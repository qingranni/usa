//
//  HomeComposerCover.swift
//  Universal Search App
//
//  The homepage composer, presented as a full-screen cover that zooms out of the
//  home search pill (`EmptySearchView` owns the `.matchedTransitionSource` /
//  `.navigationTransition(.zoom)` pair). The OS drives the entire pill → page
//  morph, so this view is just the resting full composer — no hand-built morph
//  surface, no entrance state, no cross-fade handoff.
//
//  The full treatment mirrors the 402×874 Figma frames: the default 547pt white
//  input card nearly meets the keyboard. Once composing starts it retracts to
//  461pt, revealing the warm predictive-input strip above the keys.
//
//  It reuses the real `ChipComposerField`. The empty home state shows the Figma
//  trip-starter carousel; after typing, chips, predictions, and submit behavior
//  remain shared with the docked composer.
//

import SwiftUI
import UIKit

struct HomeComposerCover: View {
    @Bindable var store: AppStore
    let metrics: Metrics

    @Environment(\.dismiss) private var dismiss

    /// Chip labels from the inline-chip field, folded into the query on submit.
    @State private var chipSummary = ""
    @State private var submitting = false
    /// In-place voice "Listening…" state: the sheet retracts to reveal the gold +
    /// waveform strip and the field swaps its placeholder / mic. No modal.
    @State private var listening = false

    /// Add-image drawer state. Like `listening`, opening it retracts the card and
    /// renders the picker (menu → photo grid) in the beige gap below — no modal.
    @State private var addImagePage: AddImageSheetPage? = nil
    @State private var addImageDraft: [String] = []
    @State private var attachedImages: [String] = []

    private let loadBackground = Theme.cardItem
    private let chipVerticalSpacing: CGFloat = 20
    private let filterPillRowHeight: CGFloat = 52
    /// Gap above the keyboard revealed for the gold + waveform while listening.
    private let listeningGap: CGFloat = 132
    /// Mock dictation, committed to the composer on confirm — the real parser
    /// then turns it into chips. Ends on the destination so its chip surfaces.
    private let voiceMockPhrase = "A relaxing week in April for 2 adults in Tokyo"

    var body: some View {
        GeometryReader { geometry in
            // One constant card height in both the resting and composing states:
            // it always stops short of the keyboard so the quick-add chip row
            // rides the gap below it (Figma node 1910:20928). The viewport
            // (`geometry.size.height`) is already keyboard-reduced, so this
            // tracks the keyboard across devices.
            let restingCardHeight = max(
                320,
                geometry.size.height
                    - chipVerticalSpacing
                    - filterPillRowHeight
                    - chipVerticalSpacing
            )
            // Height of the beige gap the inline add-image MENU fills. Zero when
            // the menu is closed (the photo grid is a sheet, not this gap).
            let addImageGap: CGFloat = addImagePage == .menu ? 420 : 0
            // Listening / add-image menu both retract the card to open a gap below.
            let cardHeight: CGFloat = {
                if listening { return max(320, geometry.size.height - listeningGap) }
                if addImagePage == .menu { return max(220, geometry.size.height - addImageGap) }
                return restingCardHeight
            }()

            ZStack(alignment: .topLeading) {
                if submitting || store.launching {
                    loadBackground.ignoresSafeArea()
                } else {
                    Theme.cardItem.ignoresSafeArea()

                    // Morphing gold mesh + scrolling waveform, tucked behind the
                    // sheet and filling the gap above the keyboard while listening.
                    if listening {
                        VoiceGoldGlow()
                            .frame(height: listeningGap + 96)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            // Lift ONLY the gold so warm white shows between it and
                            // the keyboard. The waveform overlay is added after the
                            // offset, so it keeps its original position.
                            .offset(y: -52)
                            .overlay(alignment: .bottom) {
                                VoiceWaveformView()
                                    .frame(height: 26)
                                    .padding(.bottom, (listeningGap - 26) / 2)
                            }
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }

                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .fill(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: cardHeight)
                        .shadow(
                            color: Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)
                                .opacity(0.08),
                            radius: 32,
                            x: 0,
                            y: 12
                        )

                    // SwiftUI shortens this region for the keyboard. The field
                    // condenses its flexible middle space while the card height
                    // follows the keyboard-reduced viewport.
                    GeometryReader { _ in
                        ChipComposerField(text: $store.composerText,
                                          chipSummary: $chipSummary,
                                          onSubmit: submit,
                                          focusDelay: 0.35,
                                          flexesMiddleGap: true,
                                          showsHomeSuggestions: true,
                                          fullViewProgress: 1,
                                          isListening: listening,
                                          onMicTap: startListening,
                                          onVoiceCancel: cancelListening,
                                          onVoiceConfirm: confirmListening,
                                          addImagePage: $addImagePage,
                                          attachedImages: $attachedImages)
                    }
                    .padding(.horizontal, 32.5)
                    // Land the first text line 24pt below the close button.
                    // Close button occupies safeTop + 8 (top) + 44 (height); the
                    // editor adds a 4pt top inset, so subtract it here.
                    .padding(.top, metrics.safeTop + 8 + 44 + 24 - 4)
                    // Resting: 2pt trim below the pills. Listening: lift the ✕/✓
                    // row onto the retracted sheet, above the gold gap.
                    .padding(.bottom, listening ? listeningGap + chipVerticalSpacing : chipVerticalSpacing - 2)

                    closeButton
                        .padding(.leading, 32.5)
                        .padding(.top, metrics.safeTop + 8)

                    // The add-image MENU, rendered directly in the beige gap
                    // below the retracted card (no modal sheet). The photo grid
                    // is a separate overlay sheet (see `.sheet` below).
                    if addImagePage == .menu {
                        AddImageMenuView(
                            onPhotos: { withAnimation(Theme.springSoft) { addImagePage = .photos } },
                            onClose: { withAnimation(Theme.springSoft) { addImagePage = nil } }
                        )
                        .frame(height: addImageGap)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        // A downward drag dismisses (zooming back into the search pill).
        .gesture(
            DragGesture(coordinateSpace: .global)
                .onEnded { if !submitting, $0.translation.height > 80 { dismiss() } }
        )
        .onAppear { Haptics.impact(.light) }
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

    private var closeButton: some View {
        Button { Haptics.impact(.light); dismiss() } label: {
            EGDSIcon("xmark", size: 18)
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 44, height: 44)
                .background(composerControlFill())
                .shadow(color: Theme.ink.opacity(0.08), radius: 16, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice listening

    private func startListening() {
        withAnimation(Theme.springSoft) { listening = true }
    }

    private func cancelListening() {
        Haptics.impact(.light)
        withAnimation(Theme.springSoft) { listening = false }
    }

    private func confirmListening() {
        Haptics.impact(.medium)
        // Commit the mock transcript; the field's parser turns it into chips for
        // review. The editor kept focus throughout, so the keyboard stays up.
        store.composerText = voiceMockPhrase
        withAnimation(Theme.springSoft) { listening = false }
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
        submitting = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        // Mount the root loading surface synchronously BEFORE dismissing, so the
        // cover's zoom-back-to-pill reveals the load screen underneath instead of
        // a flash of the homepage while the async route resolves. `submitting`
        // keeps the cover's own surface on the same load background meanwhile.
        store.homeSubmitLoading = true
        dismiss()
        Task { await store.submitComposer() }
    }
}
