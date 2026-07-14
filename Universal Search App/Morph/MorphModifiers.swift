//
//  MorphModifiers.swift
//  Universal Search App
//
//  View-level morph verbs built on MorphProgress. See MORPHS.md.
//

import SwiftUI

extension View {
    /// Opacity 0→1 as `driver` crosses `window` (linear, clamped).
    /// `.fadeIn(store.reveal, in: 0.9...1.0)` == `.opacity(Double(ramp(reveal, 0.9, 1.0)))`.
    func fadeIn(_ driver: CGFloat, in window: ClosedRange<CGFloat> = 0...1) -> some View {
        opacity(MorphProgress(driver, in: window).fadeIn)
    }

    /// Opacity 1→0 as `driver` crosses `window` (linear, clamped).
    /// `.fadeOut(store.reveal, in: 1.5...2.0)` == `.opacity(Double(1 - ramp(reveal, 1.5, 2.0)))`.
    func fadeOut(_ driver: CGFloat, in window: ClosedRange<CGFloat> = 0...1) -> some View {
        opacity(MorphProgress(driver, in: window).fadeOut)
    }

    /// Size + position along the eased interpolation of two rects (in the
    /// "root" coordinate space). Ends with `.position()` — apply chrome
    /// (background / clipShape / shadow / overlays) BEFORE this modifier, and
    /// compose `.offset()` after it for extra travel. When chrome must measure
    /// the morphing rect itself (masks, scaledToFill), compute `p.rect(a, b)`
    /// and lay out manually instead.
    func morphFrame(from: CGRect, to: CGRect, progress p: MorphProgress) -> some View {
        let r = p.rect(from, to)
        return frame(width: r.width, height: r.height)
            .position(x: r.midX, y: r.midY)
            .morphBlur(p)
    }

    /// Subtle transient blur for morphing layers. Endpoints stay sharp; the blur
    /// peaks at the midpoint where velocity and visual mismatch are highest.
    func morphBlur(_ p: MorphProgress, maxRadius: CGFloat = Theme.morphBlurRadius) -> some View {
        blur(radius: maxRadius * p.midPeak)
    }

    /// One-shot appear: fade + 16pt slide-up on `Theme.springSoft`, staggered
    /// `delay` seconds per index.
    func staggeredAppear(index: Int, delay: TimeInterval = 0.06) -> some View {
        modifier(StaggeredAppear(index: index, delay: delay))
    }

    /// Publish this view's frame in the "root" coordinate space, so a morphing
    /// layer can land on it exactly. Geometry stays valid even while the view is
    /// held at opacity 0. Capture endpoint frames into the store only while the
    /// source is at rest (see MORPHS.md).
    func captureFrame(enabled: Bool = true, _ onChange: @escaping (CGRect) -> Void) -> some View {
        modifier(CaptureFrame(enabled: enabled, onChange: onChange))
    }
}

private struct StaggeredAppear: ViewModifier {
    let index: Int
    let delay: TimeInterval
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            // `.task` (not a detached onAppear Task) so a row that scrolls away
            // cancels its pending stagger.
            .task {
                do { try await Task.sleep(for: .seconds(delay * Double(index))) }
                catch { return }
                withAnimation(Theme.springSoft) { appeared = true }
            }
    }
}

private struct CaptureFrame: ViewModifier {
    let enabled: Bool
    let onChange: (CGRect) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named("root"))
            } action: { onChange($0) }
        } else {
            content
        }
    }
}
