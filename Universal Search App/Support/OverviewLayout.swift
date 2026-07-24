//
//  OverviewLayout.swift
//  Universal Search App
//
//  Shared geometry for the open-overview/canvas morph, matching Figma 1008-9403.
//  The open thread expands into ONE dark container (radius 56) holding the query
//  at top and two WHITE cards (Favourites, All results) near the bottom. The full
//  canvas collapses into the All-results card. iPhone 16/17 Pro points ≈ the Figma
//  402×874 frame, so the Figma coordinates are used directly.
//

import SwiftUI

extension Metrics {
    /// Screen inset for the stacked cards (Figma 1214-13455).
    var cardInset: CGFloat { 8 }

    /// The trip overview's dark hero/header frame. Kept stable so row/card morph
    /// targets keep matching the trip landing geometry.
    var heroRect: CGRect {
        CGRect(x: 0, y: 0, width: size.width, height: safeTop + 290)
    }

    /// The open-overview query-playback card — inset 8pt on every side, running
    /// up into the safe area (the close/history actions float over its top).
    var overviewContainerRect: CGRect {
        CGRect(x: cardInset, y: cardInset, width: size.width - cardInset * 2, height: 372)
    }
    /// The canvas view pushed down below the query card — inset 8pt, its rounded
    /// bottom running off-screen so it reads as a pushed-down sheet (not a bounded
    /// stacked card). Also the slot the full canvas pushes down into.
    var recapCardRect: CGRect {
        let top = overviewContainerRect.maxY + cardInset
        return CGRect(x: cardInset, y: top, width: size.width - cardInset * 2, height: H - top + 160)
    }
    /// Follow-up input pill (compact, overview/trip size).
    var followUpPillSize: CGSize { CGSize(width: 220, height: 44) }

    /// Full canvas rect (reveal 0 end of the canvas morph): covers the full
    /// screen, with its rounded top/bottom corners running off-screen so it reads
    /// as a full-bleed canvas. The floating header pills sit over it.
    var fullCanvasRect: CGRect {
        CGRect(x: 0, y: -60, width: size.width, height: H + 120)
    }

    /// Centered trip-overview row card — the collapse target for the card-swap
    /// launch (matches the trip-list row: near full width, 96pt tall), parked in
    /// the vertical middle of the screen over the near-black backdrop.
    var centerCardRect: CGRect {
        let w = size.width - 48
        let h: CGFloat = 96
        return CGRect(x: (size.width - w) / 2, y: (H - h) / 2, width: w, height: h)
    }
}
