//
//  Theme.swift
//  Universal Search App
//
//  Design tokens ported 1:1 from the React prototype's v1.css (:root) and the
//  three motion springs from motion.js. Tune here; every view follows.
//

import SwiftUI
import UIKit

enum Theme {

    // ---- colors (exact Figma values from v1.css) ----
    /// #0C0E1C — primary dark ink / dark background.
    static let ink = Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)

    /// #0C0E1C — the navy ink used on the light "query playback" card (Figma
    /// 1214-13455). Slightly lighter than `ink`; text/icons on white surfaces.
    static let figmaInk = Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255)
    /// rgba(12,14,28,0.5) — muted navy ("Refine", secondary text on white).
    static let figmaInkMuted = figmaInk.opacity(0.5)
    /// rgba(12,14,28,0.05) — filter-chip / icon-button fill on white.
    static let figmaChipFill = figmaInk.opacity(0.05)
    /// #F9F7F6 — solid warm off-white for the canvas/result filter chips.
    static let canvasFilterChipFill = Color(red: 0xF9 / 255, green: 0xF7 / 255, blue: 0xF6 / 255)

    /// #F7F4F3 — the trip overview's list-row surface (warm off-white).
    static let cardItem = Color(red: 0xF7 / 255, green: 0xF4 / 255, blue: 0xF3 / 255)
    /// rgba(12,14,28,0.5)
    static let inkMuted = Color(red: 12 / 255, green: 14 / 255, blue: 28 / 255).opacity(0.5)
    /// Pure black — the screen backdrop behind the inset cards (Figma 1214-13455).
    static let darkBG = Color.black
    /// rgba(255,255,255,0.05) — subtle card surface on dark screens.
    static let darkSurface = Color.white.opacity(0.05)
    /// Opaque dark card (a touch lighter than the bg) — used for the details
    /// panel and the notification-style stack frames so they read as cards.
    static let cardSurface = Color(red: 30 / 255, green: 33 / 255, blue: 50 / 255)
    static let darkText = Color.white
    /// rgba(255,255,255,0.5)
    static let darkTextMuted = Color.white.opacity(0.5)

    /// Tint used inside the light glass gradient (rgba(233,239,248,…)).
    static let glassTint = Color(red: 233 / 255, green: 239 / 255, blue: 248 / 255)

    /// #676A7D — muted label on white lodging cards ("Includes taxes and fees",
    /// per-night rate). Figma node 1539-5566.
    static let onSurfaceVariant = Color(red: 0x67 / 255, green: 0x6A / 255, blue: 0x7D / 255)

    // ---- corner radii ----
    static let radiusCard: CGFloat = 32
    static let radiusChip: CGFloat = 100   // effectively a capsule
    static let radiusPill: CGFloat = 300   // effectively a capsule
    /// Redesigned lodging result card (white container) + its inset image.
    static let radiusHotelCard: CGFloat = 24
    static let radiusHotelImage: CGFloat = 16

    // ---- shadows ----
    /// --v1-shadow-card: 0 2.5px 25px rgba(0,0,0,0.25)
    static let cardShadow = Color.black.opacity(0.25)
    static let cardShadowRadius: CGFloat = 25
    static let cardShadowY: CGFloat = 2.5

    /// Softer ambient lift for white lodging cards on a light backdrop.
    static let hotelCardShadow = Color.black.opacity(0.08)
    static let hotelCardShadowRadius: CGFloat = 18
    static let hotelCardShadowY: CGFloat = 6

    /// --v1-shadow-pill glow color (#e9eff8 family).
    static let pillGlow = Color(red: 193 / 255, green: 201 / 255, blue: 214 / 255).opacity(0.25)

    // ---- device frame (iPhone 16/17 Pro logical size) ----
    static let frameWidth: CGFloat = 402
    static let frameHeight: CGFloat = 874

    // ---- motion springs ----
    // Framer {stiffness,damping,mass} → SwiftUI response/dampingFraction:
    //   response = 2π·√(mass/stiffness),  dampingFraction = damping / (2·√(stiffness·mass))

    /// Primary: screen depth-stack transitions & shared-element card morphs.
    /// motion.js SPRING (320, 34, 0.9) → response 0.333, damping ~1.0.
    static let springPrimary = Animation.spring(response: 0.333, dampingFraction: 1.0)

    /// Softer: lighter content (cards easing in). SPRING_SOFT (260, 30, 1).
    static let springSoft = Animation.spring(response: 0.39, dampingFraction: 0.93)

    /// Large surface morphs (pill <-> panel, sheet slide, canvas <-> card). A
    /// sharp cubic-bezier (CSS cubic-bezier(0.75, 0, 0, 1)) instead of a spring:
    /// it accelerates hard and settles fast with no overshoot, so live-map morphs
    /// spend less time mid-transition (less visible MapKit tile jitter).
    static let springMorph = Animation.timingCurve(0.75, 0, 0, 1, duration: 0.75)
    /// The Mexico → Cancun map fly (beat 1 of the card→packages transition). Same
    /// cubic-bezier as `springMorph` but a touch slower so the shift reads as a
    /// deliberate, cinematic beat before the pins settle in.
    static let mapFly = Animation.timingCurve(0.75, 0, 0, 1, duration: 1.0)
    /// Composer-initiated card swap. Same curve as the main morph, stretched 3x
    /// so the outgoing/incoming cards read more deliberately during loading.
    static let springMorphCardSwap = Animation.timingCurve(0.75, 0, 0, 1, duration: 1.5)
    /// Package-detail hero morph. A long, gentle ease (soft in, long settle) so
    /// the image glides into place and the windowed content beats read one after
    /// another. Slow and cinematic by design; beats are spaced across the driver.
    static let springDetailMorph = Animation.timingCurve(0.4, 0.0, 0.18, 1.0, duration: 1.55)
    /// Soft blur that peaks mid-morph and resolves to sharp endpoints.
    static let morphBlurRadius: CGFloat = 3.5
    /// The main canvas surface can carry a little more blur because it is the
    /// primary scaled layer during card <-> results transitions.
    static let canvasMorphBlurRadius: CGFloat = 6.5
    /// Composer/home loading handoff: the centered card starts blurred, then the
    /// canvas settles sharp as it expands into readable results.
    static let canvasLaunchSettleBlurRadius: CGFloat = 9

    /// Siri-style canvas shrink behind the composer. A touch slower and fully
    /// critically damped (no overshoot) so the whole flattened canvas eases down
    /// smoothly instead of snapping or wobbling.
    static let springCanvas = Animation.spring(response: 0.5, dampingFraction: 1.0)

    /// Generic short crossfade used by the thread head title<->query swap.
    static let fade = Animation.easeInOut(duration: 0.18)
}

extension Color {
    /// Linear sRGB interpolation `a`→`b` by `t` (0…1). Used to morph the open
    /// overview's surface/text from the dark collapsed row to the light query card.
    static func mix(_ a: Color, _ b: Color, _ t: CGFloat) -> Color {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(a).getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        UIColor(b).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(red: lerp(ar, br, t), green: lerp(ag, bg, t),
                     blue: lerp(ab, bb, t), opacity: lerp(aa, ba, t))
    }
}
