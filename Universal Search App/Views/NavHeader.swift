//
//  NavHeader.swift
//  Universal Search App
//
//  ONE global floating nav header, mounted once in RootView (like the follow-up
//  pill) and present whenever the trip has content. Its buttons are persistent
//  instances that morph in place across the canvas (0), the open overview (1),
//  and the trip (2):
//    left   — back ⇄ close ⇄ back
//    right  — favourite/history on the canvas → add on the Journeys screen.
//

import SwiftUI

struct NavHeader: View {
    @Bindable var store: AppStore
    let metrics: Metrics

    /// Continuous stage: 0 canvas · 1 overview · 2 trip.
    private var navStage: CGFloat {
        store.revealingThreadID != nil ? clamp(store.reveal, 0, 2) : 2
    }

    private func toTrip() {
        withAnimation(Theme.springMorph) { store.reveal = AppStore.stageTrip }
            completion: { store.teardown() }
    }

    var body: some View {
        let s = navStage
        let composerFull = store.composerActive
            ? progress(of: store.composerReveal).eased
            : 0
        let tripProgress = smoothstep(ramp(s, 1, 2))
        let tripHorizontalInset = lerp(20, 32, tripProgress)
        let tripTopInset = lerp(metrics.safeTop + 8, metrics.safeTop + 16, tripProgress)
        let usesTopControls = store.canvasNavigationStructure == .topBar
        // Bottom-dock mode removes canvas-level top controls. They return as the
        // curtain moves toward overview/trip, where the global header is needed.
        let canvasHeaderVisibility = progress(of: s, in: 0...0.5).fadeIn
        let leftVisibility = store.composerActive
            ? 1
            : (usesTopControls ? 1 : canvasHeaderVisibility)
        let rightVisibility = usesTopControls
            ? 1
            : progress(of: s, in: 0.5...1).fadeIn
        HStack(alignment: .top) {
            leftButton(s)
                .opacity(leftVisibility)
                .allowsHitTesting(leftVisibility > 0.9)
            Spacer()
            rightControl(s)
                // The composer owns the screen while it's up, so the underlying
                // history/distance control fades out — only the left button stays,
                // now morphed into the composer's close.
                .opacity(store.composerActive ? 0 : rightVisibility)
                .allowsHitTesting(!store.composerActive && rightVisibility > 0.9)
        }
        // Keep the medium endpoint at the existing nav inset; only the full
        // takeover moves the close onto the Figma frame's x=37, y=39 position.
        .padding(.horizontal, lerp(tripHorizontalInset, 37, composerFull))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, lerp(tripTopInset, 39, composerFull))
    }

    // Back stack: the canvas (results) is the hub. From the canvas, back exits to
    // the homepage (trip overview). From the intermediate overview/trip positions,
    // back resolves back into the canvas. Always the back arrow — EXCEPT while the
    // composer is up, when this same button morphs its glyph to a close (×) and
    // dismisses the composer, so the sheet needs no close button of its own.
    private func leftButton(_ s: CGFloat) -> some View {
        let composing = store.composerActive
        return GlassCircleButton(icon: composing ? "close" : "arrow_back") {
            if composing { store.closeComposer() } else { back(s) }
        }
    }

    private func back(_ s: CGFloat) {
        if store.revealingThreadID != nil {
            if s < 0.5 {
                store.dismissCanvasToHome()   // canvas → homepage (slide down)
            } else {
                toCanvas()                    // mid-collapse → snap back to canvas
            }
        } else {
            store.reopenLast()                // trip overview → previous canvas
        }
    }

    private func toCanvas() {
        withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
    }

    @ViewBuilder private func rightControl(_ s: CGFloat) -> some View {
        let addProgress = smoothstep(ramp(s, 1.35, 2))

        ZStack(alignment: .trailing) {
            GlassCircleButton(
                icon: store.canvasNavigationStructure == .topBar && s < 0.5
                    ? "distance"
                    : "history"
            ) {
                toTrip()
            }
            .opacity(1 - addProgress)
            .allowsHitTesting(addProgress < 0.5)

            GlassCircleButton(icon: "add", size: 48) {
                store.openComposer()
            }
            .opacity(addProgress)
            .allowsHitTesting(addProgress >= 0.5)
        }
        .frame(width: 48, height: 48)
    }
}
