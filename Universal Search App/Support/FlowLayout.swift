//
//  FlowLayout.swift
//  Universal Search App
//
//  Left-to-right wrapping layout used by the query-chip sentence. Items in a
//  row are centered vertically so inline text and taller chip pills align.
//

import SwiftUI

struct FlowLayout: Layout {
    var hSpacing: CGFloat = 0
    var vSpacing: CGFloat = 6

    private func rows(_ subviews: Subviews, maxWidth: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var rows: [[(Int, CGSize)]] = [[]]
        var x: CGFloat = 0
        for (i, v) in subviews.enumerated() {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append((i, s))
            x += s.width + hSpacing
        }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(subviews, maxWidth: maxWidth)
        var height: CGFloat = 0
        var width: CGFloat = 0
        for (ri, row) in rows.enumerated() {
            let rowWidth = row.reduce(0) { $0 + $1.size.width } + hSpacing * CGFloat(max(0, row.count - 1))
            let rowHeight = row.map(\.size.height).max() ?? 0
            width = max(width, rowWidth)
            height += rowHeight
            if ri < rows.count - 1 { height += vSpacing }
        }
        return CGSize(width: min(maxWidth, width), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map(\.size.height).max() ?? 0
            var x = bounds.minX
            for item in row {
                let s = item.size
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (rowHeight - s.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(s)
                )
                x += s.width + hSpacing
            }
            y += rowHeight + vSpacing
        }
    }
}
