//
//  OverviewCard.swift
//  Universal Search App
//
//  The open thread's destination in the trip: its trip-overview ROW card. The
//  canvas collapses straight into this (there is no intermediate open-overview
//  card any more), so this just renders the row's title + heading at the measured
//  slot and fades in over the tail of the collapse, matching the real
//  OverviewCardRow it hands off to once the curtain tears down.
//

import SwiftUI

struct OverviewCard: View {
    @Bindable var store: AppStore
    let thread: ThreadNode
    let metrics: Metrics

    private var comparison: Comparison? { store.openComparison }
    private var heading: String { comparison != nil ? Copy["overview.comparingHeading"] : Copy["overview.resultsHeading"] }
    private var title: String { comparison?.versusTitle ?? thread.title }

    /// The open entry's trip-list row, measured up front. During a card-swap
    /// launch it retargets to the centered card so the collapsed title lands in
    /// the middle of the screen.
    private var slot: CGRect? {
        if store.launchCentered { return metrics.centerCardRect }
        guard let id = store.openEntryID, let s = store.slotFrames[id], s != .zero else { return nil }
        return s
    }

    var body: some View {
        // Fade the row card in over the tail of the collapse so it settles just
        // as the canvas finishes shrinking onto it, then the real row takes over.
        let appearMorph = progress(of: store.morphReveal, in: 1.5...2.0)
        let appear = appearMorph.fadeIn

        Group {
            if let slot {
                OverviewCardRow(
                    heading: heading,
                    title: title,
                    images: thread.fanAssets,
                    isLogo: thread.fanIsLogo
                )
                .frame(width: slot.width, height: slot.height, alignment: .leading)
                .position(x: slot.midX, y: slot.midY)
                .morphBlur(appearMorph)
                .opacity(appear)
                .allowsHitTesting(false)
            }
        }
    }
}
