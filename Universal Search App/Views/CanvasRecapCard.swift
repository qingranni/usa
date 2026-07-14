//
//  CanvasRecapCard.swift
//  Universal Search App
//
//  The canvas-recap CONTENT — just the stacked image pair (no summary). It's the
//  collapsed representation of the full canvas: CurtainSheet shows it (on its own
//  white surface) as the canvas shrinks into the recap-card slot, so the canvas
//  morphs into the recap card rather than cross-fading with a separate view.
//

import SwiftUI

struct CanvasRecapCard: View {
    let comparison: Comparison?
    let thread: ThreadNode

    private var images: [String] {
        comparison?.images ?? thread.fanAssets
    }
    private var fanIsLogo: Bool { comparison == nil && thread.fanIsLogo }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoFan(images: images, size: 82, isLogo: fanIsLogo)
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
