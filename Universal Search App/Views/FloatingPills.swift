//
//  FloatingPills.swift
//  Universal Search App
//
//  Shared floating glass controls used by the canvas and overview headers —
//  frosted white circular icon buttons (Figma rgba(255,255,255,0.8)) that sit
//  above the full-bleed cards.
//

import SwiftUI

/// Reusable faux-glass treatment: stronger frost, a 25%→75% white sheen, and a
/// fully opaque white hairline.
struct FauxGlass<S: InsettableShape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background {
                shape
                    .fill(.thinMaterial)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
            }
            .overlay(shape.strokeBorder(.white, lineWidth: 1))
    }
}

extension View {
    func fauxGlass<S: InsettableShape>(in shape: S) -> some View {
        modifier(FauxGlass(shape: shape))
    }
}

/// Frosted white glass fill (a blur with a white tint on top, so it reads white
/// rather than the gray a bare material gives over photos).
func glassFill<S: Shape>(_ shape: S) -> some View {
    shape.fill(.ultraThinMaterial)
        .overlay(shape.fill(.white.opacity(0.75)))
}

/// Warm raised surface shared by composer and Activity controls.
func composerControlFill() -> some View {
    ZStack {
        Circle().fill(Theme.cardItem)
        Circle().fill(
            LinearGradient(
                colors: [.white.opacity(0), .white.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    .overlay(Circle().strokeBorder(.white, lineWidth: 1))
}

/// A circular glass icon button. `action` nil → a plain (decorative) glyph.
struct GlassCircleButton: View {
    let icon: String
    var size: CGFloat = 44
    var action: (() -> Void)? = nil

    private var isActivityButton: Bool {
        icon == "history"
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isActivityButton {
            composerControlFill()
        } else {
            glassFill(Circle())
        }
    }

    var body: some View {
        let glyph = EGDSIcon(icon, size: isActivityButton ? 20 : 22)
            .foregroundStyle(Theme.figmaInk)
            .frame(width: size, height: size)
            .background(buttonBackground)
            // Subtle shadow (Figma) so it reads on both photos and white.
            .shadow(
                color: Theme.ink.opacity(0.08),
                radius: isActivityButton ? 16 : 6,
                y: isActivityButton ? 12 : 2
            )
        if let action {
            Button(action: action) { glyph }.buttonStyle(.plain)
        } else {
            glyph
        }
    }
}
