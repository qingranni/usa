//
//  GlassPill.swift
//  Universal Search App
//
//  Frosted glass search / follow-up pill (Figma). Fills the frame its parent
//  gives it (parents drive the width/height morphs); two variants:
//    .empty    — text field + send arrow (initial search screen)
//    .followup — centered "Follow up" field, no arrow
//  `isDark` swaps to the subtle dark-glass treatment used on dark screens.
//

import SwiftUI

struct GlassPill: View {
    enum Variant { case empty, followup }

    let variant: Variant
    var isDark: Bool = false
    var loading: Bool = false
    /// Placeholder shown while `loading`. Defaults to the generic "Thinking…";
    /// the homepage launch pill overrides this with "Searching…".
    var loadingText: String = Copy["search.thinking"]
    let onSend: (String) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    private var isEmpty: Bool { variant == .empty }

    var body: some View {
        HStack(spacing: 12) {
            TextField("", text: $text, prompt: prompt)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .disabled(loading)
                .submitLabel(.send)
                .onSubmit(submit)
                .font(.centra(size: isEmpty ? 16 : 14))
                .multilineTextAlignment(isEmpty ? .leading : .center)
                .foregroundStyle(isDark ? Theme.darkText : Theme.ink)
                .tint(isDark ? Theme.darkText : Theme.ink)

            if isEmpty {
                Button(action: submit) {
                    EGDSIcon("arrow_forward", size: 22)
                        .font(.centra(size: 22, weight: .regular))
                        .foregroundStyle(Theme.ink)
                }
                .disabled(loading || text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(loading || text.trimmingCharacters(in: .whitespaces).isEmpty ? 0.35 : 1)
            }
        }
        .padding(.horizontal, isEmpty ? 36 : 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(GlassBackground(isDark: isDark))
    }

    private var prompt: Text {
        let s = loading ? loadingText
                        : (isEmpty ? Copy["search.placeholder"] : Copy["search.followUp"])
        return Text(s).foregroundColor(isDark ? Theme.darkTextMuted : Theme.inkMuted)
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !loading else { return }
        onSend(trimmed)
        text = ""
    }
}

/// The pill's frosted/dark capsule treatment. Light pills use iOS 26 Liquid
/// Glass; dark pills use a subtle gradient (no blur/glow), per v1.css.
private struct GlassBackground: ViewModifier {
    let isDark: Bool

    func body(content: Content) -> some View {
        if isDark {
            content
                .background(
                    LinearGradient(
                        colors: [Theme.glassTint.opacity(0.19), Theme.glassTint.opacity(0.13)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    in: Capsule()
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.05), lineWidth: 1))
        } else {
            // Light frosted glass: blurred material + a faint white→blue gradient
            // tint (matches v1.css --v1-glass-fill). Chosen over iOS 26
            // `.glassEffect()`, which renders heavy/gray over the white empty
            // screen; the material reads lighter and closer to the Figma frost.
            content
                .background {
                    ZStack {
                        Capsule().fill(.ultraThinMaterial)
                        Capsule().fill(
                            LinearGradient(
                                colors: [Theme.glassTint.opacity(0.25), Theme.glassTint.opacity(0.125)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    }
                }
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                .shadow(color: Theme.pillGlow, radius: 5, x: 0, y: 1)
        }
    }
}
