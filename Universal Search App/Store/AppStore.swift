//
//  AppStore.swift
//  Universal Search App
//
//  The single observable store. A continuous `reveal` (0 Results/full canvas ·
//  1 open overview · 2 trip list) drives the curtain morph; the views frame-
//  interpolate against it.
//

import SwiftUI
import UIKit

enum CanvasNavigationStructure: String, CaseIterable, Identifiable {
    case bottomDock
    case topBar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottomDock: return "Bottom dock"
        case .topBar: return "Top controls"
        }
    }
}

@MainActor
@Observable
final class AppStore {
    // Stages on the reveal axis.
    static let stageResults: CGFloat = 0
    static let stageOverview: CGFloat = 1   // open overview
    static let stageTrip: CGFloat = 2

    // Windows on the single `launch` driver (0…1): fade the composer/current
    // canvas to black, pop the existing centered card in, push-swap the old card
    // out for the new one, then expand the new card into the canvas.
    static let launchBlackoutEnd: CGFloat = 0.18
    static let launchCollapseEnd: CGFloat = 0.34
    static let launchSwapEnd: CGFloat = 0.62
    /// Homepage load cover fades as the map/canvas entrance comes in. Homepage
    /// launches no longer use the centered-card morph, so this can happen earlier.
    static let launchLoadFadeStart: CGFloat = 0.72
    static let launchLoadFadeEnd: CGFloat = 0.92

    // Deliberate pauses between composer launch stages so the sequence reads
    // staggered, not instant: a slower fade to black, then a quick pop/swap
    // breath before the new card morphs into the canvas.
    static let launchClearBeat: TimeInterval = 0.78
    static let launchCardPopBeat: TimeInterval = 0.08
    static let launchSwapToExpandBeat: TimeInterval = 0.26
    /// Composer swap flourish fires during the tail of the 1.5s card-swap, just
    /// before the incoming card fully settles into center.
    static let launchSwapShockwaveDelay: TimeInterval = 1.22
    /// Minimum time the dot-grid load state stays up, so instant mock/baked
    /// responses still show the full loading animation.
    static let minLoadDuration: TimeInterval = 2.2
    /// Shorter floor during a card-swap launch — just long enough for the
    /// blackout/card-pop to land before the swap, so pop → swap → expand stays
    /// continuous instead of freezing on the centered card.
    static let launchLoadFloor: TimeInterval = 0.5

    var threads: [ThreadNode] = [] {
        didSet { tripSections = buildTripSections(threads) }
    }
    /// Cached trip sections — rebuilt only when `threads` changes, so the views
    /// don't recompute `buildTripSections` on every reveal-scrub frame.
    private(set) var tripSections: [TripSection] = []
    var tripMessages: [Message] = []
    var openThreadID: String?
    var isLoading = false
    /// When true, the home screen (EmptySearchView) is shown over the existing
    /// trip — used when backing out of the canvas all the way to the homepage.
    var showHome = false
    /// Drives the straight-down slide of the curtain layers when dismissing a
    /// canvas back to the homepage (home shows through behind, no trip flash).
    var canvasDismissing = false
    /// The last canvas target that was open before collapsing to the trip
    /// overview — so back from the trip overview re-opens it.
    var lastOpenThreadID: String?
    var lastOpenActivityID: String?
    /// Developer-selectable navigation treatment for the results canvas.
    var canvasNavigationStructure: CanvasNavigationStructure = .bottomDock

    /// Continuous curtain position: 0 Results · 1 Overview · 2 Trip.
    var reveal: CGFloat = 0
    /// Non-nil ⇔ the curtain layers are mounted.
    var revealingThreadID: String?

    // MARK: - launch (card-swap entrance)

    /// Phases of the card-swap launch sequence (composer / homepage submit).
    /// `collapsing` = the composer/current canvas is fading to black and the old
    /// centered card is popping in while the new thread builds; `expanding` = the
    /// new curtain is mounted and the swap + expand windows of `launch` play.
    enum LaunchPhase { case idle, collapsing, expanding }
    var launchPhase: LaunchPhase = .idle

    /// The single continuous launch driver (0 = pre-launch, 1 = new canvas fully
    /// expanded). All launch geometry derives from windowed slices of this; see
    /// `morphReveal` and RootView's swap overlay.
    var launch: CGFloat = 0

    /// True for the whole launch sequence until the new canvas has expanded into
    /// place. Gates the near-black backdrop, hides the trip list + map, and
    /// suppresses the nav header.
    var launching = false
    /// The query submitted (shown in the homepage docked pill / sent).
    var launchQuery = ""
    /// True when launched from an existing canvas (composer): the current canvas
    /// collapses into a centered card and swaps out. False on the homepage.
    var launchFromCurrent = false
    /// While true, the reveal collapse/expand targets a CENTERED card
    /// (`metrics.centerCardRect`) instead of the thread's trip-list row slot.
    var launchCentered = false
    /// The outgoing thread whose centered card slides UP and out during the swap.
    var swapOutThreadID: String?
    /// The incoming thread whose centered card rises from the BOTTOM during the
    /// swap and then expands into the canvas.
    var swapInThreadID: String?
    /// Increments when the composer card-swap lands, so RootView can replay the
    /// one-shot dot-grid shockwave without coupling it to interpolated launch time.
    var swapShockwaveTrigger = 0
    /// The compare activity to open once the incoming card expands (nil = results).
    var swapInActivityID: String?
    /// The built thread's ids, delivered by `send()` and awaited by the staged
    /// launch sequence so the spawn/swap beat never starts before it's ready.
    @ObservationIgnored private var launchThreadResult: (threadID: String?, activityID: String?)?
    @ObservationIgnored private var launchThreadWaiter: CheckedContinuation<(String?, String?), Never>?
    /// When set, the open target is a compare activity (not the results).
    var openActivityID: String?
    /// Live list-slot frames of EVERY trip row (keyed by entry id), in "root"
    /// space — the destinations the open card and the peeking stack morph into.
    /// Measured for all rows up front (while nothing is open), so the morph has a
    /// valid collapsed frame the instant a card is tapped.
    var slotFrames: [String: CGRect] = [:]

    /// The open entry's id (the results row, or the open compare activity).
    var openEntryID: String? {
        guard let tid = openThreadID else { return nil }
        return openActivityID ?? "\(tid)-results"
    }
    /// Attributes selected in the open comparison's "Compare on" chips.
    var compareAttributes: Set<String> = []

    // MARK: - composer

    /// The AI composer overlay is presented (launched from the follow-up input
    /// on any non-home screen). While active the live canvas behind scales down
    /// (Siri-style) and the composer rides in as a sheet over it.
    var composerActive = false
    /// Text shared across the compact composer and the expanded home composer.
    var composerText = ""
    /// Continuous composer position: 0 split (shrunken canvas + composer sheet) ·
    /// 1 full home-style search takeover. Drag up grows it toward 1.
    var composerReveal: CGFloat = 0
    /// Resting frame of the shared follow-up pill (root space). The composer's
    /// entrance morph grows this rect into the docked sheet, so the pill appears
    /// to lift off the canvas and expand rather than a sheet sliding up.
    var followUpPillFrame: CGRect = .zero

    // MARK: - derived

    var isEmpty: Bool { threads.isEmpty && !isLoading }

    /// The reveal value the curtain views frame-morph against. Normally this is
    /// just `reveal`; during a launch it is DERIVED from the single `launch`
    /// driver so the expand (new curtain) rides the launch timeline instead of a
    /// local spring. Composer launches map launch swapEnd…1 → reveal 2→0 from
    /// the centered swap card; homepage launches stay at results geometry and use
    /// a separate root-level map/canvas entrance.
    var morphReveal: CGFloat {
        guard launching else { return reveal }
        switch launchPhase {
        case .collapsing:
            return reveal
        case .expanding:
            guard launchFromCurrent else { return Self.stageResults }
            return 2 - progress(of: launch, in: Self.launchSwapEnd...1).eased * 2
        case .idle:
            return reveal
        }
    }

    /// Homepage-only entrance progress after the reverse-shockwave loading cover:
    /// 0 = hidden/blurred below, 1 = settled results.
    var homeLaunchProgress: MorphProgress {
        progress(of: launch, in: Self.launchSwapEnd...1)
    }

    var openThread: ThreadNode? {
        guard let id = openThreadID else { return nil }
        return threads.first { $0.id == id }
    }

    func thread(_ id: String) -> ThreadNode? { threads.first { $0.id == id } }

    /// The comparison being viewed, if a compare activity is open.
    var openComparison: Comparison? {
        guard let aid = openActivityID else { return nil }
        return openThread?.activities.first { $0.id == aid }?.comparison
    }

    // MARK: - navigation

    /// Open a thread's results. If a curtain is already mounted (switching threads
    /// or a freshly created thread), onAppear won't fire again, so animate to
    /// Results here; otherwise mount and let CurtainSheet.onAppear zoom in.
    func open(_ id: String) {
        showHome = false
        let alreadyMounted = revealingThreadID != nil
        revealingThreadID = id
        openThreadID = id
        openActivityID = nil
        if alreadyMounted && !launching {
            withAnimation(Theme.springMorph) { reveal = Self.stageResults }
        } else {
            // Fresh mount (incl. the card-swap launch's expand): park at Trip so
            // CurtainSheet.onAppear zooms out — from the centered card when
            // `launchCentered`, otherwise the trip-list row slot.
            reveal = Self.stageTrip
        }
    }

    /// Open a compare activity — same curtain, comparison canvas.
    func openActivity(_ activityID: String, in threadID: String) {
        showHome = false
        let alreadyMounted = revealingThreadID == threadID
        revealingThreadID = threadID
        openThreadID = threadID
        openActivityID = activityID
        let comp = thread(threadID)?.activities.first { $0.id == activityID }?.comparison
        compareAttributes = Set((comp?.categories.prefix(2) ?? []).map(\.name))
        if alreadyMounted {
            withAnimation(Theme.springMorph) { reveal = Self.stageResults }
        } else {
            reveal = Self.stageTrip
        }
    }

    /// Launch the composer from a non-home screen. `seed` pre-fills the field. It
    /// opens condensed (docked sheet over the shrunken canvas) and can be dragged
    /// up to the full takeover. (The home composer is presented separately as a
    /// zooming full-screen cover — see `HomeComposerCover`.)
    func openComposer(seed: String = "") {
        composerText = seed
        composerReveal = 0
        withAnimation(Theme.springMorph) { composerActive = true }
    }

    /// Dismiss the composer back to the underlying screen.
    func closeComposer() {
        withAnimation(Theme.springMorph) { composerActive = false }
        composerReveal = 0
    }

    /// Submit the composer text. Runs the launch as a deliberately STAGED
    /// sequence: (1) fade the composer/current canvas to black and dismiss the
    /// keyboard, then (2) pop the existing centered card and push-swap in the new
    /// one, then (3) expand the new canvas — each beat landing before the next
    /// begins (`runLaunchStages`). `send()` builds the thread in parallel.
    func submitComposer() async {
        let text = composerText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !launching, !isLoading else { return }
        let fromCurrent = revealingThreadID != nil
        launchQuery = text
        launchFromCurrent = fromCurrent
        launchCentered = fromCurrent
        launching = true
        launch = 0
        launchPhase = .collapsing
        swapOutThreadID = fromCurrent ? openThreadID : nil
        swapInThreadID = nil
        swapInActivityID = nil
        launchThreadResult = nil
        launchThreadWaiter = nil
        composerReveal = 0
        composerActive = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
        // Stage 1 — dismiss the keyboard, slide/fade the composer down, and fade
        // the shrunken blurred canvas to black. The old card stays hidden until
        // the blackout window lands.
        withAnimation(Theme.springMorph) {
            if fromCurrent { launch = Self.launchBlackoutEnd }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.launchClearBeat))
            await runLaunchStages()
        }
        await send(text)
    }

    /// Fully collapsed to the trip overview — tear the curtain layers down.
    func teardown() {
        if let tid = openThreadID {
            lastOpenThreadID = tid
            lastOpenActivityID = openActivityID
        }
        openThreadID = nil
        revealingThreadID = nil
        openActivityID = nil
        reveal = Self.stageResults
    }

    /// Back out all the way to the homepage (EmptySearchView) over the trip.
    func goHome() {
        teardown()
        showHome = true
    }

    /// Dismiss a canvas straight down to the homepage. Home becomes the L0
    /// parent behind the curtain immediately, the curtain slides off the bottom,
    /// then the layers tear down — so the trip overview never flashes.
    func dismissCanvasToHome() {
        showHome = true
        withAnimation(Theme.springMorph) { canvasDismissing = true }
            completion: {
                self.teardown()
                self.canvasDismissing = false
            }
    }

    /// Re-open the canvas that was last viewed before the trip overview — used by
    /// back from the trip overview.
    func reopenLast() {
        if let tid = lastOpenThreadID, let aid = lastOpenActivityID {
            openActivity(aid, in: tid)
        } else if let tid = lastOpenThreadID {
            open(tid)
        }
    }

    /// The staged launch sequence. Stage 1 (clear the composer + keyboard) is run
    /// by the caller; this owns the rest and awaits each spring so composer beats
    /// read distinctly: stage 2a pop the existing centered card over black ·
    /// stage 2b spawn the new card just beneath and push-swap it into the center ·
    /// stage 3 expand the new canvas out to full. Homepage launches skip the
    /// static card beat and go straight from the load video into stage 3. `send()`
    /// builds the thread in parallel and hands the ids over via
    /// `deliverLaunchThread`.
    private func runLaunchStages() async {
        // Stage 2a — pop the existing card over black. (Composer only; the
        // homepage has no previous canvas to show.)
        if launchFromCurrent {
            await animateLaunch(to: Self.launchCollapseEnd)
            try? await Task.sleep(for: .seconds(Self.launchCardPopBeat))
        }

        // Don't spawn / swap until the new thread has finished building.
        let (newThreadID, newActivityID) = await awaitLaunchThread()
        guard let newThreadID else { clearLaunch(); return }
        swapInThreadID = newThreadID
        swapInActivityID = newActivityID

        // Hand the mounted curtain over to the new thread. Composer launches park
        // at the centered card for the swap; homepage launches mount at results
        // geometry and let RootView handle the blur/fade/slide entrance.
        launchPhase = .expanding
        if launchFromCurrent {
            // Tear the old curtain down but KEEP the threads, so RootView's swap
            // overlay renders the static outgoing + incoming row cards with no gap.
            if swapOutThreadID == nil { swapOutThreadID = openThreadID }
            openThreadID = nil
            revealingThreadID = nil
            openActivityID = nil
            launch = Self.launchCollapseEnd
        } else {
            // Homepage: start the driver at the expand range; morphReveal remains
            // at results geometry, while homeLaunchProgress drives the entrance.
            launch = Self.launchSwapEnd
        }
        if let newActivityID { openActivity(newActivityID, in: newThreadID) } else { open(newThreadID) }

        // Let the freshly mounted curtain warm its layout before it moves.
        try? await Task.sleep(for: .seconds(0.05))

        if launchFromCurrent {
            // Stage 2b — spawn the new card just beneath and push-swap it in.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.launchSwapShockwaveDelay))
                guard launching, launchFromCurrent, launchPhase == .expanding else { return }
                swapShockwaveTrigger += 1
            }
            await animateLaunch(to: Self.launchSwapEnd, animation: Theme.springMorphCardSwap)
            try? await Task.sleep(for: .seconds(Self.launchSwapToExpandBeat))
        }

        // Stage 3 — expand the new canvas out to full screen.
        await animateLaunch(to: 1)
        clearLaunch()
    }

    /// Spring the single `launch` driver to `target`, returning only once the
    /// spring has settled — so the next stage starts from rest (a clean beat).
    private func animateLaunch(to target: CGFloat, animation: Animation = Theme.springMorph) async {
        await withCheckedContinuation { cont in
            withAnimation(animation) { launch = target } completion: {
                cont.resume()
            }
        }
    }

    /// Suspend until `send()` delivers the built thread's ids (or return them
    /// immediately if the build already finished).
    private func awaitLaunchThread() async -> (String?, String?) {
        if let r = launchThreadResult { return (r.threadID, r.activityID) }
        return await withCheckedContinuation { cont in
            launchThreadWaiter = cont
        }
    }

    /// Hand the built thread's ids to the staged launch sequence.
    private func deliverLaunchThread(threadID: String?, activityID: String?) {
        launchThreadResult = (threadID, activityID)
        if let waiter = launchThreadWaiter {
            launchThreadWaiter = nil
            waiter.resume(returning: (threadID, activityID))
        }
    }

    /// Clear every launch flag once the new canvas has fully expanded. `reveal`
    /// lands at Results (0) — identical to the `launch == 1` derived value, so the
    /// handoff back to the normal reveal system is seamless.
    private func clearLaunch() {
        launching = false
        launchCentered = false
        launchFromCurrent = false
        launchPhase = .idle
        swapOutThreadID = nil
        swapInThreadID = nil
        swapInActivityID = nil
        composerText = ""
        reveal = Self.stageResults
        launch = 0
    }

    // MARK: - message flow (port of AppV1.sendMessage)

    /// Every free-text input creates a NEW card (thread) in the trip overview.
    /// Only manual manipulation via chips (`refine: true`) overrides the open
    /// card in place.
    func send(_ raw: String, refine: Bool = false) async {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        let action = Mock.detectAction(text)
        let inThread = refine && openThread != nil
        let targetID: String? = inThread ? openThreadID : nil
        let snapshot = targetID.flatMap { thread($0) }
        let history = snapshot?.messages ?? tripMessages

        appendMessage(Message(role: .user, text: text), toThread: targetID)
        isLoading = true
        let loadStart = Date()

        // The new card the launch swap expands into (free-text branch only).
        var launchThreadID: String?
        var launchActivityID: String?

        let resp = await assistant(node: snapshot, history: history, text: text)
        var reply = resp.reply
        let threadPayload = resp.thread
        var prebuilt = resp.prebuiltThread

        if inThread, let id = targetID, let idx = threads.firstIndex(where: { $0.id == id }) {
            // Chip / manual refinement — override the existing card.
            var node = threads[idx]
            switch action {
            case .compare:
                let comp = Mock.buildComparison(from: node)
                node = Mock.appendActivity(node, type: .compare, subtitle: comp.versusTitle, comparison: comp)
            case .map:
                node = Mock.appendActivity(node, type: .map, subtitle: threadPayload?.label ?? cap(text))
            case nil:
                if let payload = threadPayload { node = Mock.applyRefinement(node, payload) }
            }
            node.messages.append(Message(role: .assistant, text: reply))
            threads[idx] = node
            if action == .compare, let newAct = node.activities.last {
                openActivity(newAct.id, in: id)
            }
        } else {
            // Free-text input — always a brand-new card. Build from the payload/
            // prebuilt; fall back to a generic thread so every input yields a card.
            if threadPayload == nil, prebuilt == nil {
                let mock = Mock.generateResponse(node: nil, text: text)
                if let item = mock.prebuiltThread {
                    prebuilt = item
                    if reply.isEmpty { reply = mock.reply }
                }
            }
            var item = prebuilt ?? threadPayload.map { Mock.buildThreadNode($0) } ?? Mock.genericThread(text)
            if action == .compare {
                let comp = Mock.buildComparison(from: item)
                item = Mock.appendActivity(item, type: .compare, subtitle: comp.versusTitle, comparison: comp)
            }
            threads.append(item)
            tripMessages.append(Message(role: .assistant, text: reply))
            let newActivityID = (action == .compare) ? item.activities.last?.id : nil
            if launching {
                // Defer opening: the card-swap launch owns the entrance and will
                // open this thread when the new card expands.
                launchThreadID = item.id
                launchActivityID = newActivityID
            } else if let aid = newActivityID {
                openActivity(aid, in: item.id)
            } else {
                open(item.id)
            }
        }

        // Hold the load state for a minimum window so mock/baked responses (which
        // resolve near-instantly) still read as loading. A composer card-swap uses
        // a much shorter floor so collapse → swap → expand flows continuously; a
        // homepage launch keeps the full floor so the suitcase load loop reads.
        let floor = (launching && launchFromCurrent) ? Self.launchLoadFloor : Self.minLoadDuration
        let elapsed = Date().timeIntervalSince(loadStart)
        if elapsed < floor {
            let remaining = floor - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }

        isLoading = false

        // Launch flow: hand the built thread to the staged sequence, which is
        // running in parallel and awaits this before the spawn / swap beat.
        if launching {
            deliverLaunchThread(threadID: launchThreadID, activityID: launchActivityID)
        }
    }

    // MARK: - thread editing

    func deleteThread(_ id: String) {
        threads.removeAll { $0.id == id }
        if openThreadID == id { teardown() }
    }

    #if DEBUG
    /// Debug-only deterministic seed for screenshots/demos. Pair with
    /// FREEZE_REVEAL to hold a static reveal value.
    func seedDemo(_ level: String) {
        let resp = Mock.generateResponse(node: nil, text: "hotels in miami with a pool")
        guard let item = resp.prebuiltThread else { return }
        threads = [item]
        switch level {
        case "l1": break
        case "compare":
            var node = item
            let comp = Mock.buildComparison(from: node)
            node = Mock.appendActivity(node, type: .compare, subtitle: comp.versusTitle, comparison: comp)
            threads = [node]
            if let flights = Mock.generateResponse(node: nil, text: "flights to miami").prebuiltThread {
                threads.append(flights)
            }
            if let act = node.activities.last { openActivity(act.id, in: node.id) }
        default:
            revealingThreadID = item.id; openThreadID = item.id
        }
    }
    #endif

    // MARK: - private

    private func assistant(node: ThreadNode?, history: [Message], text: String) async -> AssistantResponse {
        // Covered destinations (LA, Tampa, Mexican beach cities) resolve from the
        // baked dataset — no live LLM call. Only fires for brand-new queries.
        if node == nil, let baked = DestinationData.response(text: text) {
            return baked
        }
        do {
            guard !Secrets.openAIKey.isEmpty else { throw AIError.notConfigured }
            return try await OpenAIClient.requestAssistant(node: node, history: history, userText: text)
        } catch {
            return Mock.generateResponse(node: node, text: text)
        }
    }

    private func appendMessage(_ m: Message, toThread id: String?) {
        if let id, let idx = threads.firstIndex(where: { $0.id == id }) {
            threads[idx].messages.append(m)
        } else {
            tripMessages.append(m)
        }
    }

    private func cap(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
