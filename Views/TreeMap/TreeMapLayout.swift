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

    /// Calculates treemap layout for the given node and its children
    static func layout(
        node: FileNode,
        rect: CGRect,
        colorProvider: (String) -> Color,
        depth: Int = 0,
        maxDepth: Int = 30
    ) -> [TreeMapRect] {
        var results: [TreeMapRect] = []

        // Filter zero-size children; assume already sorted by size (scanner does this)
        let sorted = node.children.filter { $0.size > 0 }

        // If no children or at max depth, this is a leaf
        guard !sorted.isEmpty, depth < maxDepth else {
            if rect.width >= 1 && rect.height >= 1 {
                results.append(TreeMapRect(
                    node: node,
                    rect: rect,
                    color: colorProvider(node.kindName),
                    depth: depth
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
                if childRect.width >= 1 && childRect.height >= 1 {
                    // Recursively layout children if this is a directory
                    if child.node.isDirectory && !child.node.children.isEmpty {
                        let childRects = layout(
                            node: child.node,
                            rect: childRect,
                            colorProvider: colorProvider,
                            depth: depth + 1,
                            maxDepth: maxDepth
                        )
                        if childRects.isEmpty {
                            diagnostics.emptyRecursiveNodes += 1
                            diagnostics.emptyRecursiveBytes = addSaturating(diagnostics.emptyRecursiveBytes, child.node.size)
                        } else {
                            diagnostics.visibleBytes = addSaturating(
                                diagnostics.visibleBytes,
                                sumSizes(childRects.map(\.node))
                            )
                        }
                        results.append(contentsOf: childRects)
                    } else {
                        results.append(TreeMapRect(
                            node: child.node,
                            rect: childRect,
                            color: colorProvider(child.node.kindName),
                            depth: depth + 1
                        ))
                        diagnostics.visibleBytes = addSaturating(diagnostics.visibleBytes, child.node.size)
                    }
                } else {
                    diagnostics.skippedSmallNodes += 1
                    diagnostics.skippedSmallBytes = addSaturating(diagnostics.skippedSmallBytes, child.node.size)
                }

                left = right
            }

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
