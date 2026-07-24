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

/// The map-sheet scroll state we react to: the vertical offset (for the
/// title fade + overscroll collapse) and whether the content has reached its
/// end (for the Mexico discovery prompt).
private struct MapSheetScroll: Equatable {
    var offsetY: CGFloat
    var reachedEnd: Bool
}

struct CurtainSheet: View {
    @Bindable var store: AppStore
    let thread: ThreadNode
    let metrics: Metrics
    /// Shared namespace for the inline-answer → conversation answer text morph.
    var answerMorph: Namespace.ID

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
    /// Scroll anchor pinned to the top of the map results content, so a freshly
    /// opened card can be scrolled back to the top.
    private static let scrollTopAnchor = "map-results-top"
    /// Snapped detent (medium by default ⇒ ~50% map visible on load).
    @State private var detent: Detent = .medium
    /// Continuous Y of the sheet's top edge while dragging; nil ⇒ use `detent`.
    @State private var sheetTop: CGFloat?
    @State private var dragStart: CGFloat?
    /// `store.reveal` captured at drag start, so a drag that begins while the
    /// sheet is collapsing keeps scrubbing the reveal instead of the detent.
    @State private var dragStartReveal: CGFloat?

    /// The source-resolved presentation decision. Content composition is shared
    /// between this detent sheet and the no-map morph sheet.
    private var isMapSheet: Bool {
        thread.presentation.showsMap && thread.presentation.overlaySheet
    }

    private var isMexicoOrientation: Bool {
        thread.presentation.canvasLayout == .mexicoOrientation
    }

    /// The narrative Cancun packages map reframes on the same collapsed-detent
    /// flag as the Mexico orientation (zoom in + centre the pins).
    private var isPackageShelves: Bool {
        thread.composition == .packageShelves
    }

    var body: some View {
        ZStack {
            if isMexicoOrientation, store.selectedMexicoDestinationID != nil {
                mexicoDestinationSelection
                    // Cross-dissolve into the rising package sheet at beat 2
                    // instead of popping out in a single frame.
                    .transition(.opacity)
            } else if store.canvasConversation != nil {
                // A conversation (an open activity, OR a quick-answer draft being
                // composed over) can live on a results/map thread. Always render
                // the chat canvas for it — the thread's map presentation must not
                // shadow it.
                morphSheet
            } else if isMapSheet {
                ZStack {
                    mapBackdropGradient
                    mapSheet
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                morphSheet
            }
        }
        .frame(width: metrics.size.width, height: metrics.H)
        // Beat 2: when the refine flips the composition into packages, animate the
        // carousel → medium-detent sheet swap on the same curve as the map fly and
        // the dock-pill morph so the three motions read as one.
        .animation(Theme.springMorph, value: thread.composition)
        // This lives on the always-mounted body (NOT the mapSheet, which only
        // mounts AFTER the flip, so an onChange there would never observe the
        // change). When the composition enters packages during beat 1 (the fly),
        // hold the sheet OFF-SCREEN below so the map + pins settle alone; beat 2
        // slides it up. A direct/cold entry (no fly) just sits at medium.
        .onChange(of: thread.composition) { _, composition in
            guard composition == .packageShelves else { return }
            dragStart = nil
            dragStartReveal = nil
            detent = .medium
            if store.mexicoPackageFly {
                sheetTop = metrics.H
                store.mapCoverage = 0
            } else {
                withAnimation(Theme.springMorph) {
                    sheetTop = top(for: .medium)
                    store.mapCoverage = 0
                    if store.reveal != AppStore.stageResults {
                        store.reveal = AppStore.stageResults
                    }
                }
            }
        }
        // Beat 2: the fly clears once beat 1 has settled — slide the sheet up from
        // off-screen to the medium detent, a touch slower than the map pan / pill
        // morph so it reads as following them in.
        .onChange(of: store.mexicoPackageFly) { _, flying in
            guard !flying, isPackageShelves else { return }
            dragStart = nil
            dragStartReveal = nil
            detent = .medium
            withAnimation(sheetSlideIn) {
                sheetTop = top(for: .medium)
                store.mapCoverage = 0
                if store.reveal != AppStore.stageResults {
                    store.reveal = AppStore.stageResults
                }
            }
        }
    }

    // MARK: - Selected Mexico destination

    private var mexicoDestinationSelection: some View {
        MexicoVacationCardCarousel(store: store, cards: thread.activeCards)
            .padding(.bottom, 113)
            .frame(width: metrics.size.width, height: metrics.H, alignment: .bottom)
    }

    // MARK: - Detent bottom sheet over the map

    /// Top edge Y for each detent. The large detent stops just below the floating
    /// global controls (nav header) so those buttons stay clear; a strip of map
    /// always peeks above.
    private func top(for d: Detent) -> CGFloat {
        switch d {
        case .large:  return metrics.safeTop + 64
        case .medium: return metrics.H * (isMexicoOrientation ? 0.432 : 0.355)
        case .small:
            guard isMexicoOrientation else { return metrics.H * 0.82 }
            // Card top placed so the title + filter row clear the follow-up "Ask
            // anything" pill by ~16pt. The pill's top sits ~90pt above the screen
            // bottom (50pt tall + 40pt bottom padding); the filter row's bottom
            // lands ~125pt below the card's top edge (65pt top pad + ~60pt row).
            let pillTopFromBottom: CGFloat = 90
            let filterBottomFromCardTop: CGFloat = 125
            return metrics.H - pillTopFromBottom - 16 - filterBottomFromCardTop
        }
    }

    private func nearestDetent(to y: CGFloat) -> Detent {
        let options: [(Detent, CGFloat)] =
            [(.small, top(for: .small)), (.medium, top(for: .medium)), (.large, top(for: .large))]
        return options.min { abs($0.1 - y) < abs($1.1 - y) }!.0
    }

    /// Map-coverage for a given sheet-top Y: 0 at the medium detent (and below,
    /// where the map reads normally), ramping to 1 at the large detent where the
    /// sheet all but hides it. Published to `store.mapCoverage` so RootView can
    /// blur + white-wash the peeking map into Figma's frosted backdrop.
    private func coverage(forTop y: CGFloat) -> CGFloat {
        let mediumTop = top(for: .medium)
        let largeTop = top(for: .large)
        guard mediumTop > largeTop else { return 0 }
        return clamp((mediumTop - y) / (mediumTop - largeTop), 0, 1)
    }

    /// Snappy interactive spring so releasing a drag settles fluidly (tracks
    /// velocity) instead of the slower morph spring.
    private var snapSpring: Animation { .interactiveSpring(response: 0.32, dampingFraction: 0.82) }

    /// Beat-2 sheet slide-in — cubic-bezier(0.75, 0, 0, 1) over 750ms.
    private var sheetSlideIn: Animation { .timingCurve(0.75, 0, 0, 1, duration: 0.75) }

    /// A soft F5F3F3 wash over the map, behind the sheet, at the medium/small
    /// detents — 100% opaque at the screen bottom fading to 0% 56pt above the
    /// sheet's top edge, so the map reads as settling into the sheet. Tracks the
    /// sheet's top 1:1 while dragging and fades out at the large detent (where the
    /// sheet is full-bleed) and as the sheet collapses toward the trip card.
    private var mapBackdropGradient: some View {
        let topY = sheetTop ?? top(for: detent)
        let largeTop = top(for: .large)
        let mediumTop = top(for: .medium)
        let presence = clamp((topY - largeTop) / max(mediumTop - largeTop, 1), 0, 1)
        let collapseFade = Double(1 - ramp(reveal, 0.15, 1.0))
        let wash = Color(red: 245 / 255, green: 243 / 255, blue: 243 / 255)
        return LinearGradient(
            colors: [wash.opacity(0), wash],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: max(metrics.H - topY + 56, 0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .opacity(Double(presence) * collapseFade)
        .allowsHitTesting(false)
    }

    private var mapSheet: some View {
        // reveal 0 end of the morph: the detent sheet, its top edge at `topY`, map
        // peeking behind. During beat 1 of the card→packages transition the sheet
        // is held off-screen below (so the map + pins settle alone) regardless of
        // the carried-over sheetTop, so it can't flash at a stale position on mount.
        let topY = store.mexicoPackageFly ? metrics.H : (sheetTop ?? top(for: detent))
        // The floating-card treatment (6pt side inset + a lifted bottom edge) is
        // applied ONLY at the small detent; the medium/large sheets stay full-
        // bleed and run to the screen bottom. `smallness` ramps 0 (medium) → 1
        // (small) off `topY`, so the card lifts in 1:1 as it's dragged down.
        let smallTop = top(for: .small)
        let mediumTop = top(for: .medium)
        let smallness = clamp((topY - mediumTop) / max(smallTop - mediumTop, 1), 0, 1)
        let sideInset = 6 * smallness
        // Bottom edge: extends 120pt past the screen bottom at medium/large; lifts
        // to a 6pt gap above the screen bottom at small (matching the side inset)
        // so the card floats over the map with even margins.
        let bottomEdge = (metrics.H + 120) - (120 + 6) * smallness
        let detentRect = CGRect(x: sideInset, y: topY,
                                width: metrics.size.width - sideInset * 2,
                                height: bottomEdge - topY)

        // Reveal-driven collapse — the whole sheet shrinks straight into the
        // trip-overview row card over the full 0→2 range (no intermediate
        // overview): 0 = detent sheet over the map · 2 = the trip-list row card.
        let morph = progress(of: reveal, in: 0...2)
        let s = morph.eased
        let rect = lerpRect(detentRect, tripSlot, s)
        let collapsed = reveal > 0.5
        let expandedCorner: CGFloat = 48
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
            ScrollViewReader { proxy in
            ScrollView {
                mapSheetContent
                    .frame(width: contentWidth, alignment: .top)
                    .id(Self.scrollTopAnchor)
            }
            // Only the large (near-top) detent scrolls its content; the smaller
            // detents keep the whole sheet draggable, and once it starts
            // collapsing (reveal > 0) the content stops scrolling entirely. Kept
            // as one ScrollView across every detent so growing to the full sheet
            // never swaps the container (which flickered / re-laid-out the content).
            .scrollDisabled(detent != .large || reveal > 0.01)
            .scrollDismissesKeyboard(.interactively)
            // A newly opened card resets to its default framing: medium detent,
            // scrolled to the top — never inheriting the previous card's detent or
            // scroll offset (e.g. Cancun packages → beachfront options).
            .onChange(of: store.resultsResetToken) { _, _ in
                proxy.scrollTo(Self.scrollTopAnchor, anchor: .top)
                guard detent != .medium || sheetTop != top(for: .medium) else { return }
                dragStart = nil
                dragStartReveal = nil
                detent = .medium
                withAnimation(snapSpring) {
                    sheetTop = top(for: .medium)
                    store.mapCoverage = 0
                }
            }
            // Overscrolling down at the large detent collapses the sheet to medium.
            .onScrollGeometryChange(for: MapSheetScroll.self) { geo in
                // Max scroll offset; guarded so a non-scrollable sheet never reads
                // as "already at the end".
                let maxY = geo.contentSize.height + geo.contentInsets.top
                    + geo.contentInsets.bottom - geo.containerSize.height
                let reachedEnd = maxY > 40 && geo.contentOffset.y >= maxY - 80
                return MapSheetScroll(offsetY: geo.contentOffset.y, reachedEnd: reachedEnd)
            } action: { _, s in
                updateContentScrolled(s.offsetY)
                // The Mexico vacation overview shows its discovery prompt only
                // while the fully-open sheet is scrolled to the end: the dock pill
                // morphs into the card at the last carousel and back to "Ask
                // anything" on scroll up. Only meaningful at the large detent (the
                // only one that scrolls); collapsing hides it via onChange(detent).
                // (Cancun is the inverse — see updateContentScrolled.)
                if thread.composition == .blocks, detent == .large,
                   store.destinationDiscoveryRevealed != s.reachedEnd {
                    withAnimation(Theme.springMorph) {
                        store.destinationDiscoveryRevealed = s.reachedEnd
                    }
                }
                if detent == .large, reveal < 0.01, s.offsetY < -60 {
                    detent = .medium
                    withAnimation(snapSpring) {
                        sheetTop = top(for: .medium)
                        store.mapCoverage = 0
                    }
                }
            }
            .allowsHitTesting(!collapsed)
            .opacity(contentOpacity)
            }

            topFade
                .opacity(contentOpacity)

            sheetDragHandle
                .opacity(contentOpacity)

            if isMexicoOrientation {
                mexicoSheetHeader
                    .opacity(contentOpacity)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .top)
        // Ease the surface white → trip-card beige across the morph so it lands
        // already matching the row card instead of snapping color on handoff.
        .background(Color.mix(.white, Theme.cardItem, s))
        .clipShape(RoundedRectangle(cornerRadius: corner))
        .shadow(color: .black.opacity(0.09 * (1 - Double(s))), radius: 8, y: -6)
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
        .onChange(of: detent) { _, d in
            store.mexicoMapCollapsed = (isMexicoOrientation || isPackageShelves) && d == .small
            // The Mexico discovery prompt only belongs at the fully-open sheet,
            // scrolled to the end. Collapsing away from large hides it again (the
            // collapse is a detent drag, so no scroll event fires to clear it).
            if thread.composition == .blocks, d != .large, store.destinationDiscoveryRevealed {
                withAnimation(Theme.springMorph) { store.destinationDiscoveryRevealed = false }
            }
        }
        // A tap on the exposed map (RootView) asks the sheet to return to the
        // split. Snap to the medium detent and clear any in-progress collapse.
        .onChange(of: store.mapSplitRequest) { _, _ in
            dragStart = nil
            dragStartReveal = nil
            detent = .medium
            withAnimation(snapSpring) {
                sheetTop = top(for: .medium)
                store.mapCoverage = 0
                if store.reveal != AppStore.stageResults {
                    store.reveal = AppStore.stageResults
                }
            }
        }
        .onAppear {
            if sheetTop == nil {
                let initialDetent: Detent = .medium
                detent = initialDetent
                sheetTop = top(for: initialDetent)
                store.mapCoverage = coverage(forTop: top(for: initialDetent))
            }
            store.mexicoMapCollapsed = (isMexicoOrientation || isPackageShelves) && detent == .small
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
        ResultsCanvasContent(
            store: store,
            thread: thread,
            topPadding: isMexicoOrientation ? 65 : 28,
            showsResultContent: !isMexicoOrientation || detent != .small
        )
    }

    /// Drag affordance shared by every results sheet that renders over the map —
    /// a 32×4 pill pinned near the sheet's top edge. Sits above `topFade` so it
    /// stays legible as content scrolls under it.
    private var sheetGrabber: some View {
        Capsule()
            .fill(Theme.figmaInk.opacity(0.15))
            .frame(width: 32, height: 4)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }

    /// The grabber wrapped in a hit-testable strip pinned at the sheet's top
    /// edge. The body's `ScrollView` owns vertical drags once the large detent
    /// is scrolling, so this handle gives the user a reliable place to grab and
    /// pull the sheet back down without first scrolling to the top — a
    /// tap-and-pull on the dragger drives the same detent/collapse drag as the
    /// rest of the sheet.
    private var sheetDragHandle: some View {
        VStack(spacing: 0) {
            sheetGrabber
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: 28)
        .contentShape(Rectangle())
        .gesture(sheetDrag)
    }

    // The floating trip title. Hidden once the content scrolls up under it so the
    // title never collides with the scrolling copy — only the grabber remains.
    private var mexicoSheetHeader: some View {
        Text(thread.title)
            .font(.centra(size: 14, weight: .medium))
            .foregroundStyle(Theme.ink)
            .lineLimit(1)
            .opacity(store.canvasContentScrolled ? 0 : 1)
            .padding(.top, 24)
            .frame(maxWidth: .infinity)
    }

    /// A short white-to-clear gradient pinned at the sheet's top edge. As the
    /// content scrolls up it fades out beneath the floating title / grabber
    /// instead of colliding with it, keeping the drag affordance legible.
    private var topFade: some View {
        LinearGradient(
            colors: [.white, .white.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 32)
        .frame(maxWidth: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    /// Records whether the scroll content has been pushed up past a small
    /// threshold, so the floating titles can fade out (see `store.canvasContentScrolled`).
    private func updateContentScrolled(_ offsetY: CGFloat) {
        let scrolled = offsetY > 8
        if store.canvasContentScrolled != scrolled {
            withAnimation(.easeOut(duration: 0.18)) {
                store.canvasContentScrolled = scrolled
            }
        }
        // Once the results have been scrolled a bit, retire the one-time
        // destination-discovery prompt so the dock pill morphs back to "Ask
        // anything" (see AppStore.showsDestinationDiscovery).
        if offsetY > 120, store.showsDestinationDiscovery {
            withAnimation(Theme.springMorph) { store.destinationDiscoveryRetired = true }
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
                        let newTop = rubberband(proposed, min: top(for: .large), max: smallTop)
                        sheetTop = newTop
                        // Track the finger 1:1 (no animation) so the map wash
                        // follows the sheet as it rises toward the large detent.
                        store.mapCoverage = coverage(forTop: newTop)
                    } else {
                        sheetTop = smallTop
                        store.mapCoverage = 0
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
                    withAnimation(snapSpring) {
                        sheetTop = top(for: target)
                        store.mapCoverage = coverage(forTop: top(for: target))
                    }
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
                    withAnimation(Theme.springMorph) {
                        store.reveal = AppStore.stageResults
                        store.mapCoverage = 0
                    }
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

            ScrollViewReader { proxy in
                ScrollView {
                    // Clears the floating header pills at the full canvas; a little top
                    // breathing room once pushed down.
                    let topClear = lerp(metrics.safeTop + 96, 12, s)
                    if let conversation = store.canvasConversation {
                        ConversationCanvasView(
                            conversation: conversation,
                            topPadding: topClear,
                            streamingTurn: store.openActivityID == store.streamingActivityID
                                ? store.streamingTurn : nil,
                            // A screenful below the last turn so a fresh reply can
                            // ride to the top with room to spare.
                            reservedBottom: metrics.size.height * 0.9,
                            // Only wire the answer morph while composing over the
                            // draft — that's the one hand-off from the inline card.
                            morphNS: store.inlineAnswerDraft != nil ? answerMorph : nil
                        )
                        .frame(width: contentWidth, alignment: .top)
                    } else {
                        ResultsCanvasContent(
                            store: store,
                            thread: thread,
                            topPadding: topClear
                        )
                        .frame(width: contentWidth, alignment: .top)
                    }
                }
                .scrollDisabled(reveal > 0.01)
                .scrollDismissesKeyboard(.interactively)
                // Overscroll pull at the full canvas collapses toward the trip.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                    updateContentScrolled(y)
                    if reveal < 0.01, y < -70 {
                        withAnimation(Theme.springMorph) { store.reveal = AppStore.stageTrip }
                            completion: { store.teardown() }
                    }
                }
                // A fresh reply pins its question just BELOW the floating header
                // (not jammed under it) so the question + streaming answer are what's
                // in focus, with the answer landing in the clear reading area.
                .onChange(of: store.conversationScrollToken) { _, _ in
                    guard let target = store.conversationScrollTarget else { return }
                    let headerFraction = min(0.32, (metrics.safeTop + 150) / metrics.H)
                    withAnimation(Theme.springMorph) {
                        proxy.scrollTo(target, anchor: UnitPoint(x: 0.5, y: headerFraction))
                    }
                }
            }
            .allowsHitTesting(!collapsed)
            .opacity(contentOpacity)

            topFade
                .opacity(contentOpacity)
        }
        .frame(width: rect.width, height: rect.height, alignment: .top)
        // Ease the surface white → trip-card beige across the morph so it lands
        // already matching the row card instead of snapping color on handoff.
        .background(Color.mix(.white, Theme.cardItem, s))
        .clipShape(RoundedRectangle(cornerRadius: lerp(Theme.radiusCard, 24, s)))
        .shadow(color: .black.opacity(0.09 * (1 - Double(s))), radius: 8, y: -6)
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

private struct MexicoVacationCardCarousel: View {
    @Bindable var store: AppStore
    let cards: [Card]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        StaggeredMexicoVacationCard(store: store, card: card, index: index)
                            .frame(width: 330)
                            .id(card.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 37, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $store.selectedMexicoDestinationID)
            .frame(height: 140)
            // `.scrollPosition` doesn't honor its initial value on first layout,
            // so the carousel would otherwise stay parked on the first card
            // (Cancun) instead of the tapped pin. Nudge it to the selected card
            // once the content is laid out; the binding still handles swipes.
            .onAppear {
                let target = store.selectedMexicoDestinationID
                DispatchQueue.main.async {
                    withAnimation(Theme.springSoft) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct StaggeredMexicoVacationCard: View {
    @Bindable var store: AppStore
    let card: Card
    let index: Int

    @State private var visible = false

    var body: some View {
        MexicoVacationCard(store: store, card: card)
            .opacity(visible ? 1 : 0)
            .offset(x: visible ? 0 : 84)
            .onAppear {
                withAnimation(
                    .spring(response: 0.46, dampingFraction: 0.84)
                        .delay(Double(index) * 0.08)
                ) {
                    visible = true
                }
            }
    }
}

private struct MexicoVacationCard: View {
    @Bindable var store: AppStore
    let card: Card

    @State private var favorited = false

    private var subtitle: String {
        guard let highlights = card.highlights, !highlights.isEmpty else {
            return "Flights + stay"
        }
        return highlights
    }

    var body: some View {
        HStack(spacing: 8) {
            image

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.displayTitle)
                        .font(.centra(size: 16, weight: .medium))
                        .foregroundStyle(Theme.figmaInk)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.centra(size: 14))
                        .foregroundStyle(Theme.figmaInk.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if let price = card.displayPrice {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Copy["results.pricePrefix"])
                            .font(.centra(size: 15, weight: .medium))
                            .foregroundStyle(Theme.figmaInk.opacity(0.6))
                        Text(price)
                            .font(.centra(size: 16, weight: .medium))
                            .foregroundStyle(Theme.figmaInk)
                    }
                }

                Text(Copy["results.priceAvgCaption"])
                    .font(.centra(size: 12))
                    .foregroundStyle(Theme.figmaInk.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(height: 140)
        .fauxGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture { openPackages() }
    }

    /// Tapping the card opens this destination's packages — behaves exactly like
    /// typing its name into the composer (the composer `.refine` path), so the
    /// narrative golden path refines the open orientation thread into the
    /// `.packageShelves` composition (`PackageResultsView`).
    private func openPackages() {
        Task { await store.openPackages(card) }
    }

    private var image: some View {
        RemoteOrLocalImage(urlString: card.imageURL)
            .frame(width: 124, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(alignment: .topLeading) {
                Button {
                    withAnimation(Theme.springSoft) { favorited.toggle() }
                } label: {
                    EGDSIcon(favorited ? "heart.fill" : "heart", size: 18)
                        .foregroundStyle(favorited ? Color.red : Color.white)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(favorited ? "Remove from favorites" : "Add to favorites")
            }
    }
}

private struct ResultsCanvasContent: View {
    @Bindable var store: AppStore
    let thread: ThreadNode
    let topPadding: CGFloat
    var showsResultContent: Bool = true

    var body: some View {
        content
    }

    private var content: some View {
        LazyVStack(alignment: .leading, spacing: 24) {
            if thread.presentation.canvasLayout == .mexicoOrientation {
                EmptyView()
            } else {
                QueryChipsView(query: thread.title)
                    .padding(.horizontal, 28)
            }

            if thread.presentation.showsFilters {
                QueryChipsAndFilters(
                    store: store,
                    filters: thread.presentation.filters,
                    refinements: thread.presentation.refinements,
                    canvasLayout: thread.presentation.canvasLayout
                )
            }

            if showsResultContent {
                ResultCompositionView(store: store, thread: thread)
            }
        }
        .padding(.top, topPadding)
        // 120 is eaten by the sheet frame extending 120pt below the screen bottom.
        // On top of that, clear the floating composer pill, whose top edge sits
        // ~124pt up from the screen bottom (≈34 safe-area + 40 offset + 50 height),
        // plus a 24pt gap.
        .padding(.bottom, 120 + 124 + 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ResultCompositionView: View {
    @Bindable var store: AppStore
    let thread: ThreadNode

    private var blocks: [ResultBlock] {
        guard let first = thread.activeBlocks.first,
              first.style == .heading,
              first.semanticType == nil,
              isEquivalentReplay(first.text, thread.title)
        else {
            return thread.activeBlocks
        }
        return Array(thread.activeBlocks.dropFirst())
    }

    @ViewBuilder
    var body: some View {
        if let comparison = store.openComparison {
            ComparisonCanvas(store: store, comparison: comparison)
                .padding(.horizontal, 28)
        } else {
            switch thread.composition {
            case .flightList:
                specializedLayout {
                    FlightsResultsView(thread: thread)
                }
            case .packageShelves:
                specializedLayout {
                    PackageResultsView(store: store, thread: thread)
                }
            case .blocks:
                if thread.presentation.canvasLayout == .mexicoOrientation {
                    mexicoOrientationLayout
                } else if !blocks.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        ForEach(blocks) { block in
                            ResultBlockView(
                                store: store,
                                block: block,
                                canvasLayout: thread.presentation.canvasLayout
                            )
                        }
                    }
                } else {
                    fallbackCards
                }
            }
        }
    }

    private var mexicoOrientationLayout: some View {
        let introBlocks = Array(blocks.prefix(2))
        let contentBlocks = Array(blocks.dropFirst(2))

        return LazyVStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(introBlocks) { block in
                    ResultBlockView(
                        store: store,
                        block: block,
                        canvasLayout: .mexicoOrientation
                    )
                }
            }

            ForEach(contentBlocks.indices, id: \.self) { index in
                let block = contentBlocks[index]
                if block.style == .heading,
                   contentBlocks.indices.contains(index + 1),
                   contentBlocks[index + 1].style == .text {
                    VStack(alignment: .leading, spacing: 4) {
                        ResultBlockView(
                            store: store,
                            block: block,
                            canvasLayout: .mexicoOrientation
                        )
                        ResultBlockView(
                            store: store,
                            block: contentBlocks[index + 1],
                            canvasLayout: .mexicoOrientation
                        )
                    }
                } else if block.style == .text,
                          index > 0,
                          contentBlocks[index - 1].style == .heading {
                    EmptyView()
                } else {
                    ResultBlockView(
                        store: store,
                        block: block,
                        canvasLayout: .mexicoOrientation
                    )
                }
            }
        }
    }

    private var semanticBlocks: [ResultBlock] {
        thread.specializedSemanticBlocks
    }

    private func specializedLayout<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(semanticBlocks) { block in
                ResultBlockView(
                    store: store,
                    block: block,
                    canvasLayout: thread.presentation.canvasLayout
                )
            }
            content()
        }
    }

    private var fallbackCards: some View {
        LazyVStack(spacing: 33.5) {
            ForEach(Array(thread.activeCards.enumerated()), id: \.element.id) { index, card in
                ResultCardView(card: card, index: index)
            }
        }
        .padding(.horizontal, 51.31)
    }

    private func isEquivalentReplay(_ heading: String, _ query: String) -> Bool {
        normalizedTokens(heading) == normalizedTokens(query)
    }

    private func normalizedTokens(_ value: String) -> Set<String> {
        let ignored: Set<String> = ["a", "an", "for", "in", "of", "the", "to"]
        let words = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        return Set(words.filter { !ignored.contains($0) })
    }
}
