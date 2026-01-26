//
//  FileKindColorAssigner.swift
//  DiskInventoryY
//
//  Assigns consistent colors to file kinds
//  Colors are normalized to consistent brightness (like Disk Inventory X)
//

import SwiftUI
import AppKit

class FileKindColorAssigner {
    private var assignedColors: [String: Color] = [:]
    private var nextColorIndex = 0

    // Target brightness: sum of RGB components (from Disk Inventory X)
    // Higher = brighter colors, 1.8 is a good balance
    private static let baseBrightness: CGFloat = 1.8

    // Color palette - will be normalized on init
    private let palette: [Color]

    // Predefined colors for common types - will be normalized on init
    private let predefinedColors: [String: Color]

    init() {
        // Raw palette colors (before normalization)
        let rawPalette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.00, 0.80, 1.00),  // Electric Cyan
            (1.00, 0.20, 0.60),  // Hot Pink
            (0.20, 1.00, 0.40),  // Neon Green
            (1.00, 0.60, 0.00),  // Electric Orange
            (0.60, 0.20, 1.00),  // Vivid Purple
            (1.00, 1.00, 0.00),  // Neon Yellow
            (1.00, 0.00, 0.40),  // Neon Red
            (0.00, 1.00, 0.80),  // Aqua
            (1.00, 0.40, 0.80),  // Bright Magenta
            (0.40, 1.00, 0.00),  // Lime
            (0.00, 0.60, 1.00),  // Bright Blue
            (1.00, 0.80, 0.00),  // Gold
            (0.80, 0.00, 1.00),  // Electric Violet
            (0.00, 1.00, 0.60),  // Spring Green
            (1.00, 0.40, 0.20),  // Coral Red
            (0.40, 0.80, 1.00),  // Sky Blue
        ]

        // Normalize palette
        palette = rawPalette.map { Self.normalizeColor(r: $0.0, g: $0.1, b: $0.2) }

        // Raw predefined colors
        let rawPredefined: [String: (CGFloat, CGFloat, CGFloat)] = [
            "Folder": (0.60, 0.60, 0.65),
            "Document": (0.70, 0.55, 0.35),
            "Free Space": (0.75, 0.75, 0.80),
            "Other Space": (0.65, 0.65, 0.70),
            "Application": (0.00, 0.60, 1.00),
            "JPEG image": (0.20, 1.00, 0.40),
            "PNG image": (0.00, 1.00, 0.60),
            "HEIC image": (0.40, 1.00, 0.20),
            "GIF image": (0.60, 1.00, 0.00),
            "PDF document": (1.00, 0.20, 0.30),
            "MP3 audio": (0.80, 0.20, 1.00),
            "MPEG-4 audio": (0.60, 0.20, 1.00),
            "MPEG-4 movie": (1.00, 0.50, 0.00),
            "QuickTime movie": (1.00, 0.60, 0.00),
            "Zip archive": (1.00, 0.80, 0.00),
            "Disk image": (1.00, 0.70, 0.20),
        ]

        // Normalize predefined colors
        var normalized: [String: Color] = [:]
        for (kind, rgb) in rawPredefined {
            normalized[kind] = Self.normalizeColor(r: rgb.0, g: rgb.1, b: rgb.2)
        }
        predefinedColors = normalized
    }

    /// Normalize color to consistent brightness (R+G+B = baseBrightness)
    /// This ensures all colors have similar perceived intensity - no dark/black boxes
    private static func normalizeColor(r: CGFloat, g: CGFloat, b: CGFloat) -> Color {
        var red = r, green = g, blue = b

        // Scale so sum equals baseBrightness
        let sum = red + green + blue
        if sum > 0 {
            let factor = baseBrightness / sum
            red *= factor
            green *= factor
            blue *= factor
        }

        // If any component exceeds 1.0, redistribute excess to others
        normalizeComponents(&red, &green, &blue)

        return Color(red: Double(red), green: Double(green), blue: Double(blue))
    }

    /// Redistribute overflow from components exceeding 1.0
    private static func normalizeComponents(_ r: inout CGFloat, _ g: inout CGFloat, _ b: inout CGFloat) {
        if r > 1.0 {
            distributeOverflow(from: &r, to: &g, and: &b)
        }
        if g > 1.0 {
            distributeOverflow(from: &g, to: &r, and: &b)
        }
        if b > 1.0 {
            distributeOverflow(from: &b, to: &r, and: &g)
        }
    }

    /// Distribute overflow from one component to two others
    private static func distributeOverflow(from first: inout CGFloat, to second: inout CGFloat, and third: inout CGFloat) {
        let overflow = (first - 1.0) / 2.0
        first = 1.0
        second += overflow
        third += overflow

        // Handle cascading overflow
        if second > 1.0 {
            let extra = second - 1.0
            second = 1.0
            third += extra
            third = min(third, 1.0)
        } else if third > 1.0 {
            let extra = third - 1.0
            third = 1.0
            second += extra
            second = min(second, 1.0)
        }
    }

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
