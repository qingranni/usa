//
//  FloatingPills.swift
//  Universal Search App
//
//  Shared floating glass controls used by the canvas and overview headers —
//  frosted white circular icon buttons (Figma rgba(255,255,255,0.8)) that sit
//  above the full-bleed cards.
//

import SwiftUI

/// Frosted white glass fill (a blur with a white tint on top, so it reads white
/// rather than the gray a bare material gives over photos).
func glassFill<S: Shape>(_ shape: S) -> some View {
    shape.fill(.ultraThinMaterial)
        .overlay(shape.fill(.white.opacity(0.75)))
}

/// A circular glass icon button. `action` nil → a plain (decorative) glyph.
struct GlassCircleButton: View {
    let icon: String
    var size: CGFloat = 44
    var action: (() -> Void)? = nil

    var body: some View {
        let glyph = EGDSIcon(icon, size: 22)
            .foregroundStyle(Theme.figmaInk)
            .frame(width: size, height: size)
            .background(glassFill(Circle()))
            // Subtle shadow (Figma) so it reads on both photos and white.
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        if let action {
            Button(action: action) { glyph }.buttonStyle(.plain)
        } else {
            glyph
        }
    }
}
