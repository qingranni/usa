//
//  ComposerView.swift
//  Universal Search App
//
//  The AI composer launched by tapping the follow-up input on any non-home
//  screen (Figma node 1483:3805). This is a Siri-style presentation: RootView
//  scales the live canvas straight down behind us, and the composer rides in as
//  a sheet OVER it — a tap-to-dismiss scrim exposes the shrunken canvas above,
//  the input sheet hugs the bottom just over the keyboard. The global nav
//  toolbar stays mounted and unchanged over the top. Dragging up morphs the
//  sheet into the full-screen home-style search takeover
//  (`store.composerReveal` 0 -> 1).
//

import SwiftUI

struct ComposerView: View {
    @Bindable var store: AppStore
    let metrics: Metrics

    /// Chip labels from the inline-chip field, folded into the query on submit.
    @State private var chipSummary = ""
    /// Keyboard overlap (points). Tracked manually because the root ZStack
    /// ignores the keyboard safe area, so automatic avoidance is disabled here.
    @State private var keyboardHeight: CGFloat = 0

    /// Entrance morph: 0 = the follow-up pill, 1 = the docked composer sheet. A
    /// geometric surface (see `ComposerMorphSurface`) grows the pill's rounded
    /// rect into the sheet while the real controls fade in slightly behind it.
    @State private var entrance: CGFloat = 0
    /// Fades the real sheet controls in behind the growing surface, so full-size
    /// text/rows never flash over a still-small pill.
    @State private var contentIn: CGFloat = 0
    /// Docked sheet frame (root space) — the entrance morph's target rect.
    @State private var dockedFrame: CGRect = .zero

    /// 0 = split composer over the canvas card, 1 = full home-style takeover.
    private var p: MorphProgress { progress(of: store.composerReveal) }

    /// The entrance morph's source pill: the shared follow-up pill.
    private var entrancePill: CGRect { store.followUpPillFrame }

    /// The morph surface's target rect: the captured docked sheet frame (falling
    /// back to the pill until it's measured, so a not-yet-captured `.zero` frame
    /// doesn't collapse the morph).
    private var morphTarget: CGRect {
        dockedFrame == .zero ? entrancePill : dockedFrame
    }

    var body: some View {
        let launchExit = store.launching && store.launchFromCurrent && store.launchPhase == .collapsing
        let exit = progress(of: store.launch, in: 0...AppStore.launchBlackoutEnd)

        ZStack(alignment: .bottom) {
            // Exposes the shrunken canvas above the sheet; tapping it dismisses
            // (only while docked — once dragged toward the home takeover a tap
            // shouldn't collapse everything).
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !store.launching, p.eased < 0.5 else { return }
                    Haptics.impact(.light)
                    store.closeComposer()
                }
                .transition(.opacity)

            // No bottom padding: the sheet runs all the way to the screen bottom
            // and tucks UNDER the keyboard (its content is lifted above the
            // keyboard from the inside), so there's no rounded bottom edge
            // floating in a gap above the keys.
            composerSheet
                // Real controls fade in behind the growing surface; the surface
                // provides the white page during the pill→sheet morph. Only the
                // full takeover (drag up) uses the slide transition on removal.
                .opacity(Double(contentIn))
                .captureFrame { dockedFrame = $0 }

            // The pill lifting off and expanding into the docked sheet. An exact
            // geometric stand-in (frosted capsule → white rounded-top sheet) so
            // the morph reads as one fluid grow; retired once the real controls
            // have faded in.
            if contentIn < 0.999, entrancePill != .zero {
                ComposerMorphSurface(progress: entrance,
                                     pill: entrancePill,
                                     docked: morphTarget)
                    .allowsHitTesting(false)
            }
        }
        .offset(y: launchExit ? exit.lerp(0, metrics.H * 0.34) : 0)
        .opacity(launchExit ? exit.fadeOut : 1)
        .allowsHitTesting(!store.launching)
        .ignoresSafeArea(.keyboard)
        .transition(.asymmetric(insertion: .identity,
                                removal: .move(edge: .bottom).combined(with: .opacity)))
        // From home the composer is always full — a downward drag dismisses it.
        // From other screens it scrubs the condensed↔expanded reveal, with a
        // drag-down past the docked bottom dismissing.
        .composerDismissGesture(store)
        .onAppear {
            Haptics.impact(.light)
            withAnimation(Theme.springMorph) { entrance = 1 }
            withAnimation(.easeOut(duration: 0.28).delay(0.12)) { contentIn = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let overlap = max(0, UIScreen.main.bounds.maxY - frame.minY)
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = overlap }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { keyboardHeight = 0 }
        }
    }

    // MARK: - composer sheet

    private var composerSheet: some View {
        // Medium keeps the original compact 20pt run. At full, 224pt places the
        // action at y=375 and the quick actions at y=483 in the 402×874 frame.
        let gap = p.lerp(20, 224)
        return VStack(alignment: .leading, spacing: 0) {
            // Inline-chip composer: type a query and recognized destinations /
            // dates / guests become active chips embedded in the text. It owns
            // its own controls (smart filter pills + an inline mic/send button),
            // so there's no separate bottom action row.
            //
            // The interpolated `gap` is threaded INTO the field (between the
            // input and its filter pills) rather than trailing the whole field,
            // so the action pills ride the top of the keyboard while the gap
            // grows the docked sheet up into the full takeover. It's a fixed
            // interpolated height (NOT a Spacer): a Spacer would grab the whole
            // proposed height and blow the docked sheet up to full screen.
            ChipComposerField(text: $store.composerText,
                              chipSummary: $chipSummary,
                              onSubmit: submit,
                              focusDelay: 0.4,
                              middleGap: gap,
                              fullViewProgress: p.eased)
        }
        // The full quick actions start at x=28 while the field adds an internal
        // 8pt inset to retain the query's x=36 alignment.
        .padding(.horizontal, p.lerp(36, 28))
        .padding(.top, p.lerp(28, 101))
        // Lift the content above the keyboard from the inside; the white
        // medium sheet still keeps its original 40pt breather. Full uses the
        // Figma's 14pt gap between the action pills and native keyboard.
        .padding(.bottom, p.lerp(40, 14) + max(keyboardHeight, metrics.safeBottom))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // Always hug the (interpolated) content height so the docked sheet stays
        // small and the whole thing grows purely via `gap`.
        .fixedSize(horizontal: false, vertical: true)
        .background(alignment: .top) {
            GeometryReader { geo in
                let surfaceHeight = p.lerp(geo.size.height, min(461, geo.size.height))
                let bottomRadius = p.lerp(0, 48)

                UnevenRoundedRectangle(
                    topLeadingRadius: 48,
                    bottomLeadingRadius: bottomRadius,
                    bottomTrailingRadius: bottomRadius,
                    topTrailingRadius: 48,
                    style: .continuous
                )
                .fill(.white)
                .frame(height: surfaceHeight)
                .shadow(
                    color: Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)
                        .opacity(0.12 * Double(p.eased)),
                    radius: 36 * p.eased,
                    x: 0,
                    y: 6 * p.eased
                )
            }
        }
    }

    private var canSend: Bool {
        !(store.composerText + " " + chipSummary).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard canSend else { return }
        Haptics.impact(.medium)
        // Fold the active chip labels into the query so the sent text carries the
        // structured selections (destination / dates / guests).
        let summary = chipSummary.trimmingCharacters(in: .whitespaces)
        if !summary.isEmpty {
            let base = store.composerText.trimmingCharacters(in: .whitespaces)
            store.composerText = base.isEmpty ? summary : base + " " + summary
        }
        Task { await store.submitComposer() }
    }
}

// MARK: - Entrance morph surface

/// The surface the follow-up pill grows into as the composer opens. Purely
/// geometric: it morphs the pill's frosted capsule up to the docked sheet's
/// white rounded-top rect and samples every interpolated frame via
/// `AnimatableMorph`, so the spring reads as one fluid grow. Collapsed it wears
/// the pill's frosted glass, gloss, hairline stroke, glow, and centred "Follow
/// up" label; all of those dissolve into a flat white sheet as it opens.
private struct ComposerMorphSurface: View {
    var progress: CGFloat
    let pill: CGRect
    let docked: CGRect

    var body: some View {
        AnimatableMorph(progress: progress) { p in
            let pillRadius = pill.height / 2
            // The docked sheet keeps 48pt top corners and squares off the bottom
            // under the keyboard.
            let topR = p.lerp(pillRadius, 48)
            let botR = p.lerp(pillRadius, 0)
            let shape = UnevenRoundedRectangle(topLeadingRadius: topR,
                                               bottomLeadingRadius: botR,
                                               bottomTrailingRadius: botR,
                                               topTrailingRadius: topR,
                                               style: .continuous)
            shape
                .fill(.white)
                .overlay {
                    // Collapsed pill treatment: the follow-up pill's frosted
                    // material, dissolving into the flat white sheet as it opens.
                    shape.fill(.ultraThinMaterial).opacity(p.inverted.eased)
                }
                .overlay {
                    shape.fill(
                        LinearGradient(colors: [Theme.glassTint.opacity(0.25),
                                                Theme.glassTint.opacity(0.125)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .opacity(p.inverted.eased)
                }
                .overlay {
                    Text(Copy["search.followUp"])
                        .font(.centra(size: 14, weight: .regular))
                        .foregroundStyle(Theme.inkMuted)
                        .opacity(p.window(0...0.35).fadeOut)
                }
                .overlay(shape.strokeBorder(.white.opacity(0.8), lineWidth: 1)
                    .opacity(p.inverted.eased))
                .shadow(color: Theme.pillGlow.opacity(Double(p.inverted.eased)),
                        radius: 5, x: 0, y: 1)
                .morphFrame(from: pill, to: docked, progress: p)
        }
    }
}

// MARK: - Dismiss gesture

private extension View {
    /// The composer's dismiss/scrub gesture: it scrubs the condensed↔expanded
    /// reveal 1:1 with the finger (drag up grows toward the full takeover), and a
    /// drag-down past the docked bottom dismisses.
    func composerDismissGesture(_ store: AppStore) -> some View {
        morphScrub(Binding(get: { store.composerReveal },
                           set: { store.composerReveal = $0 }),
                   over: 0...1, distance: -260) { target, start, drag in
            if start < 0.5, target == 0, drag.translation.height > 80 {
                store.closeComposer()
                return
            }
            withAnimation(Theme.springMorph) { store.composerReveal = target }
        }
    }
}
