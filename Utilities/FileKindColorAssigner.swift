//
//  FileKindColorAssigner.swift
//  DiskInventoryY
//
//  Assigns consistent colors to file kinds
//  Colors are normalized to consistent, muted brightness
//

import SwiftUI
import AppKit

class FileKindColorAssigner {
    private var assignedColors: [String: Color] = [:]
    private var nextColorIndex = 0

    // Target brightness: sum of RGB components.
    // Lower values keep the treemap readable without neon intensity.
    private static let baseBrightness: CGFloat = 1.55

    // Color palette - will be normalized on init
    private let palette: [Color]

    // Predefined colors for common types - will be normalized on init
    private let predefinedColors: [String: Color]

    init() {
        // Raw palette colors (before normalization)
        let rawPalette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.32, 0.58, 0.74),  // Soft blue
            (0.71, 0.44, 0.56),  // Dusty rose
            (0.45, 0.66, 0.45),  // Sage green
            (0.78, 0.58, 0.34),  // Muted amber
            (0.55, 0.48, 0.72),  // Lavender
            (0.74, 0.68, 0.38),  // Olive gold
            (0.72, 0.42, 0.38),  // Soft red
            (0.36, 0.67, 0.64),  // Teal
            (0.68, 0.48, 0.64),  // Mauve
            (0.55, 0.70, 0.38),  // Moss
            (0.38, 0.52, 0.78),  // Cornflower
            (0.76, 0.63, 0.32),  // Ochre
            (0.58, 0.43, 0.70),  // Plum
            (0.42, 0.68, 0.50),  // Eucalyptus
            (0.78, 0.50, 0.40),  // Terracotta
            (0.48, 0.66, 0.78),  // Pale sky
        ]

        // Normalize palette
        palette = rawPalette.map { Self.normalizeColor(r: $0.0, g: $0.1, b: $0.2) }

        // Raw predefined colors
        let rawPredefined: [String: (CGFloat, CGFloat, CGFloat)] = [
            "Folder": (0.58, 0.58, 0.62),
            "Document": (0.66, 0.55, 0.40),
            "Free Space": (0.72, 0.72, 0.76),
            "Other Space": (0.62, 0.62, 0.66),
            "Application": (0.34, 0.55, 0.74),
            "JPEG image": (0.45, 0.66, 0.45),
            "PNG image": (0.38, 0.67, 0.56),
            "HEIC image": (0.52, 0.68, 0.42),
            "GIF image": (0.62, 0.68, 0.38),
            "PDF document": (0.74, 0.38, 0.38),
            "MP3 audio": (0.60, 0.44, 0.72),
            "MPEG-4 audio": (0.55, 0.44, 0.70),
            "MPEG-4 movie": (0.76, 0.54, 0.34),
            "QuickTime movie": (0.76, 0.58, 0.36),
            "Zip archive": (0.74, 0.64, 0.34),
            "Disk image": (0.72, 0.58, 0.38),
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
