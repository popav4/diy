//
//  FileKindRegistry.swift
//  DiskInventoryY
//
//  Shared registry mapping file extensions to compact kind IDs
//  Saves ~50-70 bytes per FileNode by storing UInt16 instead of String + UTType
//

import Foundation
import UniformTypeIdentifiers

/// Singleton registry that maps file extensions to compact UInt16 IDs
/// Thread-safe for concurrent access during scanning
final class FileKindRegistry: @unchecked Sendable {
    static let shared = FileKindRegistry()

    private let lock = NSLock()

    // Extension -> kindId mapping
    private var extensionToId: [String: UInt16] = [:]

    // kindId -> kindName mapping (reverse lookup for display)
    private var idToKindName: [String] = []

    // Reserved IDs for special types
    static let folderKindId: UInt16 = 0
    static let documentKindId: UInt16 = 1  // Unknown/generic document
    static let freeSpaceKindId: UInt16 = 2
    static let otherSpaceKindId: UInt16 = 3

    private init() {
        // Pre-register special types
        idToKindName.append("Folder")           // 0
        idToKindName.append("Document")         // 1
        idToKindName.append("Free Space")       // 2
        idToKindName.append("Other Space")      // 3
    }

    /// Get or create a kind ID for a file extension
    /// Thread-safe, called during scanning
    func kindId(forExtension ext: String) -> UInt16 {
        let lowercased = ext.lowercased()

        lock.lock()
        if let existing = extensionToId[lowercased] {
            lock.unlock()
            return existing
        }

        // Compute kind name from UTType (only once per unique extension)
        let kindName: String
        if let utType = UTType(filenameExtension: lowercased),
           let description = utType.localizedDescription,
           !utType.identifier.hasPrefix("dyn.") {
            // Use the nice localized description (e.g., "JPEG image")
            kindName = description
        } else {
            // Unknown type or dynamic UTI - use extension-based name
            kindName = lowercased.isEmpty ? "Document" : ".\(lowercased.uppercased()) file"
        }

        // Check if this kindName already exists (different extensions, same type)
        if let existingIndex = idToKindName.firstIndex(of: kindName) {
            let id = UInt16(existingIndex)
            extensionToId[lowercased] = id
            lock.unlock()
            return id
        }

        // Create new ID
        let newId = UInt16(idToKindName.count)
        idToKindName.append(kindName)
        extensionToId[lowercased] = newId
        lock.unlock()

        return newId
    }

    /// Get kind name for display (fast lookup)
    func kindName(for kindId: UInt16) -> String {
        lock.lock()
        defer { lock.unlock() }

        let index = Int(kindId)
        guard index < idToKindName.count else {
            return "Unknown"
        }
        return idToKindName[index]
    }

    /// Number of unique kinds registered
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return idToKindName.count
    }
}
