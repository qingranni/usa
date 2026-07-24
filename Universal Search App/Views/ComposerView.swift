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
    /// Width of the placeholder text, so it can be centred inside the pill at
    /// entrance 0 and slide to leading as the surface docks.
    @State private var placeholderWidth: CGFloat = 0

    /// Add-image drawer state. Opening it grows the docked surface upward to open
    /// a gap below the field where the picker (menu → photo grid) renders inline.
    @State private var addImagePage: AddImageSheetPage? = nil
    @State private var addImageDraft: [String] = []
    @State private var attachedImages: [String] = []

    /// Height of the in-surface gap the inline add-image MENU fills (0 otherwise;
    /// the photo grid is a modal sheet, not this gap).
    private var addImageDrawerHeight: CGFloat {
        addImagePage == .menu ? 400 : 0
    }

    /// Entrance morph: 0 = the resting follow-up pill · 1 = the docked composer.
    /// ONE surface (the real composer) grows and reshapes across this range.
    private var e: MorphProgress { progress(of: store.composerEntrance) }

    /// 0 = docked · 1 = full home-style takeover. Same surface keeps growing.
    private var p: MorphProgress { progress(of: store.composerReveal) }

    /// The resting follow-up pill rect (root space). Falls back to the dock's
    /// resting slot if it wasn't captured on this surface.
    private var entrancePill: CGRect {
        if store.followUpPillFrame != .zero { return store.followUpPillFrame }
        let h: CGFloat = 50
        let w = metrics.size.width - 64
        let y = metrics.H - metrics.safeBottom - 40 - h / 2
        return CGRect(x: 32, y: y, width: w, height: h)
    }

    // MARK: - Surface geometry (pill → docked → full)

    /// Explicit docked-sheet height: the field's docked content (top 28 + editor
    /// ~50 + gap 20 + action row 50+12 + bottom 12 = 172) plus keyboard clearance.
    /// The 12pt bottom leaves a 24pt gap between the action row and the keyboard
    /// (12pt action-row bottom padding + 12pt field bottom). Explicit — so the
    /// surface never re-measures content per frame (the old `.fixedSize` +
    /// GeometryReader jank source).
    private var dockedHeight: CGFloat {
        172 + max(keyboardHeight, addImageDrawerHeight, metrics.safeBottom)
    }

    /// Full-width, bottom-anchored docked sheet.
    private var dockedRect: CGRect {
        let h = min(dockedHeight, metrics.H)
        return CGRect(x: 0, y: metrics.H - h, width: metrics.size.width, height: h)
    }

    /// Full-screen takeover.
    private var fullRect: CGRect {
        CGRect(x: 0, y: 0, width: metrics.size.width, height: metrics.H)
    }

    /// The surface rect for the current (entrance, reveal): pill → docked → full.
    private var surfaceRect: CGRect {
        let revealRect = lerpRect(dockedRect, fullRect, p.eased)
        return lerpRect(entrancePill, revealRect, e.eased)
    }

    /// The morphing background: pill capsule → rounded-top sheet.
    private func surfaceShape(pillRadius: CGFloat) -> UnevenRoundedRectangle {
        let top = e.lerp(pillRadius, 48)
        let bottom = e.lerp(pillRadius, 0)
        return UnevenRoundedRectangle(topLeadingRadius: top,
                                      bottomLeadingRadius: bottom,
                                      bottomTrailingRadius: bottom,
                                      topTrailingRadius: top,
                                      style: .continuous)
    }

    var body: some View {
        let launchExit = store.launching && store.launchFromCurrent && store.launchPhase == .collapsing
        let exit = progress(of: store.launch, in: 0...AppStore.launchBlackoutEnd)

        ZStack(alignment: .topLeading) {
            // Tap-to-dismiss scrim above the shrunken canvas (docked only).
            Color.black.opacity(0.0001)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !store.launching, p.eased < 0.5 else { return }
                    Haptics.impact(.light)
                    store.closeComposer()
                }
                .transition(.opacity)

            surface
        }
        .offset(y: launchExit ? exit.lerp(0, metrics.H * 0.34) : 0)
        .opacity(launchExit ? exit.fadeOut : 1)
        .allowsHitTesting(!store.launching)
        .ignoresSafeArea(.keyboard)
        // Both entrance and exit are the surface morph itself (pill↔docked↔full),
        // so no slide transition — it would fight the reverse morph on close.
        .transition(.identity)
        .composerDismissGesture(store)
        .background(measurementProbe)
        .onAppear {
            Haptics.impact(.light)
            // Grow the pill outward into the docked composer. Runs here (not in the
            // store) so the just-mounted surface tweens from entrance 0.
            withAnimation(Theme.springMorph) { store.composerEntrance = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let overlap = max(0, UIScreen.main.bounds.maxY - frame.minY)
            // Same spring as the entrance morph so the keyboard slides in WITH the
            // surface rather than on a separate curve.
            withAnimation(Theme.springMorph) { keyboardHeight = overlap }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(Theme.springMorph) { keyboardHeight = 0 }
        }
        .onChange(of: addImagePage) { old, new in
            // Seed the grid's in-progress selection from the committed set on open.
            if old == nil, new != nil { addImageDraft = attachedImages }
        }
        .sheet(isPresented: photoSheetPresented) {
            AddImagePhotoSheet(
                catalog: AddImageCatalog.photos,
                draft: $addImageDraft,
                onBack: { addImagePage = .menu },
                onAdd: {
                    withAnimation(Theme.springSoft) {
                        attachedImages = addImageDraft
                        addImagePage = nil
                    }
                }
            )
        }
    }

    /// True while the photo grid sheet is up. Swiping it down closes the flow.
    private var photoSheetPresented: Binding<Bool> {
        Binding(
            get: { addImagePage == .photos },
            set: { if !$0, addImagePage == .photos { addImagePage = nil } }
        )
    }

    // MARK: - The single morphing surface

    private var surface: some View {
        let rect = surfaceRect
        let pillRadius = entrancePill.height / 2
        let shape = surfaceShape(pillRadius: pillRadius)
        // Frost (pill glass) dissolves to flat white as it opens.
        let frost = Double(e.inverted.eased)
        // Real controls / cursor fade in over the back half of the entrance so the
        // pill reads as reshaping, not a sheet appearing.
        let contentIn = Double(e.window(0.4...0.95).fadeIn)
        let shadowOpacity = e.lerp(0, 0.12)

        return ZStack(alignment: .topLeading) {
            shape.fill(.white)
            // fauxGlass treatment (matches the resting pill) fading out as it opens.
            shape.fill(.thinMaterial).opacity(frost)
            shape.fill(
                LinearGradient(colors: [.white.opacity(0.25), .white.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            ).opacity(frost)
            shape.strokeBorder(.white, lineWidth: 1).opacity(frost)

            // The REAL field + controls, laid out at full width so its height is
            // stable regardless of the (narrower) pill window; revealed as the
            // surface grows.
            fieldContent
                .frame(width: metrics.size.width, alignment: .topLeading)
                .opacity(contentIn)

            // The single placeholder that scales 14 → 16 → 20 and slides
            // centred (pill) → leading (docked/full). This is the through-line
            // that makes the pill and composer read as one item.
            placeholder(in: rect)

            // Add-image MENU rendered inline in the gap the surface opened below
            // the field. The photo grid is a separate overlay sheet (see body).
            if addImagePage == .menu {
                AddImageMenuView(
                    onPhotos: { withAnimation(Theme.springSoft) { addImagePage = .photos } },
                    onClose: { withAnimation(Theme.springSoft) { addImagePage = nil } }
                )
                .frame(width: rect.width, height: addImageDrawerHeight)
                .padding(.bottom, metrics.safeBottom)
                .frame(width: rect.width, height: rect.height, alignment: .bottom)
                .opacity(contentIn)
                .transition(.opacity)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .clipShape(shape)
        .shadow(color: Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255).opacity(shadowOpacity),
                radius: 32, x: 0, y: 6)
        .shadow(color: Theme.pillGlow.opacity(frost), radius: 5, x: 0, y: 1)
        .position(x: rect.midX, y: rect.midY)
    }

    /// The inline-chip field + its controls, with the reveal-driven docked→full
    /// paddings/gap. Placeholder is drawn separately (see `placeholder`).
    private var fieldContent: some View {
        ChipComposerField(text: $store.composerText,
                          chipSummary: $chipSummary,
                          onSubmit: submit,
                          focusDelay: 0.25,
                          middleGap: p.lerp(20, 224),
                          fullViewProgress: p.eased,
                          // The field draws its OWN placeholder once docked — it's
                          // positioned by the text system so it sits exactly on the
                          // cursor. The external scaling placeholder only covers the
                          // pill→docked entrance (see `placeholder`).
                          showsFieldPlaceholder: true,
                          addImagePage: $addImagePage,
                          attachedImages: $attachedImages)
            .padding(.horizontal, p.lerp(36, 28))
            .padding(.top, p.lerp(28, 101))
            .padding(.bottom, p.lerp(12, 14) + max(keyboardHeight, addImageDrawerHeight, metrics.safeBottom))
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The pill's placeholder for the pill→docked entrance ONLY: it starts centred
    /// in the pill (14pt) and slides to the field's leading text origin (16pt),
    /// fading out as the field's own (cursor-aligned) placeholder fades in — so the
    /// two hand off seamlessly and the docked placeholder sits exactly on the cursor.
    @ViewBuilder
    private func placeholder(in rect: CGRect) -> some View {
        if store.composerText.trimmingCharacters(in: .whitespaces).isEmpty
            && chipSummary.trimmingCharacters(in: .whitespaces).isEmpty {
            let font = e.lerp(14, 16)
            // Leading: the field's text origin (≈36) at docked; centred in the pill
            // at entrance 0 using the measured text width.
            let dockedLeading: CGFloat = 36
            let pillLeading = max(0, (entrancePill.width - placeholderWidth) / 2)
            let leading = e.lerp(pillLeading, dockedLeading)
            // Top: vertically centred in the 50pt pill → the field's text top at docked.
            let dockedTop: CGFloat = 28 + 4
            let pillTop = max(0, (entrancePill.height - font * 1.3) / 2)
            let top = e.lerp(pillTop, dockedTop)

            Text(store.composerPrompt)
                .font(.centra(size: font, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .fixedSize()
                .padding(.leading, leading)
                .padding(.top, top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // Hand off to the field's own placeholder as it docks.
                .opacity(Double(e.window(0.6...0.85).fadeOut))
                .allowsHitTesting(false)
        }
    }

    /// Off-screen probe measuring the placeholder width (at the pill font) so it
    /// can be centred inside the pill at entrance 0.
    private var measurementProbe: some View {
        Text(store.composerPrompt)
            .font(.centra(size: 14, weight: .medium))
            .fixedSize()
            .hidden()
            .allowsHitTesting(false)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { placeholderWidth = g.size.width }
                    .onChange(of: store.composerPrompt) { _, _ in
                        placeholderWidth = g.size.width
                    }
            })
    }

    private var canSend: Bool {
        // Attached images alone are enough to submit ("treat it as filled").
        !attachedImages.isEmpty
            || !(store.composerText + " " + chipSummary).trimmingCharacters(in: .whitespaces).isEmpty
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
