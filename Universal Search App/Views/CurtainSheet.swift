//
//  CurtainSheet.swift
//  Universal Search App
//
//  The canvas as ONE morphing white surface. Driven by `store.reveal` over [0,1]
//  it frame-interpolates between full screen (reveal 0) and the open overview's
//  recap-card slot (reveal 1), crossfading its content from the result cards /
//  comparison (full) to the canvas-recap (collapsed) — so the canvas morphs INTO
//  the recap card, the way the overview card morphs into a collapsed list row.
//  Tapping the recap card (or dragging up) re-expands to the full canvas.
//

import SwiftUI

struct CurtainSheet: View {
    @Bindable var store: AppStore
    let thread: ThreadNode
    let metrics: Metrics

    /// The value the sheet frame-morphs against. Normally `store.reveal`; during a
    /// launch it is derived from the single `launch` driver (see AppStore) so the
    /// collapse/expand ride the one continuous timeline instead of a local spring.
    private var reveal: CGFloat { store.morphReveal }

    /// The open entry's trip-overview row card — the destination the whole canvas
    /// collapses into (there is no intermediate open-overview card any more).
    /// During a card-swap launch this retargets to the CENTERED card so the
    /// canvas collapses to / expands from the middle of the screen instead of the
    /// trip-list row.
    private var tripSlot: CGRect {
        if store.launchCentered { return metrics.centerCardRect }
        if let id = store.openEntryID, let slot = store.slotFrames[id], slot != .zero {
            return slot
        }
        return metrics.recapCardRect   // fallback until slots are measured
    }

    // MARK: Map detent sheet state

    /// Apple Maps-style detents for the map + results pages (map always behind).
    private enum Detent { case small, medium, large }
    /// Snapped detent (medium by default ⇒ ~50% map visible on load).
    @State private var detent: Detent = .medium
    /// Continuous Y of the sheet's top edge while dragging; nil ⇒ use `detent`.
    @State private var sheetTop: CGFloat?
    @State private var dragStart: CGFloat?
    /// `store.reveal` captured at drag start, so a drag that begins while the
    /// sheet is collapsing keeps scrubbing the reveal instead of the detent.
    @State private var dragStartReveal: CGFloat?

    /// True when this thread renders as a detent sheet over a map (flights,
    /// packages/broad searches, or a destination-city page) — not a comparison.
    private var isMapSheet: Bool {
        store.openComparison == nil && !thread.activeBlocks.isEmpty
            && ResultsMapView.hasMap(for: thread)
    }

    var body: some View {
        if isMapSheet {
            mapSheet
        } else {
            morphSheet
        }
    }

    // MARK: - Detent bottom sheet over the map

    /// Top edge Y for each detent. The large detent stops just below the floating
    /// global controls (nav header) so those buttons stay clear; a strip of map
    /// always peeks above.
    private func top(for d: Detent) -> CGFloat {
        switch d {
        case .large:  return metrics.safeTop + 64
        case .medium: return metrics.H * 0.5
        case .small:  return metrics.H * 0.82
        }
    }

    private func nearestDetent(to y: CGFloat) -> Detent {
        let options: [(Detent, CGFloat)] =
            [(.small, top(for: .small)), (.medium, top(for: .medium)), (.large, top(for: .large))]
        return options.min { abs($0.1 - y) < abs($1.1 - y) }!.0
    }

    /// Snappy interactive spring so releasing a drag settles fluidly (tracks
    /// velocity) instead of the slower morph spring.
    private var snapSpring: Animation { .interactiveSpring(response: 0.32, dampingFraction: 0.82) }

    private var mapSheet: some View {
        // reveal 0 end of the morph: the detent sheet, its top edge at `topY`, map
        // peeking behind.
        let topY = sheetTop ?? top(for: detent)
        let detentRect = CGRect(x: 0, y: topY, width: metrics.size.width, height: metrics.H - topY + 120)

        // Reveal-driven collapse — the whole sheet shrinks straight into the
        // trip-overview row card over the full 0→2 range (no intermediate
        // overview): 0 = detent sheet over the map · 2 = the trip-list row card.
        let morph = progress(of: reveal, in: 0...2)
        let s = morph.eased
        let rect = lerpRect(detentRect, tripSlot, s)
        let collapsed = reveal > 0.5
        let expandedCorner: CGFloat = thread.kind == .other ? 48 : 32
        let corner = lerp(expandedCorner, 24, s)
        // Fade the results content out as the sheet shrinks toward the row.
        let contentOpacity = Double(1 - ramp(reveal, 0.15, 1.0))
        // Pin the content to full width during the launch expand so the shrinking
        // outer frame clips rather than re-flows it (content is invisible until
        // near full anyway).
        let launchExpanding = store.launching && store.launchPhase == .expanding
        let contentWidth: CGFloat? = launchExpanding ? metrics.size.width : nil
        let blurRadius = (launchExpanding ? Theme.canvasLaunchSettleBlurRadius : Theme.canvasMorphBlurRadius) * morph.midPeak

        return ZStack(alignment: .top) {
            ScrollView {
                mapSheetContent
                    .frame(width: contentWidth, alignment: .top)
            }
            // Only the large (near-top) detent scrolls its content; the smaller
            // detents keep the whole sheet draggable, and once it starts
            // collapsing (reveal > 0) the content stops scrolling entirely.
            .scrollDisabled(detent != .large || reveal > 0.01)
            .scrollDismissesKeyboard(.interactively)
            // Overscrolling down at the large detent collapses the sheet to medium.
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                if detent == .large, reveal < 0.01, y < -60 {
                    detent = .medium
                    withAnimation(snapSpring) { sheetTop = top(for: .medium) }
                }
            }
            .allowsHitTesting(!collapsed)
            .opacity(contentOpacity)
        }
        .frame(width: rect.width, height: rect.height, alignment: .top)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .shadow(color: .black.opacity(0.18 * (1 - Double(s))), radius: 8, y: -6)
        .position(x: rect.midX, y: rect.midY)
        .blur(radius: blurRadius)
        // The whole sheet is the drag surface (no grabber): between detents while
        // at the results stage, then handing off into the reveal-collapse morph
        // once dragged past the smallest detent.
        .gesture(sheetDrag)
        // Once collapsed into the recap card, a tap re-expands to the results.
        .overlay {
            if collapsed {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
                    }
            }
        }
        .onAppear {
            if sheetTop == nil { sheetTop = top(for: .medium) }
            // During a launch the `launch` spring owns the entrance (this curtain
            // derives its reveal from it), so don't run our own zoom.
            guard !store.launching else { return }
            withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
        }
    }

    /// The sheet's scrollable content: bespoke flights and package layouts, or
    /// the server-driven blocks for destination-city pages. The whole sheet is
    /// draggable, so no grabber is needed.
    @ViewBuilder
    private var mapSheetContent: some View {
        if thread.kind == .flights {
            FlightsResultsView(thread: thread, metrics: metrics)
        } else if thread.kind == .other {
            PackageResultsView(thread: thread)
        } else {
            LazyVStack(alignment: .leading, spacing: 28) {
                ForEach(thread.activeBlocks) { block in
                    ResultBlockView(block: block)
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Drag applied to the whole map sheet (there's no grabber). While at the
    /// results stage it moves the sheet between detents (rubber-banding past the
    /// ends); dragging down past the smallest detent hands off into the reveal
    /// collapse so the sheet morphs down into the trip card. A drag that begins
    /// while already collapsing keeps scrubbing the reveal.
    private var sheetDrag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                if dragStart == nil {
                    dragStart = sheetTop ?? top(for: detent)
                    dragStartReveal = reveal
                }
                if (dragStartReveal ?? 0) <= 0.001 {
                    // Began at the results stage: detent drag, spilling into the
                    // reveal collapse once past the smallest detent.
                    let proposed = (dragStart ?? 0) + v.translation.height
                    let smallTop = top(for: .small)
                    if proposed <= smallTop {
                        if store.reveal != 0 { store.reveal = 0 }
                        sheetTop = rubberband(proposed, min: top(for: .large), max: smallTop)
                    } else {
                        sheetTop = smallTop
                        store.reveal = clamp((proposed - smallTop) / 280, 0, 2)
                    }
                } else {
                    // Began collapsed: scrub the reveal 1:1 with the finger.
                    store.reveal = clamp((dragStartReveal ?? 0) + v.translation.height / 280, 0, 2)
                }
            }
            .onEnded { v in
                let startReveal = dragStartReveal ?? 0
                dragStart = nil
                dragStartReveal = nil

                // Pure detent snap only when the whole drag stayed at the results
                // stage; otherwise snap along the reveal axis.
                if store.reveal <= 0.01 && startReveal <= 0.01 {
                    let current = sheetTop ?? top(for: detent)
                    let projected = current + v.predictedEndTranslation.height * 0.3
                    let target = nearestDetent(to: projected)
                    detent = target
                    withAnimation(snapSpring) { sheetTop = top(for: target) }
                    return
                }

                // Binary snap: results (0) or trip (2) — the overview stage is
                // skipped, so the sheet always resolves to one end.
                let fling = v.predictedEndTranslation.height - v.translation.height
                var target: CGFloat = store.reveal < 1 ? AppStore.stageResults : AppStore.stageTrip
                if abs(fling) > 250 {
                    target = fling > 0 ? AppStore.stageTrip : AppStore.stageResults
                }
                if target >= AppStore.stageTrip {
                    withAnimation(Theme.springMorph) { store.reveal = AppStore.stageTrip }
                        completion: { store.teardown() }
                } else {
                    // Settle back onto the smallest detent over the map.
                    detent = .small
                    sheetTop = top(for: .small)
                    withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
                }
            }
    }

    /// Soft resistance once the drag passes either end of the detent range.
    private func rubberband(_ value: CGFloat, min lo: CGFloat, max hi: CGFloat) -> CGFloat {
        if value < lo { return lo - (lo - value) * 0.3 }
        if value > hi { return hi + (value - hi) * 0.3 }
        return value
    }

    // MARK: - Everything else: the reveal-driven canvas morph

    private var morphSheet: some View {
        // The whole canvas shrinks straight into the trip-overview row card over
        // the full 0→2 range (no intermediate overview): 0 = full canvas · 2 =
        // the trip-list row card.
        let morph = progress(of: reveal, in: 0...2)
        let s = morph.eased
        let rect = lerpRect(metrics.fullCanvasRect, tripSlot, s)
        let collapsed = reveal > 0.5
        // Fade the results content out as the canvas shrinks toward the row.
        let contentOpacity = Double(1 - ramp(reveal, 0.1, 1.0))
        // During the launch expand the content is invisible until near full, so
        // pin it to the full-canvas width — the shrinking outer frame then only
        // clips it instead of re-flowing (wrapping) it every frame.
        let launchExpanding = store.launching && store.launchPhase == .expanding
        let contentWidth: CGFloat? = launchExpanding ? metrics.fullCanvasRect.width : nil
        let blurRadius = (launchExpanding ? Theme.canvasLaunchSettleBlurRadius : Theme.canvasMorphBlurRadius) * morph.midPeak

        return ZStack(alignment: .top) {
            // Whole-canvas drag/tap layer (replaces the grabber). Always present,
            // behind the content; the scroll ignores touches when collapsed, so
            // drags/taps fall through to here to expand (up) or go to the trip
            // (down). Always mounted so an in-progress drag isn't dropped as
            // `collapsed` flips at reveal 0.5.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if collapsed { withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults } }
                }
                .revealDrag(store)

            ScrollView {
                // Clears the floating header pills at the full canvas; a little top
                // breathing room once pushed down.
                let topClear = lerp(metrics.safeTop + 96, 12, s)
                Group {
                    if let comparison = store.openComparison {
                        ComparisonCanvas(store: store, comparison: comparison)
                            .padding(.horizontal, 28)
                            .padding(.top, topClear)
                            .padding(.bottom, 120)
                    } else if !thread.activeBlocks.isEmpty {
                        // Server-driven layout: the LLM's (or mock's) ordered blocks.
                        // Extra top clearance so the intro text clears the header pills.
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(thread.activeBlocks) { block in
                                ResultBlockView(block: block)
                            }
                        }
                        .padding(.top, lerp(metrics.safeTop + 124, 12, s))
                        .padding(.bottom, 120)
                    } else {
                        // Fallback: flat card list (threads with no blocks).
                        LazyVStack(spacing: 33.5) {
                            ForEach(Array(thread.activeCards.enumerated()), id: \.element.id) { i, card in
                                ResultCardView(card: card, index: i)
                            }
                        }
                        .padding(.horizontal, 51.31)
                        .padding(.top, topClear)
                        .padding(.bottom, 120)
                    }
                }
                .frame(width: contentWidth, alignment: .top)
            }
            .scrollDisabled(reveal > 0.01)
            .scrollDismissesKeyboard(.interactively)
            // Overscroll pull at the full canvas collapses toward the trip.
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                if reveal < 0.01, y < -70 {
                    withAnimation(Theme.springMorph) { store.reveal = AppStore.stageTrip }
                        completion: { store.teardown() }
                }
            }
            .allowsHitTesting(!collapsed)
            .opacity(contentOpacity)
        }
        .frame(width: rect.width, height: rect.height, alignment: .top)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: lerp(Theme.radiusCard, 24, s)))
        .shadow(color: .black.opacity(0.18 * (1 - Double(s))), radius: 8, y: -6)
        .position(x: rect.midX, y: rect.midY)
        .blur(radius: blurRadius)
        .onAppear {
            #if DEBUG
            if let v = ProcessInfo.processInfo.environment["FREEZE_REVEAL"], let r = Double(v) {
                store.reveal = CGFloat(r)
                return
            }
            #endif
            // During a launch the `launch` spring owns the entrance (this curtain
            // derives its reveal from it), so don't run our own zoom.
            guard !store.launching else { return }
            withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
        }
    }
}
