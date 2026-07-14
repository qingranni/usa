//
//  MorphScrub.swift
//  Universal Search App
//
//  The shared scrub gesture: drag a continuous driver 1:1 with the finger, snap
//  to integer stages on release (a decisive fling jumps one stage from where the
//  drag began). See MORPHS.md.
//

import SwiftUI

/// Snap decision shared by every scrub gesture: the nearest integer stage, or
/// one stage from `startStage` in the fling direction when the release velocity
/// is decisive. `fling` is signed along the DRIVER axis (positive = toward
/// higher driver values); `threshold` is in points.
func flingTarget(current: CGFloat, startStage: CGFloat, fling: CGFloat,
                 in range: ClosedRange<CGFloat>, threshold: CGFloat = 250) -> CGFloat {
    var target = current.rounded()
    if abs(fling) > threshold {
        target = clamp(startStage + (fling > 0 ? 1 : -1),
                       range.lowerBound, range.upperBound)
    }
    return target
}

extension View {
    /// Scrub `driver` 1:1 with the finger over `range`; snap to integer stages
    /// on release.
    ///
    /// `distance` is points of vertical drag per driver unit — NEGATIVE when
    /// dragging UP should increase the driver (composer: -260; reveal: 280).
    ///
    /// `onSettle(target, start, drag)` replaces the default settle
    /// (`withAnimation(Theme.springMorph) { driver = target }`) so callers can
    /// attach completions or special cases (trip teardown, drag-down dismiss);
    /// `start` is the raw driver value captured when the drag began.
    func morphScrub(_ driver: Binding<CGFloat>, over range: ClosedRange<CGFloat>,
                    distance: CGFloat = 280,
                    onSettle: ((_ target: CGFloat, _ start: CGFloat,
                                _ drag: DragGesture.Value) -> Void)? = nil) -> some View {
        modifier(MorphScrub(driver: driver, range: range,
                            distance: distance, onSettle: onSettle))
    }
}

private struct MorphScrub: ViewModifier {
    @Binding var driver: CGFloat
    let range: ClosedRange<CGFloat>
    let distance: CGFloat
    let onSettle: ((CGFloat, CGFloat, DragGesture.Value) -> Void)?

    @State private var start: CGFloat?

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(coordinateSpace: .global)
                .onChanged { value in
                    if start == nil { start = driver }
                    driver = clamp((start ?? 0) + value.translation.height / distance,
                                   range.lowerBound, range.upperBound)
                }
                .onEnded { value in
                    let startValue = start ?? driver
                    start = nil
                    // Sign-normalize the fling onto the driver axis via `distance`.
                    let flingPts = value.predictedEndTranslation.height - value.translation.height
                    let fling = distance > 0 ? flingPts : -flingPts
                    let target = flingTarget(current: driver,
                                             startStage: startValue.rounded(),
                                             fling: fling, in: range)
                    if let onSettle {
                        onSettle(target, startValue, value)
                    } else {
                        withAnimation(Theme.springMorph) { driver = target }
                    }
                }
        )
    }
}
