//
//  MorphProgress.swift
//  Universal Search App
//
//  The core morph vocabulary: a normalized 0…1 slice of a continuous driver
//  (`store.reveal`, `store.composerReveal`, a local @State). Every morph derives
//  its geometry and opacity from one of these instead of hand-rolling
//  `smoothstep(clamp(…))` / `ramp(…)` chains. See MORPHS.md for the playbook.
//

import CoreGraphics

struct MorphProgress {
    /// The windowed driver, normalized to 0…1 (clamped, unsmoothed).
    let linear: CGFloat

    /// Slice `driver` over `window`: 0 at/below the lower bound, 1 at/above the
    /// upper bound. `progress(of: reveal, in: 1...2)` is 0 at the overview and
    /// 1 at the trip.
    init(_ driver: CGFloat, in window: ClosedRange<CGFloat> = 0...1) {
        linear = ramp(driver, window.lowerBound, window.upperBound)
    }

    private init(linear: CGFloat) { self.linear = linear }

    /// Hermite-eased progress — use for geometry (frames, radii, scales, fonts).
    var eased: CGFloat { smoothstep(linear) }
    /// 0 at either endpoint, 1 at the midpoint. Useful for transient effects that
    /// should only appear while a morph is in motion.
    var midPeak: CGFloat { smoothstep(1 - abs(2 * linear - 1)) }
    /// Linear opacity ramps (matches the app's `ramp`-driven fades).
    var fadeIn: Double { Double(linear) }
    var fadeOut: Double { Double(1 - linear) }
    /// Mirrored progress — 1 at the collapsed end (e.g. pill chrome that
    /// dissolves as a surface expands).
    var inverted: MorphProgress { MorphProgress(linear: 1 - linear) }

    /// Re-slice this progress over a sub-window of its own 0…1 range. Inside an
    /// `AnimatableMorph` closure this is how windowed fades stay per-frame:
    /// `p.window(0...0.35).fadeOut` (never re-read the captured outer driver —
    /// it holds the endpoint value, not the interpolated one).
    func window(_ w: ClosedRange<CGFloat>) -> MorphProgress {
        MorphProgress(linear, in: w)
    }

    /// Eased scalar interpolation a→b.
    func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * eased }
    /// Eased rect interpolation a→b.
    func rect(_ a: CGRect, _ b: CGRect) -> CGRect { lerpRect(a, b, eased) }
}

/// Free-function spelling that reads well at call sites:
/// `let p = progress(of: store.reveal, in: 1...2)`.
func progress(of driver: CGFloat, in window: ClosedRange<CGFloat> = 0...1) -> MorphProgress {
    MorphProgress(driver, in: window)
}
