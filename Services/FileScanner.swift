//
//  FileScanner.swift
//  DiskInventoryY
//
//  Async file system scanner with parallel directory traversal
//

import Foundation
import UniformTypeIdentifiers

// MARK: - Array Chunking Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// Thread-safe counter for progress reporting
private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _fileCount = 0
    private var _folderCount = 0

    var fileCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _fileCount
    }

    var folderCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _folderCount
    }

    func incrementFiles() -> (Int, Int) {
        lock.lock()
        defer { lock.unlock() }
        _fileCount += 1
        return (_fileCount, _folderCount)
    }

    func incrementFolders() -> (Int, Int) {
        lock.lock()
        defer { lock.unlock() }
        _folderCount += 1
        return (_fileCount, _folderCount)
    }
}

actor FileScanner {
    private var scanTask: Task<FileNode, Error>?

    // MARK: - Public API

    func cancel() {
        scanTask?.cancel()
    }

    func scan(
        url: URL,
        showPackageContents: Bool,
        usePhysicalSize: Bool,
        useParallelScanning: Bool = true,
        progress: @escaping @Sendable (String, Int, Int) -> Void
    ) async throws -> FileNode {
        let counter = ProgressCounter()

        let task = Task {
            if useParallelScanning {
                return try await Self.scanDirectoryParallel(
                    url: url,
                    parent: nil,
                    showPackageContents: showPackageContents,
                    usePhysicalSize: usePhysicalSize,
                    counter: counter,
                    progress: progress
                )
            } else {
                return try await Self.scanDirectorySequential(
                    url: url,
                    parent: nil,
                    showPackageContents: showPackageContents,
                    usePhysicalSize: usePhysicalSize,
                    counter: counter,
                    progress: progress
                )
            }
        }
        scanTask = task

        let result = try await task.value
        result.sortChildrenBySize()
        return result
    }

    // MARK: - Private Implementation (static for parallel execution)

    private static let resourceKeys: Set<URLResourceKey> = [
        .nameKey,
        .isDirectoryKey,
        .isPackageKey,
        .fileSizeKey,
        .totalFileAllocatedSizeKey,
        .contentTypeKey,
        .isSymbolicLinkKey,
        .isAliasFileKey
    ]

    /// Creates a FileNode from a URL, reporting progress
    private static func makeNode(
        url: URL,
        parent: FileNode?,
        usePhysicalSize: Bool,
        counter: ProgressCounter,
        progress: @escaping @Sendable (String, Int, Int) -> Void
    ) throws -> (node: FileNode, isDirectory: Bool, isPackage: Bool, shouldDescend: Bool) {
        let values = try url.resourceValues(forKeys: resourceKeys)

        let isDirectory = values.isDirectory ?? false
        let isPackage = values.isPackage ?? false
        let isSymlink = values.isSymbolicLink ?? false
        let isAlias = values.isAliasFile ?? false

        let size: UInt64
        if usePhysicalSize {
            size = UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        } else {
            size = UInt64(values.fileSize ?? 0)
        }

        // Use path directly - more memory efficient than storing URL
        let node = FileNode(
            path: url.path,
            isDirectory: isDirectory,
            isPackage: isPackage,
            size: isDirectory ? 0 : size
        )
        node.parent = parent

        // Report progress
        if isDirectory {
            let (files, folders) = counter.incrementFolders()
            progress(url.lastPathComponent, files, folders)
        } else {
            _ = counter.incrementFiles()
        }

        // Don't follow symlinks or aliases to avoid infinite loops
        let shouldDescend = isDirectory && !isSymlink && !isAlias

        return (node, isDirectory, isPackage, shouldDescend)
    }

    // MARK: - Parallel Scanning (with batched concurrency)

    /// Number of directories to process in parallel per batch
    private static let batchSize = 8

    private static func scanDirectoryParallel(
        url: URL,
        parent: FileNode?,
        showPackageContents: Bool,
        usePhysicalSize: Bool,
        counter: ProgressCounter,
        progress: @escaping @Sendable (String, Int, Int) -> Void
    ) async throws -> FileNode {
        try Task.checkCancellation()

        let (node, _, isPackage, shouldDescend) = try makeNode(
            url: url,
            parent: parent,
            usePhysicalSize: usePhysicalSize,
            counter: counter,
            progress: progress
        )

        guard shouldDescend && (showPackageContents || !isPackage) else {
            return node
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )

            // Separate directories from files for smarter processing
            var directories: [URL] = []

            for childURL in contents {
                let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    directories.append(childURL)
                } else {
                    // Process files immediately - no task overhead
                    try Task.checkCancellation()
                    do {
                        let (fileNode, _, _, _) = try makeNode(
                            url: childURL,
                            parent: node,
                            usePhysicalSize: usePhysicalSize,
                            counter: counter,
                            progress: progress
                        )
                        node.children.append(fileNode)
                        node.size += fileNode.size
                    } catch {
                        // Skip inaccessible files
                    }
                }
            }

            // Process directories in batches to limit memory usage
            for batch in directories.chunked(into: batchSize) {
                try Task.checkCancellation()

                try await withThrowingTaskGroup(of: FileNode?.self) { group in
                    for dirURL in batch {
                        group.addTask {
                            try Task.checkCancellation()
                            do {
                                return try await scanDirectoryParallel(
                                    url: dirURL,
                                    parent: node,
                                    showPackageContents: showPackageContents,
                                    usePhysicalSize: usePhysicalSize,
                                    counter: counter,
                                    progress: progress
                                )
                            } catch is CancellationError {
                                throw CancellationError()
                            } catch {
                                return nil
                            }
                        }
                    }

                    for try await childNode in group {
                        if let child = childNode {
                            node.children.append(child)
                            node.size += child.size
                        }
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Can't enumerate directory, return node with no children
        }

        return node
    }

    // MARK: - Sequential Scanning

    private static func scanDirectorySequential(
        url: URL,
        parent: FileNode?,
        showPackageContents: Bool,
        usePhysicalSize: Bool,
        counter: ProgressCounter,
        progress: @escaping @Sendable (String, Int, Int) -> Void
    ) async throws -> FileNode {
        try Task.checkCancellation()

        let (node, _, isPackage, shouldDescend) = try makeNode(
            url: url,
            parent: parent,
            usePhysicalSize: usePhysicalSize,
            counter: counter,
            progress: progress
        )

        guard shouldDescend && (showPackageContents || !isPackage) else {
            return node
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )

            // Scan children sequentially
            for childURL in contents {
                try Task.checkCancellation()
                do {
                    let child = try await scanDirectorySequential(
                        url: childURL,
                        parent: node,
                        showPackageContents: showPackageContents,
                        usePhysicalSize: usePhysicalSize,
                        counter: counter,
                        progress: progress
                    )
                    node.children.append(child)
                    node.size += child.size
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Skip files we can't access (permission denied, etc.)
                    continue
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Can't enumerate directory, return node with no children
        }

        return node
    }
}
