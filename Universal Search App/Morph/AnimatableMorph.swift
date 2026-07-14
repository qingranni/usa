//
//  AnimatableMorph.swift
//  Universal Search App
//
//  Owns the `Animatable` boilerplate for spring-driven morphs, plus the shared
//  two-state crossfade. See MORPHS.md.
//

import SwiftUI

/// Re-evaluates `content` at EVERY interpolated progress value during a spring,
/// not just at the endpoints. Needed whenever derived values are windowed (a
/// label that's gone by 0.35) or non-monotonic (an opacity that peaks mid-fly) —
/// without it those would pop between endpoints.
///
/// IMPORTANT: inside the closure, derive everything from the passed
/// `MorphProgress` (`p.eased`, `p.lerp`, `p.window(…)`). The closure captures the
/// outer driver at its ENDPOINT value; only `p` carries the per-frame value.
struct AnimatableMorph<Content: View>: View, Animatable {
    var progress: CGFloat
    @ViewBuilder let content: (MorphProgress) -> Content

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        content(MorphProgress(progress))
    }
}

/// Two overlaid states crossfaded by a driver, with hit-testing cutting over at
/// `cutover` so mid-morph taps never hit both (or the wrong) layer.
struct MorphCrossfade<Out: View, In: View>: View {
    var driver: CGFloat
    var outWindow: ClosedRange<CGFloat> = 0...1
    var inWindow: ClosedRange<CGFloat> = 0...1
    var cutover: CGFloat = 0.5
    var alignment: Alignment = .center
    @ViewBuilder let out: () -> Out
    @ViewBuilder let inContent: () -> In

    var body: some View {
        ZStack(alignment: alignment) {
            out()
                .opacity(MorphProgress(driver, in: outWindow).fadeOut)
                .allowsHitTesting(driver < cutover)
            inContent()
                .opacity(MorphProgress(driver, in: inWindow).fadeIn)
                .allowsHitTesting(driver >= cutover)
        }
    }
}
