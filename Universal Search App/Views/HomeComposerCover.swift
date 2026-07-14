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

    private let loadBackground = Theme.cardItem
    private let chipVerticalSpacing: CGFloat = 20
    private let filterPillRowHeight: CGFloat = 52

    private var hasStartedComposing: Bool {
        !store.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !chipSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let composingCardHeight = max(
                320,
                geometry.size.height
                    - chipVerticalSpacing
                    - filterPillRowHeight
                    - chipVerticalSpacing
            )

            ZStack(alignment: .topLeading) {
                if submitting || store.launching {
                    loadBackground.ignoresSafeArea()
                } else {
                    Theme.cardItem.ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: hasStartedComposing ? composingCardHeight : 547)
                        .shadow(
                            color: Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)
                                .opacity(0.08),
                            radius: 32,
                            x: 0,
                            y: 12
                        )
                        .animation(
                            .spring(response: 0.42, dampingFraction: 0.9),
                            value: hasStartedComposing
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
                                          fullViewProgress: 1)
                    }
                    .padding(.horizontal, 32.5)
                    .padding(.top, 101)
                    // The pill scroll view contributes 2pt below its contents.
                    .padding(.bottom, chipVerticalSpacing - 2)

                    closeButton
                        .padding(.leading, 32.5)
                        .padding(.top, metrics.safeTop + 8)
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
    }

    private var closeButton: some View {
        Button { Haptics.impact(.light); dismiss() } label: {
            EGDSIcon("xmark", size: 18)
                .foregroundStyle(Theme.figmaInk)
                .frame(width: 44, height: 44)
                .background {
                    ZStack {
                        Circle().fill(Theme.cardItem)
                        Circle().fill(
                            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    }
                }
                .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                .shadow(color: Theme.ink.opacity(0.08), radius: 16, x: 0, y: 12)
        }
        .buttonStyle(.plain)
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
        submitting = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        // Swap to the loading surface before dismissing so the native cover
        // transition cannot show composer chrome during the root load sequence.
        dismiss()
        Task { await store.submitComposer() }
    }
}
