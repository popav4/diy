//
//  FileKindColorAssigner.swift
//  DiskInventoryY
//
//  Assigns consistent colors to file kinds
//

import SwiftUI

class FileKindColorAssigner {
    private var assignedColors: [String: Color] = [:]
    private var nextColorIndex = 0

    // Color palette - bright neon colors for maximum visibility
    private let palette: [Color] = [
        Color(red: 0.00, green: 0.80, blue: 1.00),  // Electric Cyan
        Color(red: 1.00, green: 0.20, blue: 0.60),  // Hot Pink
        Color(red: 0.20, green: 1.00, blue: 0.40),  // Neon Green
        Color(red: 1.00, green: 0.60, blue: 0.00),  // Electric Orange
        Color(red: 0.60, green: 0.20, blue: 1.00),  // Vivid Purple
        Color(red: 1.00, green: 1.00, blue: 0.00),  // Neon Yellow
        Color(red: 1.00, green: 0.00, blue: 0.40),  // Neon Red
        Color(red: 0.00, green: 1.00, blue: 0.80),  // Aqua
        Color(red: 1.00, green: 0.40, blue: 0.80),  // Bright Magenta
        Color(red: 0.40, green: 1.00, blue: 0.00),  // Lime
        Color(red: 0.00, green: 0.60, blue: 1.00),  // Bright Blue
        Color(red: 1.00, green: 0.80, blue: 0.00),  // Gold
        Color(red: 0.80, green: 0.00, blue: 1.00),  // Electric Violet
        Color(red: 0.00, green: 1.00, blue: 0.60),  // Spring Green
        Color(red: 1.00, green: 0.40, blue: 0.20),  // Coral Red
        Color(red: 0.40, green: 0.80, blue: 1.00),  // Sky Blue
    ]

    // Predefined colors for common types - bright neon variants
    private let predefinedColors: [String: Color] = [
        "Folder": Color(red: 0.50, green: 0.50, blue: 0.55),
        "Free Space": Color(red: 0.75, green: 0.75, blue: 0.80),
        "Other Space": Color(red: 0.60, green: 0.60, blue: 0.65),
        "Application": Color(red: 0.00, green: 0.60, blue: 1.00),
        "JPEG image": Color(red: 0.20, green: 1.00, blue: 0.40),
        "PNG image": Color(red: 0.00, green: 1.00, blue: 0.60),
        "HEIC image": Color(red: 0.40, green: 1.00, blue: 0.20),
        "GIF image": Color(red: 0.60, green: 1.00, blue: 0.00),
        "PDF document": Color(red: 1.00, green: 0.20, blue: 0.30),
        "MP3 audio": Color(red: 0.80, green: 0.20, blue: 1.00),
        "MPEG-4 audio": Color(red: 0.60, green: 0.20, blue: 1.00),
        "MPEG-4 movie": Color(red: 1.00, green: 0.50, blue: 0.00),
        "QuickTime movie": Color(red: 1.00, green: 0.60, blue: 0.00),
        "Zip archive": Color(red: 1.00, green: 0.80, blue: 0.00),
        "Disk image": Color(red: 1.00, green: 0.70, blue: 0.20),
    ]

    func color(for kindName: String) -> Color {
        // Check predefined colors first
        if let predefined = predefinedColors[kindName] {
            return predefined
        }

        // Check if already assigned
        if let existing = assignedColors[kindName] {
            return existing
        }

        // Assign next color from palette
        let color = palette[nextColorIndex % palette.count]
        assignedColors[kindName] = color
        nextColorIndex += 1
        return color
    }

    func reset() {
        assignedColors.removeAll()
        nextColorIndex = 0
    }
}
