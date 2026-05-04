//
//  AppState.swift
//  DiskInventoryY
//
//  Global application state management
//

import SwiftUI
import Combine

private final class ScanProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private let interval: Duration
    private var lastUpdate = ContinuousClock.now

    init(interval: Duration) {
        self.interval = interval
    }

    func shouldPublish() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        let now = ContinuousClock.now
        guard now - lastUpdate >= interval else {
            return false
        }

        lastUpdate = now
        return true
    }
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var rootNode: FileNode?
    @Published var zoomedNode: FileNode?
    @Published var selectedNode: FileNode?
    @Published var zoomStack: [FileNode] = []

    @Published var isScanning = false
    @Published var scanProgress: ScanProgress?
    @Published var errorMessage: String?

    @Published var kindStatistics: [FileKindStatistic] = []
    @Published var selectedKind: String?

    // MARK: - Settings

    @AppStorage("showPhysicalSize") var showPhysicalSize = false
    @AppStorage("showPackageContents") var showPackageContents = false
    @AppStorage("ignoreCreatorCodes") var ignoreCreatorCodes = true
    @AppStorage("showFreeSpace") var showFreeSpace = true
    @AppStorage("showOtherSpace") var showOtherSpace = true
    @AppStorage("useParallelScanning") var useParallelScanning = true

    // MARK: - Private

    private var scanner: FileScanner?
    private var colorAssigner = FileKindColorAssigner()
    private var scanID = UUID()
    private let progressUpdateInterval: Duration = .milliseconds(200)

    // MARK: - Computed Properties

    var displayRoot: FileNode? {
        zoomedNode ?? rootNode
    }

    // MARK: - Actions

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to analyze disk usage"
        panel.prompt = "Analyze"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await scan(url: url)
            }
        }
    }

    func scan(url: URL) async {
        // Cancel any existing scan
        await scanner?.cancel()
        let currentScanID = UUID()
        let progressThrottle = ScanProgressThrottle(interval: progressUpdateInterval)
        scanID = currentScanID

        isScanning = true
        scanProgress = ScanProgress(currentFolder: url.lastPathComponent, filesScanned: 0, foldersScanned: 0)
        errorMessage = nil
        rootNode = nil
        zoomedNode = nil
        zoomStack = []
        selectedNode = nil
        kindStatistics = []

        let newScanner = FileScanner()
        scanner = newScanner

        do {
            let root = try await newScanner.scan(
                url: url,
                showPackageContents: showPackageContents,
                usePhysicalSize: showPhysicalSize,
                useParallelScanning: useParallelScanning
            ) { [weak self] folder, files, folders in
                guard progressThrottle.shouldPublish() else { return }

                Task { @MainActor in
                    self?.updateScanProgress(
                        scanID: currentScanID,
                        folder: folder,
                        files: files,
                        folders: folders
                    )
                }
            }

            rootNode = root

            // Add free space and other space items if scanning a volume root
            if showFreeSpace || showOtherSpace {
                await addVolumeSpaceItems(for: url)
            }

        } catch is CancellationError {
            // Scan was cancelled, ignore
        } catch {
            errorMessage = error.localizedDescription
        }

        isScanning = false
        scanProgress = nil

        // Calculate statistics in background (kindName triggers lazy UTType computation)
        // Don't await - let sidebar populate asynchronously
        if let root = rootNode {
            updateStatistics(from: root)
        }
    }

    func refresh() async {
        guard let root = rootNode else { return }
        await scan(url: root.url)
    }

    func zoomIn() {
        guard let selected = selectedNode, selected.isDirectory else { return }

        if let current = zoomedNode {
            zoomStack.append(current)
        } else if let root = rootNode {
            zoomStack.append(root)
        }

        zoomedNode = selected
    }

    func zoomOut() {
        guard !zoomStack.isEmpty else { return }
        zoomedNode = zoomStack.removeLast()

        if zoomedNode === rootNode {
            zoomedNode = nil
        }
    }

    func zoomToRoot() {
        zoomedNode = nil
        zoomStack = []
    }

    func color(for kindName: String) -> Color {
        colorAssigner.color(for: kindName)
    }

    /// Remove a node from the tree (after trashing) and update sizes
    func removeNode(_ node: FileNode) {
        let deletedSize = node.size

        // Clear selection if we're deleting the selected node
        if selectedNode === node {
            selectedNode = nil
        }

        // Remove from parent's children
        if let parent = node.parent {
            parent.children.removeAll { $0 === node }

            // Update sizes up the tree
            var current: FileNode? = parent
            while let ancestor = current {
                ancestor.size -= deletedSize
                current = ancestor.parent
            }
        }

        // Update statistics in background
        if let root = rootNode {
            updateStatistics(from: root)
        }

        // Trigger UI refresh
        objectWillChange.send()
    }

    // MARK: - Private Methods

    private func updateStatistics(from root: FileNode) {
        Task { [root] in
            let stats = await Task.detached {
                Self.collectStatistics(from: root)
            }.value

            kindStatistics = stats.map { kind, stat in
                FileKindStatistic(
                    kindName: kind,
                    count: stat.count,
                    totalSize: stat.size,
                    color: colorAssigner.color(for: kind)
                )
            }.sorted { $0.totalSize > $1.totalSize }
        }
    }

    private func updateScanProgress(scanID: UUID, folder: String, files: Int, folders: Int) {
        guard self.scanID == scanID, isScanning else { return }

        scanProgress = ScanProgress(
            currentFolder: folder,
            filesScanned: files,
            foldersScanned: folders
        )
    }

    /// Collect statistics off-main-thread (kindName triggers lazy UTType computation)
    private nonisolated static func collectStatistics(from root: FileNode) -> [String: (count: Int, size: UInt64)] {
        var stats: [String: (count: Int, size: UInt64)] = [:]

        func collect(_ node: FileNode) {
            if !node.isDirectory {
                let kind = node.kindName
                var stat = stats[kind] ?? (count: 0, size: 0)
                stat.count += 1
                stat.size += node.size
                stats[kind] = stat
            }

            for child in node.children {
                collect(child)
            }
        }

        collect(root)
        return stats
    }

    private func addVolumeSpaceItems(for url: URL) async {
        guard let root = rootNode else { return }

        do {
            // Only add volume space items when scanning a volume root
            let resourceValues = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .isVolumeKey
            ])

            // Check if this is actually a volume root (like / or /Volumes/SomeDisk)
            let isVolumeRoot = resourceValues.isVolume ?? false
            let parentPath = url.deletingLastPathComponent().path
            let isVolumeMountPoint = parentPath == "/Volumes" || url.path == "/"

            guard isVolumeRoot || isVolumeMountPoint else {
                return // Not a volume root, don't add space items
            }

            guard let totalCapacity = resourceValues.volumeTotalCapacity,
                  let availableCapacity = resourceValues.volumeAvailableCapacity,
                  totalCapacity >= 0,
                  availableCapacity >= 0 else {
                return
            }

            let scannedSize = root.size
            let totalSize = UInt64(totalCapacity)
            let freeSize = UInt64(availableCapacity)
            let usedSize = totalSize >= freeSize ? totalSize - freeSize : 0
            let otherSize = usedSize > scannedSize ? usedSize - scannedSize : 0

            if showOtherSpace && otherSize > 0 {
                let otherItem = FileNode(
                    url: url.appendingPathComponent("<Other Space>"),
                    name: "Other Space",
                    isDirectory: false,
                    isPackage: false,
                    size: otherSize,
                    type: .otherSpace
                )
                root.children.append(otherItem)
            }

            if showFreeSpace && freeSize > 0 {
                let freeItem = FileNode(
                    url: url.appendingPathComponent("<Free Space>"),
                    name: "Free Space",
                    isDirectory: false,
                    isPackage: false,
                    size: freeSize,
                    type: .freeSpace
                )
                root.children.append(freeItem)
            }

            root.size = root.children.reduce(UInt64(0)) { partialSize, child in
                let (sum, overflow) = partialSize.addingReportingOverflow(child.size)
                return overflow ? UInt64.max : sum
            }

        } catch {
            // Ignore volume info errors
        }
    }
}

// MARK: - Supporting Types

struct ScanProgress {
    let currentFolder: String
    let filesScanned: Int
    let foldersScanned: Int
}
