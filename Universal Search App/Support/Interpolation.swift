//
//  Interpolation.swift
//  Universal Search App
//
//  Small math helpers for the reveal-driven morph.
//

import CoreGraphics

/// Clamp `x` into [lo, hi].
func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(x, lo), hi) }

/// Linear interpolation a→b by t (t unclamped).
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

/// Normalize `x` from [lo, hi] to [0, 1], clamped.
func ramp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
    guard hi > lo else { return x < lo ? 0 : 1 }
    return clamp((x - lo) / (hi - lo), 0, 1)
}

/// Smoothstep easing of a 0…1 value.
func smoothstep(_ t: CGFloat) -> CGFloat {
    let x = clamp(t, 0, 1)
    return x * x * (3 - 2 * x)
}

/// Per-component rect interpolation.
func lerpRect(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    CGRect(x: lerp(a.minX, b.minX, t),
           y: lerp(a.minY, b.minY, t),
           width: lerp(a.width, b.width, t),
           height: lerp(a.height, b.height, t))
}
