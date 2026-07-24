//
//  NavHeader.swift
//  Universal Search App
//
//  ONE global floating nav header, mounted once in RootView (like the follow-up
//  pill) and present whenever the trip has content. Its buttons are persistent
//  instances that morph in place across the canvas (0), the open overview (1),
//  and the trip (2):
//    left   — back ⇄ close ⇄ back
//    right  — favourite/history on the canvas → overflow on the Activity screen.
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
        store.showTripOverview()
    }

    var body: some View {
        let s = navStage
        let composerFull = store.composerActive
            ? progress(of: store.composerReveal).eased
            : 0
        let tripProgress = smoothstep(ramp(s, 1, 2))
        // Match the 32pt edge inset used by the canvas/result controls.
        let tripHorizontalInset: CGFloat = 32
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
        // The full chat view and the floating inline answer keep the top-right
        // history control (a shortcut to the trip / conversation history), so it
        // stays put as the answer morphs into its own conversation — INCLUDING
        // while composing a reply to it. Only a fresh full-screen search composer
        // (no conversation/answer behind it) hides it.
        let hidesRightControl = store.composerActive
            && store.openConversation == nil
            && store.inlineAnswerDraft == nil
        ZStack(alignment: .top) {
            HStack(alignment: .top) {
                leftButton(s)
                    .opacity(leftVisibility)
                    .allowsHitTesting(leftVisibility > 0.9)
                Spacer()
                rightControl(s)
                    .opacity(hidesRightControl ? 0 : rightVisibility)
                    .allowsHitTesting(!hidesRightControl && rightVisibility > 0.9)
            }

            if let conversation = store.openConversation,
               s < 0.5,
               !store.composerActive {
                // Fade the title out once the canvas content scrolls up under it,
                // so it never overlaps the scrolling copy.
                headerTitle(conversation.title)
                    .opacity(store.canvasContentScrolled ? 0 : 1)
            }

            // Composing a reply to a quick answer keeps the answer's title up top
            // (back chevron on the left), matching the clean full-white surface.
            if store.composerActive,
               composerFull < 0.5,
               let draft = store.inlineAnswerDraft {
                headerTitle(draft.conversation.title)
            }
        }
        // Keep the medium endpoint at the existing nav inset; only the full
        // takeover moves the close onto the Figma frame's x=37, y=39 position.
        .padding(.horizontal, lerp(tripHorizontalInset, 37, composerFull))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, lerp(tripTopInset, 39, composerFull))
    }

    private func headerTitle(_ title: String) -> some View {
        Text(title)
            .font(.centra(size: 16, weight: .medium))
            .foregroundStyle(Theme.figmaInk)
            .lineLimit(1)
            .frame(height: 44)
            .padding(.horizontal, 92)
            .transition(.opacity)
    }

    // Back stack: the canvas (results) is the hub. From the canvas, back pops to
    // the previously-viewed canvas, falling through to the homepage only when the
    // stack is empty. From the intermediate overview/trip positions, back resolves
    // back into the canvas. Always the back arrow — EXCEPT while the
    // composer is up, when this same button morphs its glyph to a close (×) and
    // dismisses the composer, so the sheet needs no close button of its own.
    private func leftButton(_ s: CGFloat) -> some View {
        let composing = store.composerActive
        let showingInlineAnswer = store.inlineAnswerDraft != nil
        // Composing over a quick answer reads as a back step (returns to the
        // answer); every other composer/inline-answer state uses close (×).
        let icon = composing
            ? (showingInlineAnswer ? "arrow_back" : "close")
            : (showingInlineAnswer ? "close" : "arrow_back")
        return GlassCircleButton(icon: icon) {
            if composing {
                store.closeComposer()
            } else if showingInlineAnswer {
                store.dismissInlineAnswer()
            } else {
                back(s)
            }
        }
    }

    private func back(_ s: CGFloat) {
        if store.revealingThreadID != nil, s >= 0.5 {
            toCanvas()                        // mid-collapse → snap back to canvas
        } else {
            store.navigateBack()              // pop the back stack (canvas / trip / home)
        }
    }

    private func toCanvas() {
        withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
    }

    @ViewBuilder private func rightControl(_ s: CGFloat) -> some View {
        let overflowProgress = smoothstep(ramp(s, 1.35, 2))

        ZStack(alignment: .trailing) {
            GlassCircleButton(icon: "history") {
                toTrip()
            }
            .opacity(1 - overflowProgress)
            .allowsHitTesting(overflowProgress < 0.5)

            Menu {
                Button {
                    store.openComposer()
                } label: {
                    Label("New search", systemImage: "plus")
                }
            } label: {
                EGDSIcon("more_vert", size: 18)
                    .foregroundStyle(Theme.figmaInk)
                    .frame(width: 44, height: 44)
                    .background(composerControlFill())
                    .shadow(color: Theme.ink.opacity(0.08), radius: 16, y: 12)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More options")
            .opacity(overflowProgress)
            .allowsHitTesting(overflowProgress >= 0.5)
        }
        .frame(width: 44, height: 44)
    }
}
