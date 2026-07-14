//
//  RootView.swift
//  Universal Search App
//
//  Hosts the store and the curtain-reveal layer stack over a persistent trip
//  overview parent. A single `store.reveal` (0 Results · 1 Overview · 2 Trip)
//  scrubs the canvas, the open-overview container, and the cascading others.
//

import SwiftUI

/// Screen geometry shared across the curtain layers.
struct Metrics {
    var size: CGSize
    var safeTop: CGFloat
    var safeBottom: CGFloat = 0
    var headerH: CGFloat = 84
    var H: CGFloat { size.height }
}

struct RootView: View {
    @State private var store = AppStore()

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let fullH = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let m = Metrics(size: CGSize(width: geo.size.width, height: fullH),
                            safeTop: safeTop,
                            safeBottom: geo.safeAreaInsets.bottom)

            // The homepage shows when there's no trip yet, or when the user has
            // backed all the way out of the canvas to home.
            let showHome = store.isEmpty || store.showHome

            // Siri-style composer presentation: while composing, the canvas
            // recedes behind the docked sheet. Once submitted from a canvas, the
            // live tree fades to the loading surface and static centered cards
            // carry the load sequence until the new curtain expands.
            let launching = store.launching
            let phase = store.launchPhase

            // The canvas now carries ONLY the composer shrink. The launch path no
            // longer shrinks the live canvas into a card; it fades the live tree
            // away, then uses static row cards before handing off to the new
            // curtain's centered-card → full-canvas expand.
            let cardScale: CGFloat = 0.92
            let cardMargin = m.size.width * (1 - cardScale) / 2

            let launchComposerExit = launching && store.launchFromCurrent && phase == .collapsing
            let composerShrink = store.composerActive || launchComposerExit
            let canvasScale = composerShrink ? cardScale : 1
            let canvasOffset = composerShrink ? cardMargin : 0
            let canvasCorner: CGFloat = composerShrink ? 34 / cardScale : 0
            let canvasShadow: Double = composerShrink ? 0.28 : 0
            // While the composer is up, the backdrop canvas recedes: a soft blur
            // plus a 75% black overlay so focus lands on the sheet.
            let canvasBlur: CGFloat = composerShrink ? 15 : 0
            let canvasDim: Double = composerShrink ? 0.75 : 0
            let blackingOut = launching && store.launchFromCurrent && phase == .collapsing
            let blackout = progress(of: store.launch, in: 0...AppStore.launchBlackoutEnd)
            let canvasLaunchOpacity: Double = blackingOut ? blackout.fadeOut : 1

            ZStack(alignment: .top) {
                // Keep the near-black frame around the composer while it is open,
                // then switch every launch path to the shared #F7F4F3 surface.
                (launching
                    ? Theme.cardItem
                    : Color(red: 5 / 255, green: 5 / 255, blue: 5 / 255))
                    .ignoresSafeArea()
                    .opacity(store.composerActive || launching ? 1 : 0)

                CardSwapShockwaveOverlay(trigger: store.swapShockwaveTrigger)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .zIndex(1)

                // The live canvas — L0 parent, the curtain layers and the
                // follow-up pill. During composer launch it fades away as one
                // flattened layer, then the static-card overlay carries the load.
                canvasStack(m)
                    // Flatten the whole subtree into ONE layer before transforming,
                    // so it scales/clips as a single texture.
                    .compositingGroup()
                    // Clip BEFORE scaling so the rounded corners shrink into the
                    // card; pre-scale radius divides out the scale to land on 34.
                    .clipShape(RoundedRectangle(cornerRadius: canvasCorner, style: .continuous))
                    .scaleEffect(canvasScale, anchor: .top)
                    .offset(y: canvasOffset)
                    .blur(radius: canvasBlur)
                    .overlay(Color.black.opacity(canvasDim).ignoresSafeArea())
                    .shadow(color: .black.opacity(canvasShadow), radius: 24, y: 10)
                    .opacity(canvasLaunchOpacity)
                    // Drive the composer shrink from one spring keyed to the toggle.
                    // During launch, the canvas fade is driven by `launch`; the
                    // composer toggle only removes the sheet and keyboard.
                    .animation(launching ? Theme.springMorph : Theme.springCanvas, value: store.composerActive)
                    // Dragging the composer up toward the full takeover fades the
                    // shrunken canvas away behind it.
                    .fadeOut(store.composerReveal, in: 0.45...1.0)
                    .zIndex(2)

                // ONE global nav header, mounted once across every non-empty
                // state (canvas · overview · trip). Kept full-size and UNSCALED
                // above the shrunken canvas so the toolbar stays put. It stays put
                // AND interactive while the composer is up too — its left button
                // morphs into the composer's close (the right control fades), so
                // the composer needs no close button of its own. zIndex above the
                // sheet keeps that close tappable over the full-screen takeover.
                if !showHome && !launching {
                    NavHeader(store: store, metrics: m)
                        .zIndex(16)
                }

                // The AI composer sheet — slides in over the shrunken canvas.
                // On submit, keep it mounted just long enough to slide/fade down
                // while the blurred canvas fades out underneath.
                if (store.composerActive && !launching) || launchComposerExit {
                    ComposerView(store: store, metrics: m)
                        .zIndex(15)
                }

                // Homepage launch load state — the Figma loading video plays
                // full-screen while the new thread builds, then fades off over
                // the first moments of the direct card → results morph.
                if launching && !store.launchFromCurrent {
                    let loadFade: Double = phase == .expanding
                        ? progress(of: store.launch,
                                   in: AppStore.launchLoadFadeStart...AppStore.launchLoadFadeEnd).fadeOut
                        : 1
                    HomeLoadingVideoView()
                        .ignoresSafeArea()
                        .opacity(loadFade)
                        .allowsHitTesting(false)
                        .zIndex(20)
                }

                // Card-swap overlay for launches from an existing canvas: the old
                // card pops in over the loading surface, then the incoming card
                // rises from just beneath it and pushes the old card upward.
                // Homepage launches skip this overlay and expand the live curtain
                // directly from the load video into results. The incoming card is the live curtain itself,
                // so the same layer that rises into center also scales into results.
                //
                // Mounted for the whole launch (never gated on the animated
                // `launch` at `launchSwapEnd`, or `withAnimation` would evaluate
                // that gate at its endpoint and drop the overlay before the swap
                // plays). Offsets/opacity are plain animatable modifiers, so each
                // staged spring animates them.
                if store.launching,
                   store.launchFromCurrent,
                   store.swapInThreadID != nil || store.swapOutThreadID != nil {
                    let pop = progress(of: store.launch,
                                       in: AppStore.launchBlackoutEnd...AppStore.launchCollapseEnd)
                    let sp = progress(of: store.launch,
                                      in: AppStore.launchCollapseEnd...AppStore.launchSwapEnd)
                    let push = m.centerCardRect.height + 12
                    ZStack {
                        if let outID = store.swapOutThreadID, let t = store.thread(outID) {
                            swapCard(t, m)
                                .offset(y: 18 * (1 - pop.eased) - push * sp.eased)
                                .scaleEffect(lerp(0.94, 1, pop.eased) * lerp(1, 0.97, sp.eased))
                                .blur(radius: lerp(12, 0, pop.eased) + lerp(0, 6, sp.eased))
                                .opacity(pop.fadeIn * sp.fadeOut)
                        }
                    }
                    .zIndex(20)
                }

            }
            .frame(width: geo.size.width, height: fullH, alignment: .top)
            .coordinateSpace(.named("root"))
            // Disabled during a launch so the loading toggle's tree-wide ease
            // doesn't fight the collapse/expand springs.
            .animation(store.launching ? nil : .easeInOut(duration: 0.45), value: store.isLoading)
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)   // the whole app is light now
        #if DEBUG
        .task {
            if let level = ProcessInfo.processInfo.environment["SEED_DEMO"] {
                store.seedDemo(level)
            }
        }
        #endif
    }

    // MARK: - Card-swap overlay

    /// A static centered trip-overview row card for the launch swap. Matches the
    /// CurtainSheet's collapsed target (`centerCardRect`) so the incoming card and
    /// the new curtain's collapsed state line up exactly.
    @ViewBuilder
    private func swapCard(_ thread: ThreadNode, _ m: Metrics) -> some View {
        OverviewCardRow(heading: Copy["overview.resultsHeading"],
                        title: thread.title,
                        images: thread.fanAssets,
                        isLogo: thread.fanIsLogo)
            .frame(width: m.centerCardRect.width)
            .position(x: m.centerCardRect.midX, y: m.centerCardRect.midY)
            .allowsHitTesting(false)
    }

    // MARK: - Live canvas

    /// The live canvas subtree — L0 parent, the curtain layers, and the follow-up
    /// pill. Factored out so the body can transform it as one flattened unit.
    @ViewBuilder
    private func canvasStack(_ m: Metrics) -> some View {
        let showHome = store.isEmpty || store.showHome
        let homepageLaunchEntrance = store.launching && !store.launchFromCurrent && store.launchPhase == .expanding
        let homeLaunch = store.homeLaunchProgress
        let homeMapOpacity: Double = homepageLaunchEntrance ? homeLaunch.fadeIn : 1
        let homeMapBlur: CGFloat = homepageLaunchEntrance ? lerp(14, 0, homeLaunch.eased) : 0
        let homeCanvasOpacity: Double = homepageLaunchEntrance ? homeLaunch.fadeIn : 1
        let homeCanvasOffset: CGFloat = homepageLaunchEntrance ? lerp(96, 0, homeLaunch.eased) : 0
        let homeCanvasBlur: CGFloat = homepageLaunchEntrance ? lerp(10, 0, homeLaunch.eased) : 0
        // Live-curtain opacity during a launch:
        //   • collapsing phase → fully shown (it IS the old canvas collapsing);
        //   • expanding phase from an existing canvas → the live curtain is the
        //     incoming card. It rises into center during the swap window, then the
        //     same layer scales/blurs into results.
        let liveCurtainSwap = progress(of: store.launch, in: AppStore.launchCollapseEnd...AppStore.launchSwapEnd)
        let liveCurtainPush = m.centerCardRect.height + 12
        let curtainOpacity: Double = {
            if store.canvasDismissing { return 0 }
            guard store.launching, store.launchPhase == .expanding else { return 1 }
            guard store.launchFromCurrent else { return 1 }
            return liveCurtainSwap.fadeIn
        }()
        let curtainOffsetY: CGFloat = {
            if store.canvasDismissing { return m.H }
            guard store.launching, store.launchPhase == .expanding else { return 0 }
            guard store.launchFromCurrent else { return 0 }
            return liveCurtainPush * (1 - liveCurtainSwap.eased)
        }()
        ZStack(alignment: .top) {
            // L0 — persistent parent. Hidden while launching from a canvas so the
            // near-black backdrop shows behind the collapsing/expanding card
            // instead of the trip list (we never navigate to the trip overview).
            if showHome {
                EmptySearchView(store: store, metrics: m)
            } else if !store.launching {
                TripOverviewView(store: store, metrics: m)
            }

            // Curtain layers — mounted whenever a thread is open.
            if store.revealingThreadID != nil, let thread = store.openThread {
                ZStack(alignment: .top) {
                    // A live Apple Map behind the results sheet, revealed by
                    // dragging the sheet down. Composer launches freeze/hide it
                    // during collapse; homepage launches blur/fade it in under the
                    // reverse-shockwave cover.
                    if ResultsMapView.hasMap(for: thread) {
                        // Freeze the live map during the launch entrance — as a
                        // UIViewRepresentable it re-renders tiles under the morph
                        // and jitters. Hidden through composer collapse; homepage
                        // expand uses a separate blur/fade entrance.
                        let mapHidden = store.launching && store.launchPhase == .collapsing
                        // Keep MapKit out of the geometric morph. The map stays
                        // full-screen and simply blurs/fades while the canvas sheet
                        // scales into or out of the trip card.
                        let mapFade = progress(of: store.morphReveal, in: 0...0.9)
                        ResultsMapView(thread: thread)
                            .frame(width: m.size.width, height: m.size.height)
                            .blur(radius: Theme.morphBlurRadius * 1.8 * mapFade.eased + homeMapBlur)
                            .opacity((mapHidden ? 0.0 : mapFade.fadeOut) * homeMapOpacity)
                            .animation(.easeOut(duration: 0.3), value: mapHidden)
                            .allowsHitTesting(store.morphReveal < 0.1)
                            .zIndex(4.6)
                    }

                    Group {
                        // The open thread's query card — collapsed it's the floating
                        // title pill; it grows into the overview card and collapses
                        // back into its trip-list row.
                        OverviewCard(store: store, thread: thread, metrics: m)
                            .zIndex(5.5)
                        // Canvas is the morphing white surface across reveal 0→1: full
                        // screen, then pushed down below the query card. Fades toward
                        // the trip.
                        CurtainSheet(store: store, thread: thread, metrics: m)
                            .zIndex(5)
                    }
                    .offset(y: homeCanvasOffset)
                    .blur(radius: homeCanvasBlur)
                    .opacity(homeCanvasOpacity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .offset(y: curtainOffsetY)
                // During composer launches this is the incoming card itself, not a
                // duplicate overlay, so it can keep morphing into the canvas.
                .opacity(curtainOpacity)
            }

            // Shared bottom navigation for every non-home surface: home, the AI
            // follow-up entry, and the trip overview. The middle pill remains the
            // composer's shared-element source so its existing entrance morph and
            // interaction state stay unchanged.
            if !showHome && !store.launching {
                // Once the curtain is torn down we are resting on Journeys even
                // though `teardown()` resets the raw reveal driver to Results for
                // the next mount. Keep layout keyed to the visible stage so the
                // dock cannot briefly jump to its canvas structure.
                let bottomNavStage = store.revealingThreadID != nil
                    ? store.reveal
                    : AppStore.stageTrip
                // Side buttons belong to the results canvas only. They fade OUT as
                // the surface moves toward Journeys (stage 0→0.5), so they never
                // flash on arrival there — and stay hidden the whole time in the
                // top-controls structure, where the canvas carries no bottom
                // controls at all.
                let bottomSideVisibility = store.canvasNavigationStructure == .topBar
                    ? 0
                    : progress(of: bottomNavStage, in: 0...0.5).fadeOut
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 133)
                    .allowsHitTesting(false)

                    HStack(spacing: 24 * bottomSideVisibility) {
                        GlassCircleButton(icon: "home", size: 50) {
                            if store.revealingThreadID != nil {
                                store.dismissCanvasToHome()
                            } else {
                                store.goHome()
                            }
                        }
                        .accessibilityLabel("Home")
                        .opacity(bottomSideVisibility)
                        .frame(width: 50 * bottomSideVisibility)
                        .clipped()
                        .allowsHitTesting(
                            store.revealingThreadID != nil && bottomSideVisibility > 0.9
                        )

                        GlassPill(variant: .followup,
                                  isDark: false,
                                  loading: store.isLoading) { _ in }
                            .allowsHitTesting(false)
                            .overlay {
                                Button {
                                    store.openComposer()
                                } label: {
                                    Color.clear.contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Ask or follow up")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            // Publish the middle pill only: the composer still
                            // grows from the exact control the user tapped.
                            .captureFrame(
                                enabled: !store.composerActive && !store.launching
                            ) {
                                store.followUpPillFrame = $0
                            }

                        GlassCircleButton(icon: "distance", size: 50) {
                            guard store.revealingThreadID != nil else { return }
                            withAnimation(Theme.springMorph) {
                                store.reveal = AppStore.stageTrip
                            } completion: {
                                store.teardown()
                            }
                        }
                        .accessibilityLabel("Trip overview")
                        .opacity(bottomSideVisibility)
                        .frame(width: 50 * bottomSideVisibility)
                        .clipped()
                        .allowsHitTesting(
                            store.revealingThreadID != nil && bottomSideVisibility > 0.9
                        )
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, m.safeTop > 20 ? 40 : 24)
                }
                // The morph surface replaces the whole dock while composing.
                .opacity(store.composerActive ? 0 : 1)
                .allowsHitTesting(!store.composerActive)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(.keyboard)
                .zIndex(10)
            }
        }
    }
}

private struct CardSwapShockwaveOverlay: View {
    let trigger: Int

    @State private var active = false
    @State private var visible = false
    @State private var controller = DotGridController()
    @State private var replayTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if active {
                DotGridView(params: .default, controller: controller, transparent: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(visible ? 1 : 0)
                    .scaleEffect(visible ? 1 : 0.985)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: trigger) { _, newValue in
            guard newValue > 0 else { return }
            replay()
        }
        .onDisappear {
            replayTask?.cancel()
            replayTask = nil
        }
    }

    @MainActor
    private func replay() {
        replayTask?.cancel()
        controller = DotGridController()
        controller.mode = .flat
        active = true
        visible = false

        withAnimation(.easeOut(duration: 0.14)) {
            visible = true
        }

        replayTask = Task { @MainActor in
            do {
                // Let SwiftUI mount the MTKView and attach the renderer first.
                try await Task.sleep(for: .milliseconds(35))
                guard !Task.isCancelled else { return }
                controller.fire(.shockwave)

                try await Task.sleep(for: .seconds(1.55))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.35)) {
                    visible = false
                }

                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                active = false
                replayTask = nil
            } catch {
                // Cancellation is expected if another launch starts immediately.
            }
        }
    }
}

extension View {
    /// Shared drag that scrubs `store.reveal` 1:1 with the finger. Thin wrapper
    /// over `morphScrub`; the settle rule is bespoke — a BINARY snap to results
    /// (0) or trip (2), skipping the overview stage, with the trip landing
    /// tearing the curtain down. Taps still pass through.
    func revealDrag(_ store: AppStore) -> some View {
        morphScrub(Binding(get: { store.reveal }, set: { store.reveal = $0 }),
                   over: 0...2, distance: 280) { _, _, drag in
            let fling = drag.predictedEndTranslation.height - drag.translation.height
            var target: CGFloat = store.reveal < 1 ? AppStore.stageResults : AppStore.stageTrip
            if abs(fling) > 250 {
                target = fling > 0 ? AppStore.stageTrip : AppStore.stageResults
            }
            if target >= AppStore.stageTrip {
                withAnimation(Theme.springMorph) { store.reveal = AppStore.stageTrip }
                    completion: { store.teardown() }
            } else {
                withAnimation(Theme.springMorph) { store.reveal = AppStore.stageResults }
            }
        }
    }
}

#Preview {
    RootView()
}
