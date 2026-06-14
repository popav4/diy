//
//  TreeMapLayout.swift
//  DiskInventoryY
//
//  TreeMap layout algorithm - ported from original TMVItem.m
//  Uses row-based layout with minProportion constraint
//

import SwiftUI

struct TreeMapRect {
    let node: FileNode
    var rect: CGRect
    let color: Color
    let depth: Int  // Nesting depth for cushion shading
    let representedSize: UInt64
    let label: String?
}

enum TreeMapLayout {

    /// Minimum aspect ratio for rectangles (prevents very thin rectangles)
    private static let minProportion: Double = 0.4

    private struct LayoutDiagnostics {
        var visibleBytes: UInt64 = 0
        var skippedSmallNodes = 0
        var skippedSmallBytes: UInt64 = 0
        var emptyRecursiveNodes = 0
        var emptyRecursiveBytes: UInt64 = 0
        var unprocessedNodes = 0
        var unprocessedBytes: UInt64 = 0

        var lostNodes: Int {
            skippedSmallNodes + emptyRecursiveNodes + unprocessedNodes
        }

        var lostBytes: UInt64 {
            TreeMapLayout.addSaturating(
                TreeMapLayout.addSaturating(skippedSmallBytes, emptyRecursiveBytes),
                unprocessedBytes
            )
        }
    }

    private struct SmallItemAggregate {
        var rect: CGRect
        var size: UInt64
        var count: Int
    }

    /// Calculates treemap layout for the given node and its children
    static func layout(
        node: FileNode,
        rect: CGRect,
        colorProvider: (String) -> Color,
        minRectSize: Double = 3.0,
        depth: Int = 0,
        maxDepth: Int = 30
    ) -> [TreeMapRect] {
        var results: [TreeMapRect] = []

        // Filter zero-size children; assume already sorted by size (scanner does this)
        let sorted = node.children.filter { $0.size > 0 }

        // If no children or at max depth, this is a leaf
        guard !sorted.isEmpty, depth < maxDepth else {
            if rect.width >= minRectSize && rect.height >= minRectSize {
                results.append(TreeMapRect(
                    node: node,
                    rect: rect,
                    color: colorProvider(node.kindName),
                    depth: depth,
                    representedSize: node.size,
                    label: nil
                ))
            }
            return results
        }
        let totalWeight = Double(node.size)

        guard totalWeight > 0 else { return results }
        var diagnostics = LayoutDiagnostics()

        // Determine if rows should be horizontal or vertical
        let horizontal = rect.width >= rect.height

        // Calculate normalized width (aspect ratio)
        let width: Double
        if horizontal {
            width = rect.height > 0 ? Double(rect.width) / Double(rect.height) : 1.0
        } else {
            width = rect.width > 0 ? Double(rect.height) / Double(rect.width) : 1.0
        }

        // Arrange children into rows
        var rows: [(height: Double, children: [(node: FileNode, width: Double)])] = []
        var childIndex = 0

        while childIndex < sorted.count {
            let (rowHeight, childWidths, childsUsed) = calculateRow(
                children: sorted,
                startIndex: childIndex,
                rowWidth: width,
                totalWeight: totalWeight
            )

            if childsUsed == 0 { break }

            var rowChildren: [(node: FileNode, width: Double)] = []
            for i in 0..<childsUsed {
                rowChildren.append((sorted[childIndex + i], childWidths[i]))
            }

            rows.append((rowHeight, rowChildren))
            childIndex += childsUsed
        }

        if childIndex < sorted.count {
            let unprocessed = sorted[childIndex...]
            diagnostics.unprocessedNodes = unprocessed.count
            diagnostics.unprocessedBytes = sumSizes(unprocessed)
        }

        // Layout the rows
        let parentWidth = horizontal ? rect.width : rect.height
        let parentHeight = horizontal ? rect.height : rect.width
        let parentLeft = horizontal ? rect.minX : rect.minY
        let parentTop = horizontal ? rect.minY : rect.minX
        let parentRight = horizontal ? rect.maxX : rect.maxY
        let parentBottom = horizontal ? rect.maxY : rect.maxX

        var top = parentTop

        for (rowIndex, row) in rows.enumerated() {
            var bottom = top + CGFloat(row.height) * parentHeight

            // Last row: snap to parent bottom to avoid rounding errors
            if bottom > parentBottom || rowIndex == rows.count - 1 {
                bottom = parentBottom
            }

            var left = parentLeft
            var smallAggregate: SmallItemAggregate?

            func flushSmallAggregate() {
                guard let aggregate = smallAggregate else { return }
                defer { smallAggregate = nil }

                if let visibleRect = visibleRect(for: aggregate.rect, within: rect, minSize: minRectSize) {
                    results.append(TreeMapRect(
                        node: node,
                        rect: visibleRect,
                        color: mutedColor(colorProvider(node.kindName)),
                        depth: depth + 1,
                        representedSize: aggregate.size,
                        label: "Small items"
                    ))
                    diagnostics.visibleBytes = addSaturating(diagnostics.visibleBytes, aggregate.size)
                } else {
                    diagnostics.skippedSmallNodes += aggregate.count
                    diagnostics.skippedSmallBytes = addSaturating(diagnostics.skippedSmallBytes, aggregate.size)
                }
            }

            for (colIndex, child) in row.children.enumerated() {
                var right = left + CGFloat(child.width) * parentWidth

                // Last column: snap to parent right
                if right > parentRight || colIndex == row.children.count - 1 {
                    right = parentRight
                }

                let childRect: CGRect
                if horizontal {
                    childRect = CGRect(x: left, y: top, width: right - left, height: bottom - top)
                } else {
                    childRect = CGRect(x: top, y: left, width: bottom - top, height: right - left)
                }

                // Skip very small rectangles
                if childRect.width >= minRectSize && childRect.height >= minRectSize {
                    flushSmallAggregate()

                    // Recursively layout children if this is a directory
                    if child.node.isDirectory && !child.node.children.isEmpty {
                        let childRects = layout(
                            node: child.node,
                            rect: childRect,
                            colorProvider: colorProvider,
                            minRectSize: minRectSize,
                            depth: depth + 1,
                            maxDepth: maxDepth
                        )
                        if childRects.isEmpty {
                            results.append(TreeMapRect(
                                node: child.node,
                                rect: childRect,
                                color: colorProvider(child.node.kindName),
                                depth: depth + 1,
                                representedSize: child.node.size,
                                label: nil
                            ))
                            diagnostics.visibleBytes = addSaturating(diagnostics.visibleBytes, child.node.size)
                        } else {
                            diagnostics.visibleBytes = addSaturating(
                                diagnostics.visibleBytes,
                                sumRepresentedSizes(childRects)
                            )
                            results.append(contentsOf: childRects)
                        }
                    } else {
                        results.append(TreeMapRect(
                            node: child.node,
                            rect: childRect,
                            color: colorProvider(child.node.kindName),
                            depth: depth + 1,
                            representedSize: child.node.size,
                            label: nil
                        ))
                        diagnostics.visibleBytes = addSaturating(diagnostics.visibleBytes, child.node.size)
                    }
                } else {
                    if var aggregate = smallAggregate {
                        aggregate.rect = aggregate.rect.union(childRect)
                        aggregate.size = addSaturating(aggregate.size, child.node.size)
                        aggregate.count += 1
                        smallAggregate = aggregate
                    } else {
                        smallAggregate = SmallItemAggregate(
                            rect: childRect,
                            size: child.node.size,
                            count: 1
                        )
                    }
                }

                left = right
            }

            flushSmallAggregate()

            top = bottom
        }

        logDiagnosticsIfNeeded(for: node, rect: rect, depth: depth, diagnostics: diagnostics)
        return results
    }

    /// Calculate a single row of children
    /// Returns: (rowHeight as fraction, childWidths as fractions, number of children used)
    private static func calculateRow(
        children: [FileNode],
        startIndex: Int,
        rowWidth: Double,
        totalWeight: Double
    ) -> (Double, [Double], Int) {

        var sizeUsed: Double = 0
        var rowHeight: Double = 0
        var childWidths: [Double] = []
        var childsUsed = 0

        for i in startIndex..<children.count {
            let childSize = Double(children[i].size)

            // Skip zero-size children (they'll be added at the end)
            if childSize == 0 {
                if i > startIndex {
                    break
                }
                continue
            }

            sizeUsed += childSize
            let virtualRowHeight = sizeUsed / totalWeight

            // Rectangle(totalWeight) = width * 1.0
            // Rectangle(childSize) = childWidth * virtualRowHeight
            // childWidth = childSize / totalWeight * rowWidth / virtualRowHeight
            let childWidth = childSize / totalWeight * rowWidth / virtualRowHeight

            // Stop if rectangle would be too thin
            if childWidth / virtualRowHeight < minProportion {
                if i > startIndex {
                    break
                }
                // First child - must include it
            }

            rowHeight = virtualRowHeight
            childsUsed = i - startIndex + 1
        }

        // Add any remaining zero-size children
        var i = startIndex + childsUsed
        while i < children.count && children[i].size == 0 {
            childsUsed += 1
            i += 1
        }

        // Calculate final child widths
        let rowSize = totalWeight * rowHeight
        for j in 0..<childsUsed {
            let childSize = Double(children[startIndex + j].size)
            let cw = rowSize > 0 ? childSize / rowSize : 1.0 / Double(childsUsed)
            childWidths.append(cw)
        }

        return (rowHeight, childWidths, childsUsed)
    }

    private static func logDiagnosticsIfNeeded(
        for node: FileNode,
        rect: CGRect,
        depth: Int,
        diagnostics: LayoutDiagnostics
    ) {
        guard AppLogger.shared.isTreeMapLayoutDiagnosticsEnabled else { return }

        let expectedBytes = node.size
        let observedLostBytes = expectedBytes > diagnostics.visibleBytes
            ? expectedBytes - diagnostics.visibleBytes
            : diagnostics.lostBytes

        guard observedLostBytes > 0 || diagnostics.lostNodes > 0 else { return }

        let lostPercentTimes10: UInt64
        if expectedBytes > 0 {
            lostPercentTimes10 = min(1000, observedLostBytes.saturatingMultiply(by: 1000) / expectedBytes)
        } else {
            lostPercentTimes10 = 0
        }

        guard observedLostBytes > 0 || diagnostics.lostNodes >= 100 else { return }

        AppLogger.shared.log(
            "TreeMapLayout diagnostics: node='\(node.path)' depth=\(depth) rect=\(Int(rect.width))x\(Int(rect.height)) expected-bytes=\(expectedBytes) visible-bytes=\(diagnostics.visibleBytes) lost-bytes=\(observedLostBytes) lost-percent=\(lostPercentTimes10 / 10).\(lostPercentTimes10 % 10) skipped-small-nodes=\(diagnostics.skippedSmallNodes) skipped-small-bytes=\(diagnostics.skippedSmallBytes) empty-recursive-nodes=\(diagnostics.emptyRecursiveNodes) empty-recursive-bytes=\(diagnostics.emptyRecursiveBytes) unprocessed-nodes=\(diagnostics.unprocessedNodes) unprocessed-bytes=\(diagnostics.unprocessedBytes)"
        )
    }

    private static func sumSizes<S: Sequence>(_ nodes: S) -> UInt64 where S.Element == FileNode {
        nodes.reduce(UInt64(0)) { partialSize, node in
            addSaturating(partialSize, node.size)
        }
    }

    private static func sumRepresentedSizes<S: Sequence>(_ rects: S) -> UInt64 where S.Element == TreeMapRect {
        rects.reduce(UInt64(0)) { partialSize, rect in
            addSaturating(partialSize, rect.representedSize)
        }
    }

    private static func mutedColor(_ color: Color) -> Color {
        guard let rgbColor = NSColor(color).usingColorSpace(.sRGB) else {
            return Color(white: 0.62)
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        rgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        let mutedSaturation = saturation * 0.35
        let mutedBrightness = min(0.82, max(0.48, brightness * 0.92))

        return Color(
            hue: Double(hue),
            saturation: Double(mutedSaturation),
            brightness: Double(mutedBrightness),
            opacity: 1.0
        )
    }

    private static func visibleRect(for rect: CGRect, within bounds: CGRect, minSize: Double) -> CGRect? {
        guard rect.width > 0, rect.height > 0, bounds.width > 0, bounds.height > 0 else { return nil }

        let targetWidth = min(max(rect.width, minSize), bounds.width)
        let targetHeight = min(max(rect.height, minSize), bounds.height)
        let centerX = rect.midX
        let centerY = rect.midY

        let minX = min(max(centerX - targetWidth / 2, bounds.minX), bounds.maxX - targetWidth)
        let minY = min(max(centerY - targetHeight / 2, bounds.minY), bounds.maxY - targetHeight)

        return CGRect(x: minX, y: minY, width: targetWidth, height: targetHeight)
    }

    private static func addSaturating(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

private extension UInt64 {
    func saturatingMultiply(by multiplier: UInt64) -> UInt64 {
        let result = multipliedReportingOverflow(by: multiplier)
        return result.overflow ? UInt64.max : result.partialValue
    }
}
