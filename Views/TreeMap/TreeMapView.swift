//
//  TreeMapView.swift
//  DiskInventoryY
//
//  Treemap visualization using Canvas for efficient rendering
//  Cushion shading ported from original TMVCushionRenderer
//

import SwiftUI

struct TreeMapView: View {
    let root: FileNode
    @Binding var selectedNode: FileNode?
    let colorProvider: (String) -> Color
    let onZoomIntoNode: (FileNode) -> Void
    @AppStorage("cushionShading") private var cushionShading = true

    @State private var hoveredNode: FileNode?

    // Use a class to store layout cache without triggering view updates
    private class LayoutCache {
        var rects: [ObjectIdentifier: TreeMapRect] = [:]
        var cachedSize: CGSize = .zero
        var cachedRootId: ObjectIdentifier?
        var cachedRectList: [TreeMapRect] = []
    }
    private let layoutCache = LayoutCache()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, size in
                    // Use cached layout if size and root haven't changed
                    let rootId = ObjectIdentifier(root)
                    let rects: [TreeMapRect]

                    if layoutCache.cachedSize == size && layoutCache.cachedRootId == rootId {
                        rects = layoutCache.cachedRectList
                    } else {
                        rects = TreeMapLayout.layout(
                            node: root,
                            rect: CGRect(origin: .zero, size: size),
                            colorProvider: colorProvider
                        )
                        // Cache for next draw
                        layoutCache.cachedSize = size
                        layoutCache.cachedRootId = rootId
                        layoutCache.cachedRectList = rects
                        layoutCache.rects = Dictionary(uniqueKeysWithValues: rects.map { (ObjectIdentifier($0.node), $0) })
                    }

                    // Draw all rectangles with selected shading mode
                    for rect in rects {
                        if cushionShading {
                            drawCushion(rect, context: context)
                        } else {
                            drawFlat(rect, context: context)
                        }
                    }

                    // Draw selection group border (bright red around entire folder contents)
                    if let selected = selectedNode {
                        drawSelectionGroupBorder(for: selected, rects: rects, context: context)
                    }

                    // Draw hover highlight on top
                    for rect in rects {
                        drawHoverHighlight(rect, context: context)
                    }
                }

                // Invisible overlay for gestures
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                selectedNode = nodeAt(point: value.location)
                            }
                    )
                    .gesture(
                        SpatialTapGesture(count: 2)
                            .onEnded { value in
                                if let node = nodeAt(point: value.location), node.isDirectory {
                                    selectedNode = node
                                    onZoomIntoNode(node)
                                }
                            }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredNode = nodeAt(point: location)
                        case .ended:
                            hoveredNode = nil
                        }
                    }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) {
            if let hovered = hoveredNode ?? selectedNode {
                InfoBar(node: hovered)
            }
        }
    }

    // MARK: - Cushion Rendering

    private func drawCushion(_ treeRect: TreeMapRect, context: GraphicsContext) {
        let rect = treeRect.rect
        guard rect.width >= 1, rect.height >= 1 else { return }

        let baseColor = treeRect.color

        // Create cushion shading using radial gradient
        // Light source is at top-left (-1, -1, 10)
        let cushionPath = Path(rect)

        // Cushion effect: brighter at top-left, darker at bottom-right
        // Use cached color pairs to avoid repeated NSColor allocations
        let (brightColor, darkColor) = adjustedColors(for: baseColor)

        let gradient = Gradient(colors: [brightColor, darkColor])

        context.fill(
            cushionPath,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )

        // Label if rect is large enough (diagonal text fits in smaller rects)
        if rect.width > 30 && rect.height > 16 {
            drawLabel(treeRect.node.name, in: rect, context: context)
        }
    }

    private func drawFlat(_ treeRect: TreeMapRect, context: GraphicsContext) {
        let rect = treeRect.rect
        guard rect.width >= 1, rect.height >= 1 else { return }

        let fillPath = Path(rect)
        context.fill(fillPath, with: .color(treeRect.color))

        if rect.width > 30 && rect.height > 16 {
            drawLabel(treeRect.node.name, in: rect, context: context)
        }
    }

    private func drawSelectionGroupBorder(for selected: FileNode, rects: [TreeMapRect], context: GraphicsContext) {
        // Find bounding box of selected node and all its descendants
        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity
        var foundAny = false

        for treeRect in rects {
            if treeRect.node === selected || isDescendant(treeRect.node, of: selected) {
                minX = min(minX, treeRect.rect.minX)
                minY = min(minY, treeRect.rect.minY)
                maxX = max(maxX, treeRect.rect.maxX)
                maxY = max(maxY, treeRect.rect.maxY)
                foundAny = true
            }
        }

        guard foundAny else { return }

        let boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let borderPath = Path(boundingRect.insetBy(dx: 1, dy: 1))

        // White border
        context.stroke(borderPath, with: .color(.white), lineWidth: 5)
    }

    private func isDescendant(_ node: FileNode, of ancestor: FileNode) -> Bool {
        var current = node.parent
        while let parent = current {
            if parent === ancestor {
                return true
            }
            current = parent.parent
        }
        return false
    }

    private func drawHoverHighlight(_ treeRect: TreeMapRect, context: GraphicsContext) {
        let rect = treeRect.rect
        guard treeRect.node === hoveredNode else { return }

        let highlightPath = Path(rect)

        context.stroke(highlightPath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
    }

    private func drawLabel(_ text: String, in rect: CGRect, context: GraphicsContext) {
        // Font size based on smaller dimension
        let fontSize = min(11, min(rect.height, rect.width) * 0.35)
        guard fontSize >= 7 else { return }

        let styledText = Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.white.opacity(0.9))

        // Measure the text to see if it fits horizontally
        let resolvedText = context.resolve(styledText)
        let textSize = resolvedText.measure(in: CGSize(width: .max, height: .max))

        let paddingX: CGFloat = 6
        let paddingY: CGFloat = 3
        let availableWidth = rect.width - (paddingX * 2)

        // Check if text fits horizontally
        let fitsHorizontally = textSize.width <= availableWidth

        // Create a clipped context so text doesn't overflow
        var clippedContext = context
        clippedContext.clip(to: Path(rect))

        if fitsHorizontally {
            // Draw horizontally, centered vertically, left-aligned
            let startX = rect.minX + paddingX
            let startY = rect.maxY - paddingY

            clippedContext.draw(
                resolvedText,
                at: CGPoint(x: startX, y: startY),
                anchor: .bottomLeading
            )
        } else {
            // Calculate the actual diagonal angle from bottom-left to top-right
            let diagonalAngle = atan2(rect.height, rect.width)
            let angleInDegrees = diagonalAngle * 180 / .pi

            // Position at bottom-left with padding
            let startX = rect.minX + paddingX
            let startY = rect.maxY - paddingY

            // Rotate by the actual diagonal angle (negative = counter-clockwise)
            clippedContext.translateBy(x: startX, y: startY)
            clippedContext.rotate(by: .degrees(-angleInDegrees))

            // Draw the text along the diagonal
            clippedContext.draw(
                resolvedText,
                at: CGPoint(x: 0, y: 0),
                anchor: .bottomLeading
            )
        }
    }

    // Pre-resolved color cache to avoid NSColor allocations during drawing
    private static var colorCache: [Int: (bright: Color, dark: Color)] = [:]

    private func adjustedColors(for color: Color) -> (bright: Color, dark: Color) {
        // Create cache key from color hash
        let key = color.hashValue

        if let cached = Self.colorCache[key] {
            return cached
        }

        // Convert to NSColor in sRGB color space to avoid conversion issues
        let nsColor = NSColor(color)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else {
            // Fallback for conversion failure - use a visible gray
            let fallbackBright = Color(white: 0.75)
            let fallbackDark = Color(white: 0.6)
            let result = (fallbackBright, fallbackDark)
            Self.colorCache[key] = result
            return result
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Safeguard: if brightness is too low, bump it up
        // This can happen with certain color space conversions
        let safeBrightness = max(0.5, brightness)

        // Cushion gradient: subtle top-left highlight to slightly darker bottom-right
        let brightVal = min(0.94, safeBrightness * 1.08)
        let darkVal = max(0.50, safeBrightness * 0.88)

        // Keep colors muted instead of neon.
        let boostedSat = min(0.72, saturation * 0.75)

        let bright = Color(hue: Double(hue), saturation: boostedSat, brightness: brightVal, opacity: Double(alpha))
        let dark = Color(hue: Double(hue), saturation: boostedSat, brightness: darkVal, opacity: Double(alpha))

        let result = (bright, dark)
        Self.colorCache[key] = result
        return result
    }

    // MARK: - Hit Testing

    private func nodeAt(point: CGPoint) -> FileNode? {
        // Find the smallest (deepest) rect containing the point
        var bestMatch: TreeMapRect?

        for (_, rect) in layoutCache.rects {
            if rect.rect.contains(point) {
                if bestMatch == nil || rect.depth > bestMatch!.depth {
                    bestMatch = rect
                }
            }
        }

        return bestMatch?.node
    }
}

// MARK: - Info Bar

struct InfoBar: View {
    let node: FileNode

    var body: some View {
        HStack(spacing: 16) {
            Image(nsImage: node.icon)
                .resizable()
                .frame(width: 16, height: 16)

            Text(node.name)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Text(node.kindName)
                .foregroundStyle(.secondary)

            Text(FileSizeFormatter.string(from: node.size))
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    let root = FileNode(url: URL(fileURLWithPath: "/"), name: "Root", isDirectory: true, size: 1000)
    let child1 = FileNode(url: URL(fileURLWithPath: "/a"), name: "Large Folder", isDirectory: true, size: 600)
    let child2 = FileNode(url: URL(fileURLWithPath: "/b"), name: "Medium.app", isPackage: true, size: 300)
    let child3 = FileNode(url: URL(fileURLWithPath: "/c"), name: "Small.txt", size: 100)
    root.children = [child1, child2, child3]

    return TreeMapView(
        root: root,
        selectedNode: .constant(nil),
        colorProvider: { _ in .blue },
        onZoomIntoNode: { _ in }
    )
    .frame(width: 600, height: 400)
}
