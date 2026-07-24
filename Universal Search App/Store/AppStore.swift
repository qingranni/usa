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

enum AssistantSourceMode: String, CaseIterable, Identifiable {
    case narrativeMock
    case genUI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .narrativeMock: return "Narrative + mock"
        case .genUI: return "Gen-UI"
        }
    }

    var subtitle: String {
        switch self {
        case .narrativeMock: return "Unlock authored golden paths, then fall back to mock results"
        case .genUI: return "Run Gen-UI in app with direct live providers and observable partial results"
        }
    }

    var icon: String {
        switch self {
        case .narrativeMock: return "bubble.left.and.bubble.right"
        case .genUI: return "square.stack.3d.up"
        }
    }
}

enum DataSourceError: LocalizedError {
    case narrativeMockUnavailable

    var errorDescription: String? {
        switch self {
        case .narrativeMockUnavailable:
            return "Narrative + mock has no results for this search."
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
    var canvasNavigationStructure: CanvasNavigationStructure = .topBar
    /// Selection shared by the Mexico map and its floating destination carousel.
    var selectedMexicoDestinationID: String?
    /// Beat 1 of the card→packages transition: the persistent map flies to Cancun
    /// and the orientation pins fade out. Stays true through beat 1.5 (pins in);
    /// cleared at beat 2 (sheet slides up, map pans, pill morphs). See `openPackages`.
    var mexicoPackageFly = false
    /// Beat 1.5: flipped true once the fly has settled so the Cancun package pins
    /// stagger in *after* the shift rather than during it.
    var mexicoPackagePinsIn = false
    /// True when a pin-map results sheet (Mexico orientation or Cancun packages)
    /// is dragged down to its smallest detent, so the map behind it reframes: pins
    /// centered in the taller visible area and zoomed in, instead of the default
    /// sheet-up framing.
    var mexicoMapCollapsed = false
    /// How much the results sheet covers the map behind it: 0 at the medium (and
    /// smaller) detents where the map reads normally, ramping to 1 as the sheet
    /// rises toward the large detent and the map all but disappears. RootView uses
    /// it to blur + white-wash the peeking map into Figma's soft frosted backdrop
    /// so the sliver of map above a full sheet never reads as a live, crisp map.
    var mapCoverage: CGFloat = 0
    /// Bumped when the user taps the exposed map above the results sheet; the
    /// active `CurtainSheet` observes it and snaps back to its split (medium)
    /// detent so a tap on the map always returns to the map+sheet split.
    var mapSplitRequest = 0
    /// Exactly one of the two result pipelines owns each request.
    var assistantSourceMode: AssistantSourceMode = .narrativeMock
    var dataSourceErrorMessage: String?

    @ObservationIgnored private let genUIDataSource: any GenUIDataSourceProviding
    @ObservationIgnored private let composerRouter: any ComposerRouting

    init(
        genUIDataSource: (any GenUIDataSourceProviding)? = nil,
        composerRouter: (any ComposerRouting)? = nil
    ) {
        self.genUIDataSource = genUIDataSource ?? EmbeddedGenUIDataSource()
        self.composerRouter = composerRouter ?? EmbeddedLiveProviderFactory.composerRouter()
    }

    /// True once the canvas/results scroll content is pushed up far enough to
    /// slide under the floating title — fades the title out and lets the top
    /// grabber read against a small white gradient instead of running text.
    var canvasContentScrolled = false

    /// The narrative package results open with a one-time "destination discovery"
    /// prompt in the dock (in place of the ask-anything pill). Flipped true once
    /// the results have been scrolled a bit, so the pill morphs back to
    /// "Ask anything". Reset whenever a thread/activity is opened.
    var destinationDiscoveryRetired = false

    /// The Mexico vacation overview shows its "Can't decide?" discovery prompt
    /// only once the results have been scrolled all the way to the end — the
    /// mirror image of `destinationDiscoveryRetired`. Flipped true when the
    /// results scroll reaches the bottom; reset whenever a thread/activity opens.
    var destinationDiscoveryRevealed = false

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
    /// Continuous composer entrance: 0 = the resting follow-up pill · 1 = the
    /// docked composer. ONE surface morphs across this range (the pill grows and
    /// reshapes into the docked sheet), and it also drives `InlineAnswerView`'s
    /// resting→compose push-up, so the two read as a single motion. Animated in
    /// `openComposer`/`closeComposer`; `composerActive` gates the mount and stays
    /// true for the whole entrance AND exit morph (see `closeComposer`).
    var composerEntrance: CGFloat = 0
    /// Resting frame of the shared follow-up pill (root space). The composer's
    /// entrance morph grows this rect into the docked sheet, so the pill appears
    /// to lift off the canvas and expand rather than a sheet sliding up.
    var followUpPillFrame: CGRect = .zero

    // MARK: - package detail (Hyatt Ziva)

    /// The package card currently shown in the full-screen detail page (nil =
    /// closed). Mounts `PackageDetailView` as a top layer in `RootView`.
    var detailCard: Card?
    /// Continuous detail morph: 0 = the tapped card · 1 = the detail page fully
    /// expanded. Beats (hero fly-in, on-image chrome, rest of page) are windowed
    /// slices of this, evaluated per-frame inside the page's `AnimatableMorph`.
    var detailReveal: CGFloat = 0
    /// The tapped card's hero-image rect in "root" space — the frame the detail
    /// hero flies out of (and back into on dismiss).
    var detailHeroSource: CGRect = .zero

    /// A first contextual answer remains lightweight until the user replies.
    var inlineAnswerDraft: InlineAnswerDraft?

    /// An in-flight conversational reply. While set, the open conversation shows
    /// a thinking shim then streams the answer in — the composer has already
    /// reversed to the pill. `streamingActivityID` scopes it to the conversation
    /// it belongs to, so navigating away never leaks the shim elsewhere.
    var streamingTurn: StreamingTurn?
    var streamingActivityID: String?
    /// Bumped after a reply's user message lands, to scroll it to the top so the
    /// fresh turn — question + streaming answer — is what's in focus.
    var conversationScrollToken = 0
    /// Message index the scroll should pin to the top on the next token bump.
    var conversationScrollTarget: Int?
    /// Bumped whenever a results thread/activity opens, so the map results sheet
    /// snaps back to its medium detent and scrolls to the top — a newly opened
    /// card always starts from its default framing, never inheriting the previous
    /// card's detent or scroll offset.
    var resultsResetToken = 0
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    /// Set synchronously the instant a homepage submit begins, before the
    /// full-screen composer cover dismisses. It mounts the root loading surface
    /// underneath the cover so the cover's zoom-back-to-pill reveals the load
    /// screen rather than a flash of the homepage. Cleared once routing resolves:
    /// search routes hand off to `launching`; answer routes clear it directly.
    var homeSubmitLoading = false

    // MARK: - derived

    var isEmpty: Bool { threads.isEmpty && !isLoading }

    /// The follow-up placeholder ("Ask anything" on contextual surfaces, else
    /// "Ask or follow-up"). ONE source of truth shared by the resting dock pill
    /// and the composer's own placeholder, so the label can never differ between
    /// them mid-morph (which used to flash on tap).
    var composerPrompt: String {
        inlineAnswerDraft != nil
            || openConversation != nil
            || openThread?.presentation.canvasLayout == .mexicoOrientation
            || (openThreadID == nil && !showHome)
            ? "Ask anything"
            : Copy["search.followUp"]
    }

    /// True while the dock pill should show a destination-discovery prompt
    /// instead of the ask-anything pill: a narrative results thread is open,
    /// settled at the results stage, and hasn't been scrolled away yet.
    var showsDestinationDiscovery: Bool {
        destinationDiscoveryVariant != nil
    }

    /// Which destination-discovery prompt the dock pill should morph into, or
    /// `nil` when the ask-anything pill should stay put. The two narrative flows
    /// are mirror images:
    ///  • Cancun package results show the fanned-photo "at a glance" prompt from
    ///    the start, retiring once the results are scrolled a bit.
    ///  • The Mexico vacation overview hides the globe "Can't decide?" prompt
    ///    until the results are scrolled to the END, then reveals it.
    var destinationDiscoveryVariant: DestinationDiscoveryPill.Variant? {
        // The discovery prompt is a results-canvas affordance only. A question
        // opens an inline answer / conversation activity *on the same thread*
        // (openThread stays the package-shelves node), so gate it out whenever a
        // conversation or inline answer is what's actually on screen.
        // `mexicoPackageFly` is beat 1 of the card→packages transition (map fly +
        // pins). Hold the pill morph back until beat 2 (fly cleared) so it doesn't
        // morph in while the map is still settling.
        guard !composerActive, morphReveal < 0.5, !mexicoPackageFly,
              openConversation == nil, inlineAnswerDraft == nil,
              let thread = openThread, thread.source == .narrative
        else { return nil }
        switch thread.composition {
        case .packageShelves:
            // Suppress the "at a glance" prompt on the beachfront-refined step;
            // every other package-shelf screen (incl. the map→packages open) keeps it.
            guard thread.scenarioStep != "refined-packages" else { return nil }
            return destinationDiscoveryRetired ? nil : .cancunPackages
        case .blocks:
            return destinationDiscoveryRevealed ? .mexicoVacations : nil
        default:
            return nil
        }
    }

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

    var openConversation: Conversation? {
        guard let aid = openActivityID else { return nil }
        return openThread?.activities.first { $0.id == aid }?.conversation
    }

    /// Identity of the fresh quick-answer conversation once its reply promotes it
    /// to a real activity. While this matches the open activity, ONE surface — the
    /// `QuickConversation` overlay — owns the rendering from the floating quick
    /// answer, through the compose expand, through every streamed reply, with no
    /// view swap. Cleared the moment navigation opens anything else, after which
    /// the conversation is just a normal activity rendered by the CurtainSheet.
    var freshConversationID: String?

    /// The conversation the `QuickConversation` overlay renders: the draft's
    /// conversation before the first reply, then the promoted activity's
    /// conversation. `nil` once we've navigated away (the CurtainSheet takes over).
    var quickConversation: Conversation? {
        if let draft = inlineAnswerDraft { return draft.conversation }
        if let id = freshConversationID, openActivityID == id { return openConversation }
        return nil
    }

    /// A from-trip conversation the CurtainSheet should render as a full canvas
    /// (with its collapse-to-trip morph). Excludes the fresh flow, which the
    /// overlay owns, so the two never render the same conversation at once.
    var canvasConversation: Conversation? {
        quickConversation == nil ? openConversation : nil
    }

    // MARK: - navigation

    /// A canvas position — a thread's results, or a compare/conversation activity
    /// within it.
    struct NavLocation: Equatable {
        var threadID: String
        var activityID: String?
    }

    /// A screen on the back stack. The homepage is implicit: an empty stack means
    /// back falls through to it.
    enum NavStep: Equatable {
        case canvas(NavLocation)
        case tripOverview
    }

    /// History of screens visited *before* the current one — canvases and the
    /// trip-overview alike, so back retraces the real path (e.g. conversational
    /// item → trip overview → results → home) rather than snapping to home.
    private(set) var navStack: [NavStep] = []

    /// The screen currently on display, or nil for the homepage (nothing to
    /// record — it is the implicit base of the stack).
    private var currentStep: NavStep? {
        if let tid = openThreadID {
            return .canvas(NavLocation(threadID: tid, activityID: openActivityID))
        }
        return showHome ? nil : .tripOverview
    }

    /// Record history before a forward navigation to `next`, keeping the stack a
    /// simple path (no repeats). If `next` is already on the stack, we're revisiting
    /// it — rewind by dropping it and everything above rather than appending, so
    /// cycles like results → trip → conversation → trip → results collapse instead
    /// of growing without bound (and back can never loop). Otherwise push the
    /// current screen. The stack therefore stays duplicate-free and bounded by the
    /// number of distinct screens.
    private func recordStep(before next: NavStep) {
        if let existing = navStack.firstIndex(of: next) {
            navStack.removeSubrange(existing...)
            return
        }
        guard let step = currentStep, step != next, step != navStack.last else { return }
        navStack.append(step)
    }

    /// Open a thread's results. If a curtain is already mounted (switching threads
    /// or a freshly created thread), onAppear won't fire again, so animate to
    /// Results here; otherwise mount and let CurtainSheet.onAppear zoom in.
    /// `record` pushes the outgoing screen onto the back stack (false for back /
    /// launch-expand navigations, which must not grow history).
    func open(_ id: String, record: Bool = true) {
        if record { recordStep(before: .canvas(NavLocation(threadID: id, activityID: nil))) }
        freshConversationID = nil
        showHome = false
        selectedMexicoDestinationID = nil
        mexicoPackageFly = false
        mexicoPackagePinsIn = false
        canvasContentScrolled = false
        destinationDiscoveryRetired = false
        destinationDiscoveryRevealed = false
        resultsResetToken += 1
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
    func openActivity(_ activityID: String, in threadID: String, record: Bool = true) {
        if record {
            recordStep(before: .canvas(NavLocation(threadID: threadID, activityID: activityID)))
        }
        // Opening anything other than the fresh conversation hands rendering back
        // to the CurtainSheet (a normal from-trip activity). `beginPendingInlineAnswerReply`
        // re-sets this right after promoting, so the overlay keeps ownership there.
        if activityID != freshConversationID { freshConversationID = nil }
        showHome = false
        selectedMexicoDestinationID = nil
        mexicoPackageFly = false
        mexicoPackagePinsIn = false
        canvasContentScrolled = false
        destinationDiscoveryRetired = false
        destinationDiscoveryRevealed = false
        resultsResetToken += 1
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
        composerEntrance = 0
        // Mount at entrance 0 (the surface sits exactly on the pill); ComposerView's
        // onAppear then springs `composerEntrance` to 1 so the fresh AnimatableMorph
        // tweens from 0 (a value set here would make it jump straight to 1).
        // Opening over a quick answer animates the toggle so the inline card's
        // answer text flies (matchedGeometry) into the conversation canvas that
        // replaces it; other opens keep the plain toggle (canvas shrink animates
        // via its own `.animation(value:)`).
        if inlineAnswerDraft != nil {
            withAnimation(Theme.springMorph) { composerActive = true }
        } else {
            composerActive = true
        }
    }

    /// Dismiss the composer back to the underlying screen. The surface stays
    /// mounted (`composerActive` true) and morphs full→docked→pill in reverse; only
    /// on completion does it unmount, so the resting pill takes over seamlessly.
    func closeComposer() {
        withAnimation(Theme.springMorph) {
            composerReveal = 0
            composerEntrance = 0
        } completion: {
            self.composerActive = false
        }
    }

    // MARK: - package detail

    /// Open the full-screen package detail from a tapped card. Mounts at reveal 0
    /// (the page's `onAppear` springs it to 1) so the hero morphs out of the
    /// card's captured image rect rather than snapping to the endpoint.
    func openPackageDetail(_ card: Card, source: CGRect) {
        detailHeroSource = source
        detailReveal = 0
        detailCard = card
    }

    /// Reverse the detail morph, then unmount once it has flown back to the card.
    func closePackageDetail() {
        withAnimation(Theme.springDetailMorph) {
            detailReveal = 0
        } completion: {
            self.detailCard = nil
        }
    }

    /// Classify composer input before choosing whether to answer, continue a chat,
    /// mutate the current results, or run the staged new-card launch.
    func submitComposer() async {
        let text = composerText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !launching, !isLoading, streamingTurn == nil else { return }
        dataSourceErrorMessage = nil
        let context = composerContext()
        if context.surface == .home { showHome = true }
        isLoading = true
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)

        // A question typed into an open conversation is (per the router contract)
        // a continue-conversation turn. Don't wait on the model with the sheet
        // hanging up: reverse the composer to the pill straight away, drop the
        // user's turn into the thread, and show the thinking shim while the
        // answer resolves — then stream it in.
        // The first reply promotes the floating inline answer into its own
        // conversation; every later reply continues that conversation. Both are
        // optimistic chat turns: reverse the composer, drop the user's turn in,
        // and raise the thinking shim while the answer resolves — then stream it.
        let optimisticChat = (context.surface == .conversation
            || context.surface == .inlineAnswer) && text.contains("?")
        if optimisticChat {
            finishComposerPresentation()
            if context.surface == .inlineAnswer {
                beginPendingInlineAnswerReply(query: text)
            } else {
                beginPendingConversationTurn(query: text)
            }
        }

        let routing: ComposerRoutingResult
        do {
            routing = try await composerRouter.route(query: text, context: context)
        } catch {
            if optimisticChat { cancelPendingConversationTurn() }
            failDataSource(
                (error as? LocalizedError)?.errorDescription
                    ?? "The question could not be understood."
            )
            return
        }

        // In narrative+mock mode an authored golden path owns its presentation.
        // Every covered step is a forward move that launches its OWN card — never
        // an in-place refine or a compare/map overlay — so the path reads as a
        // sequence of distinct results the user can step back through (e.g. "on
        // the beach" on the Cancun package flow opens a fresh beachfront-options
        // card). Only chat turns stay as answers.
        var route = routing.route
        if assistantSourceMode == .narrativeMock,
           route != .question, route != .continueConversation,
           NarrativeData.handles(current: openThread, text: text) {
            route = .newSearch
        }

        switch route {
        case .question:
            guard !routing.answer.isEmpty else {
                if optimisticChat { cancelPendingConversationTurn() }
                failDataSource("The question could not be answered right now.")
                return
            }
            if optimisticChat {
                streamPendingConversationTurn(routing: routing)
                break
            }
            finishComposerPresentation()
            if context.surface == .home {
                createHomeConversation(query: text, routing: routing)
            } else if context.surface == .conversation {
                appendConversationTurn(query: text, routing: routing)
            } else if context.surface == .inlineAnswer {
                promoteInlineAnswer(with: text, routing: routing)
            } else {
                createInlineAnswer(query: text, routing: routing)
            }

        case .continueConversation:
            guard !routing.answer.isEmpty else {
                if optimisticChat { cancelPendingConversationTurn() }
                failDataSource("The conversation could not be continued right now.")
                return
            }
            if optimisticChat {
                streamPendingConversationTurn(routing: routing)
                break
            }
            finishComposerPresentation()
            if context.surface == .inlineAnswer {
                promoteInlineAnswer(with: text, routing: routing)
            } else {
                appendConversationTurn(query: text, routing: routing)
            }

        case .refine:
            if optimisticChat { cancelPendingConversationTurn() }
            finishComposerPresentation(clearText: false)
            isLoading = false
            await send(text, refine: true, usesActionDetection: false)
            composerText = ""

        case .compare:
            if optimisticChat { cancelPendingConversationTurn() }
            finishComposerPresentation(clearText: false)
            isLoading = false
            if openThread != nil {
                await send(text, refine: true, actionOverride: .compare)
                composerText = ""
            } else {
                await beginSearchLaunch(text, actionOverride: .compare)
            }

        case .map:
            if optimisticChat { cancelPendingConversationTurn() }
            finishComposerPresentation(clearText: false)
            isLoading = false
            if openThread != nil {
                await send(text, refine: true, actionOverride: .map)
                composerText = ""
            } else {
                await beginSearchLaunch(text, actionOverride: .map)
            }

        case .newSearch:
            if optimisticChat { cancelPendingConversationTurn() }
            finishComposerPresentation(clearText: false)
            inlineAnswerDraft = nil
            isLoading = false
            await beginSearchLaunch(text)
        }
    }

    private func beginSearchLaunch(_ text: String, actionOverride: ActivityType? = nil) async {
        let fromCurrent = revealingThreadID != nil
        // A new search from an existing canvas is a forward step (record it); a
        // search from the homepage starts a fresh journey (clear the stack). The
        // expand stage nils `openThreadID` before re-opening, so record here.
        if fromCurrent {
            if let current = currentStep { navStack.append(current) }
        } else {
            navStack.removeAll()
        }
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
        composerEntrance = 0
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
        await send(text, actionOverride: actionOverride)
    }

    private func composerContext() -> ComposerContext {
        let surface: ComposerSurface
        let messages: [Message]
        if let draft = inlineAnswerDraft {
            surface = .inlineAnswer
            messages = draft.conversation.messages
        } else if let conversation = openConversation {
            surface = .conversation
            messages = conversation.messages
        } else if openThread != nil {
            surface = .results
            messages = openThread?.messages ?? []
        } else {
            surface = .home
            messages = tripMessages
        }

        let resultDescriptions = (openThread?.activeCards ?? []).prefix(8).map { card in
            [
                card.displayTitle,
                card.sublabel,
                card.displayPrice,
                card.highlights,
            ]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
        }
        return ComposerContext(
            surface: surface,
            threadID: openThreadID,
            title: openConversation?.title ?? inlineAnswerDraft?.conversation.title ?? openThread?.title,
            summary: openThread?.resultSets.last?.summary,
            filters: openThread?.presentation.filters ?? [],
            results: resultDescriptions,
            messages: messages
        )
    }

    private func finishComposerPresentation(clearText: Bool = true) {
        composerActive = false
        composerReveal = 0
        composerEntrance = 0
        isLoading = false
        // For search routes this runs in the same synchronous block as the
        // launch begins, so `launching` takes over the load surface with no gap;
        // for answer routes it retires the home submit's stand-in load screen.
        homeSubmitLoading = false
        if clearText { composerText = "" }
    }

    private func createInlineAnswer(query: String, routing: ComposerRoutingResult) {
        guard let threadID = openThreadID else {
            createHomeConversation(query: query, routing: routing)
            return
        }
        inlineAnswerDraft = InlineAnswerDraft(
            id: IDGen.uid("answer"),
            originThreadID: threadID,
            conversation: Conversation(
                title: conversationTitle(routing.title, fallback: query),
                messages: [
                    Message(role: .user, text: query),
                    Message(role: .assistant, text: routing.answer),
                ]
            )
        )
    }

    private func createHomeConversation(query: String, routing: ComposerRoutingResult) {
        let threadID = IDGen.uid("thread")
        let activityID = IDGen.uid("act")
        let title = conversationTitle(routing.title, fallback: query)
        let conversation = Conversation(
            title: title,
            messages: [
                Message(role: .user, text: query),
                Message(role: .assistant, text: routing.answer),
            ]
        )
        let activity = Activity(
            id: activityID,
            type: .conversation,
            subtitle: title,
            conversation: conversation
        )
        let thread = ThreadNode(
            id: threadID,
            kind: .other,
            title: title,
            presentation: ResultsPresentation(
                showsMap: false,
                showsFilters: false,
                overlaySheet: false
            ),
            preview: Preview(
                icon: "forum",
                imageURL: nil,
                sublabel: title,
                message: routing.answer,
                layoutId: "\(threadID)-conversation"
            ),
            activities: [activity],
            messages: conversation.messages,
            conversationOnly: true
        )
        threads.append(thread)
        inlineAnswerDraft = nil
        openActivity(activityID, in: threadID)
    }

    private func promoteInlineAnswer(with query: String, routing: ComposerRoutingResult) {
        guard let draft = inlineAnswerDraft,
              let index = threads.firstIndex(where: { $0.id == draft.originThreadID }) else {
            createHomeConversation(query: query, routing: routing)
            return
        }
        var conversation = draft.conversation
        conversation.messages.append(Message(role: .user, text: query))
        conversation.messages.append(Message(role: .assistant, text: routing.answer))
        if !routing.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversation.title = routing.title
        }
        let activity = Activity(
            id: IDGen.uid("act"),
            type: .conversation,
            subtitle: conversation.title,
            conversation: conversation
        )
        var thread = threads[index]
        thread.activities.append(activity)
        thread.messages.append(contentsOf: conversation.messages)
        threads[index] = thread
        inlineAnswerDraft = nil
        openActivity(activity.id, in: thread.id)
    }

    private func appendConversationTurn(query: String, routing: ComposerRoutingResult) {
        guard let threadID = openThreadID,
              let activityID = openActivityID,
              let threadIndex = threads.firstIndex(where: { $0.id == threadID }),
              let activityIndex = threads[threadIndex].activities.firstIndex(where: {
                  $0.id == activityID && $0.type == .conversation
              }),
              var conversation = threads[threadIndex].activities[activityIndex].conversation else {
            createHomeConversation(query: query, routing: routing)
            return
        }
        conversation.messages.append(Message(role: .user, text: query))
        conversation.messages.append(Message(role: .assistant, text: routing.answer))
        if !routing.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversation.title = routing.title
        }
        var thread = threads[threadIndex]
        thread.activities[activityIndex].conversation = conversation
        thread.activities[activityIndex].subtitle = conversation.title
        thread.messages.append(contentsOf: conversation.messages.suffix(2))
        threads[threadIndex] = thread
    }

    // MARK: - Streaming a conversational reply

    /// Locate the open conversation activity as `(threadIndex, activityIndex)`.
    private func openConversationIndices() -> (Int, Int)? {
        guard let threadID = openThreadID, let activityID = openActivityID,
              let ti = threads.firstIndex(where: { $0.id == threadID }),
              let ai = threads[ti].activities.firstIndex(where: {
                  $0.id == activityID && $0.type == .conversation
              }) else { return nil }
        return (ti, ai)
    }

    /// The first reply to a floating inline answer: promote the draft into a
    /// standing conversation activity on its origin thread (carrying the original
    /// Q&A plus the new user turn, but no answer yet), open it, and raise the
    /// thinking shim — so the inline sheet morphs into its own conversation view
    /// and the reply streams in exactly like a continued turn. The promotion is
    /// wrapped in the morph spring so the hand-off animates rather than snapping.
    private func beginPendingInlineAnswerReply(query: String) {
        guard let draft = inlineAnswerDraft,
              let index = threads.firstIndex(where: { $0.id == draft.originThreadID }) else {
            beginPendingConversationTurn(query: query)
            return
        }
        var conversation = draft.conversation
        conversation.messages.append(Message(role: .user, text: query))
        let activity = Activity(
            id: IDGen.uid("act"),
            type: .conversation,
            subtitle: conversation.title,
            conversation: conversation
        )
        var thread = threads[index]
        thread.activities.append(activity)
        thread.messages.append(contentsOf: conversation.messages)
        threads[index] = thread
        streamingActivityID = activity.id
        withAnimation(Theme.springMorph) {
            inlineAnswerDraft = nil
            openActivity(activity.id, in: thread.id)
            // Keep the same overlay owning this conversation across the promote —
            // `openActivity` cleared it, so re-mark it as the fresh conversation so
            // rendering never swaps to the CurtainSheet (no flash on the trip-entry).
            freshConversationID = activity.id
            streamingTurn = StreamingTurn()
        }
        // Pin the fresh question to the top so the incoming answer is in focus.
        conversationScrollTarget = conversation.messages.count - 1
        conversationScrollToken += 1
    }

    /// Drop the user's turn into the open conversation and raise the thinking
    /// shim; the streamed answer arrives via `streamPendingConversationTurn`.
    private func beginPendingConversationTurn(query: String) {
        guard let (ti, ai) = openConversationIndices(),
              var conversation = threads[ti].activities[ai].conversation else { return }
        conversation.messages.append(Message(role: .user, text: query))
        var thread = threads[ti]
        thread.activities[ai].conversation = conversation
        thread.messages.append(Message(role: .user, text: query))
        threads[ti] = thread
        streamingActivityID = threads[ti].activities[ai].id
        withAnimation(Theme.springMorph) {
            streamingTurn = StreamingTurn()
        }
        // Pin the fresh question to the top so the incoming answer is in focus.
        conversationScrollTarget = conversation.messages.count - 1
        conversationScrollToken += 1
    }

    /// After the answer resolves: hold the shim for a beat, reveal it word by
    /// word, then commit the finished turn into the conversation.
    private func streamPendingConversationTurn(routing: ComposerRoutingResult) {
        isLoading = false
        let answer = routing.answer
        let title = routing.title
        streamTask?.cancel()
        streamTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            guard !Task.isCancelled, streamingTurn != nil else { return }
            streamingTurn?.fullText = answer
            withAnimation(.easeOut(duration: 0.2)) { streamingTurn?.thinking = false }

            // Parse the Markdown once, then reveal by growing attributed prefix at
            // each word boundary — bold phrases render correctly as they arrive
            // instead of flashing their `**` markers mid-stream.
            let full = (try? AttributedString(
                markdown: answer,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )) ?? AttributedString(answer)
            let plain = Array(full.characters)
            // Character offsets to stop at: end of each whitespace-delimited word.
            var stops: [Int] = []
            for (i, ch) in plain.enumerated() where ch == " " { stops.append(i + 1) }
            if stops.last != plain.count { stops.append(plain.count) }
            for stop in stops {
                guard !Task.isCancelled, streamingTurn != nil else { return }
                let end = full.index(full.startIndex, offsetByCharacters: stop)
                streamingTurn?.revealed = AttributedString(full[full.startIndex..<end])
                try? await Task.sleep(for: .milliseconds(28))
            }
            guard !Task.isCancelled else { return }
            commitPendingConversationTurn(answer: answer, title: title)
        }
    }

    /// Fold the streamed answer into the conversation it belongs to (located by
    /// `streamingActivityID`, so it lands correctly even after navigation).
    private func commitPendingConversationTurn(answer: String, title: String) {
        defer { clearStreamingTurn() }
        guard let activityID = streamingActivityID,
              let ti = threads.firstIndex(where: { $0.activities.contains { $0.id == activityID } }),
              let ai = threads[ti].activities.firstIndex(where: { $0.id == activityID }),
              var conversation = threads[ti].activities[ai].conversation else { return }
        conversation.messages.append(Message(role: .assistant, text: answer))
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            conversation.title = title
        }
        var thread = threads[ti]
        thread.activities[ai].conversation = conversation
        thread.activities[ai].subtitle = conversation.title
        thread.messages.append(Message(role: .assistant, text: answer))
        threads[ti] = thread
        // Re-pin the question now the full answer gives room to scroll it up.
        conversationScrollToken += 1
    }

    /// Undo the optimistic turn when routing failed or sent us elsewhere.
    private func cancelPendingConversationTurn() {
        streamTask?.cancel()
        if let activityID = streamingActivityID,
           let ti = threads.firstIndex(where: { $0.activities.contains { $0.id == activityID } }),
           let ai = threads[ti].activities.firstIndex(where: { $0.id == activityID }),
           var conversation = threads[ti].activities[ai].conversation,
           conversation.messages.last?.role == .user {
            conversation.messages.removeLast()
            var thread = threads[ti]
            if thread.messages.last?.role == .user { thread.messages.removeLast() }
            thread.activities[ai].conversation = conversation
            threads[ti] = thread
        }
        clearStreamingTurn()
    }

    private func clearStreamingTurn() {
        streamTask = nil
        streamingTurn = nil
        streamingActivityID = nil
    }

    func dismissInlineAnswer() {
        withAnimation(Theme.springMorph) { inlineAnswerDraft = nil }
    }

    private func conversationTitle(_ title: String, fallback query: String) -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty { return cleaned }
        return query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[?.!]+$"#, with: "", options: .regularExpression)
            .split(separator: " ")
            .prefix(6)
            .joined(separator: " ")
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
        freshConversationID = nil
        selectedMexicoDestinationID = nil
        mexicoPackageFly = false
        mexicoPackagePinsIn = false
        canvasContentScrolled = false
        reveal = Self.stageResults
    }

    /// The nav-header back button: pop one screen off the back stack — a previous
    /// canvas or the trip overview — or, when the stack is empty, fall through to
    /// the homepage. Works from either a mounted canvas or the trip overview.
    func navigateBack() {
        guard let previous = navStack.popLast() else {
            if revealingThreadID != nil { dismissCanvasToHome() } else { goHome() }
            return
        }
        switch previous {
        case .canvas(let loc):
            if let aid = loc.activityID {
                openActivity(aid, in: loc.threadID, record: false)
            } else {
                open(loc.threadID, record: false)
            }
        case .tripOverview:
            collapseToTripOverview()
        }
    }

    /// Collapse the current canvas down to the trip-overview (journeys) screen —
    /// the curtain slides to the trip stage, then the layers tear down. Recording
    /// the outgoing canvas is the caller's job (see `showTripOverview`).
    func collapseToTripOverview() {
        // Hand the fresh conversation back to the CurtainSheet so it collapses to
        // its trip row with the normal canvas morph (the overlay is a fixed
        // full-screen surface and can't do the collapse). Inside the animation so
        // the overlay cross-fades out as the sheet collapses.
        withAnimation(Theme.springMorph) {
            freshConversationID = nil
            reveal = Self.stageTrip
        } completion: { self.teardown() }
    }

    /// The nav header's history button: record the current canvas, then collapse
    /// to the trip overview so back returns here.
    func showTripOverview() {
        recordStep(before: .tripOverview)
        collapseToTripOverview()
    }

    /// Back out all the way to the homepage (EmptySearchView) over the trip.
    func goHome() {
        navStack.removeAll()
        teardown()
        showHome = true
    }

    /// Dismiss a canvas straight down to the homepage. Home becomes the L0
    /// parent behind the curtain immediately, the curtain slides off the bottom,
    /// then the layers tear down — so the trip overview never flashes.
    func dismissCanvasToHome() {
        navStack.removeAll()
        showHome = true
        // Hand a fresh conversation back to the curtain so it slides off with the
        // canvas rather than hanging as a fixed overlay while home comes in.
        withAnimation(Theme.springMorph) {
            freshConversationID = nil
            canvasDismissing = true
        } completion: {
                self.teardown()
                self.canvasDismissing = false
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
        // History was already recorded in `beginSearchLaunch` (openThreadID is
        // nil'd above), so the expand itself must not push again.
        if let newActivityID {
            openActivity(newActivityID, in: newThreadID, record: false)
        } else {
            open(newThreadID, record: false)
        }

        // Let the freshly mounted curtain warm its layout before it moves.
        try? await Task.sleep(for: .seconds(0.05))

        if launchFromCurrent {
            // Stage 2b — spawn the new card just beneath and push-swap it in.
            await animateLaunch(to: Self.launchSwapEnd, animation: Theme.springMorphCardSwap)
            try? await Task.sleep(for: .seconds(Self.launchSwapToExpandBeat))
        }

        // Stage 3 — expand the new canvas out to full screen.
        await animateLaunch(to: 1)
        clearLaunch()
    }

    /// Spring the single `launch` driver to `target`, returning only once the
    /// spring has settled — so the next stage starts from rest (a clean beat).
    private func animateLaunch(to target: CGFloat, animation: Animation? = nil) async {
        let animation = animation ?? Theme.springMorph
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

    /// Cinematic hand-off from a Mexico destination card to its packages page, in
    /// three sequenced beats:
    ///  • Beat 1 (~1.0s): the persistent map flies from the Mexico orientation into
    ///    a full-screen Cancun framing (`mapFly` curve) and the orientation pins
    ///    fade out. The carousel fades and the sheet stays off-screen — "just the
    ///    map." The refine fires now (real pins need the packages thread) but runs
    ///    detached so the ~2s load floor doesn't gate the beat timing; the pins
    ///    mount hidden.
    ///  • Beat 1.5 (after the fly settles): `mexicoPackagePinsIn` flips true and the
    ///    Cancun package pins stagger in (fade / blur / scale).
    ///  • Beat 2 (after a longer pause): `mexicoPackageFly` clears — the sheet slides
    ///    up to the medium detent, the map pans up (pins ride higher), and the dock
    ///    pill morphs into "Cancun at a glance".
    func openPackages(_ card: Card) async {
        // Packages land at the medium detent; clear any collapsed (small-detent)
        // framing the orientation was left in so the fly uses the resting region.
        mexicoMapCollapsed = false
        mexicoPackagePinsIn = false
        withAnimation(Theme.mapFly) { mexicoPackageFly = true }        // beat 1
        Task { await send(card.displayTitle, refine: true, usesActionDetection: false) }
        try? await Task.sleep(for: .milliseconds(1000))               // let the fly settle
        mexicoPackagePinsIn = true                                     // beat 1.5
        try? await Task.sleep(for: .milliseconds(950))                // hold before beat 2
        selectedMexicoDestinationID = nil
        mexicoPackageFly = false                                       // beat 2
    }

    // MARK: - message flow (port of AppV1.sendMessage)

    /// Every free-text input creates a NEW card (thread) in the trip overview.
    /// Only manual manipulation via chips (`refine: true`) overrides the open
    /// card in place.
    func send(
        _ raw: String,
        refine: Bool = false,
        intentEvents: [ContinuationEvent] = [],
        actionOverride: ActivityType? = nil,
        usesActionDetection: Bool = true
    ) async {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }
        dataSourceErrorMessage = nil

        let action = actionOverride ?? (usesActionDetection ? Mock.detectAction(text) : nil)
        // Navigation policy is source-agnostic: only an explicit in-canvas UI
        // control may mutate the open entry. Composer text always branches.
        let inThread = refine && openThread != nil
        let targetID: String? = inThread ? openThreadID : nil
        let snapshot = targetID.flatMap { thread($0) }
        let narrativeContext = openThread

        appendMessage(Message(role: .user, text: text), toThread: targetID)
        isLoading = true
        let loadStart = Date()

        // The new card the launch swap expands into (free-text branch only).
        var launchThreadID: String?
        var launchActivityID: String?

        let resp: AssistantResponse
        do {
            resp = try await assistant(
                node: snapshot,
                narrativeContext: narrativeContext,
                text: text,
                intentEvents: intentEvents
            )
        } catch {
            failDataSource(
                (error as? LocalizedError)?.errorDescription
                    ?? "The selected data sources are unavailable."
            )
            return
        }
        let reply = resp.reply
        let threadPayload = resp.thread
        let prebuilt = resp.prebuiltThread

        if inThread, let id = targetID, let idx = threads.firstIndex(where: { $0.id == id }) {
            // Chip / manual refinement — override the existing card.
            var node = threads[idx]
            switch action {
            case .compare:
                let comp = Mock.buildComparison(from: node)
                node = Mock.appendActivity(node, type: .compare, subtitle: comp.versusTitle, comparison: comp)
            case .map:
                node = Mock.appendActivity(node, type: .map, subtitle: threadPayload?.label ?? cap(text))
            case .conversation:
                break
            case nil:
                if let payload = threadPayload { node = Mock.applyRefinement(node, payload) }
            }
            node.messages.append(Message(role: .assistant, text: reply))
            threads[idx] = node
            if action == .compare, let newAct = node.activities.last {
                openActivity(newAct.id, in: id)
            }
        } else {
            // A root search must be backed by one of the explicitly selected
            // sources. Never synthesize a generic card across source boundaries.
            guard var item = prebuilt ?? threadPayload.map({ Mock.buildThreadNode($0) }) else {
                failDataSource("The selected data sources have no results for this search.")
                return
            }
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

    /// Applies a server-authored clarification/refinement to the open Gen-UI
    /// thread. Free-text questions route into the existing composer.
    func submit(_ action: RefinementAction) async {
        if action.kind == .openComposer {
            openComposer()
            return
        }
        let events = continuationEvents(for: action)
        let query = action.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            openComposer()
            return
        }
        await send(query, refine: true, intentEvents: events)
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
        let narrativeQueries: [String: String] = [
            "mexico-orientation": "Mexico spring break beach trip with teens under $5000",
            "mexico-packages": "Mexico Cancun hotel package",
            "mexico-refined": "Cancun beachfront two bedroom suite with seats together",
            "mexico-hyatt": "Hyatt Ziva Cancun family room",
            "mexico-flights": "Nonstop flights from Houston to Cancun with seats together",
            "mexico-activities": "Teen-friendly snorkeling activities in Cancun",
        ]
        if let query = narrativeQueries[level],
           let payload = NarrativeData.resolve(current: nil, text: query)?.response.thread {
            let item = Mock.buildThreadNode(payload)
            threads = [item]
            Task { @MainActor in
                await Task.yield()
                revealingThreadID = item.id
                openThreadID = item.id
                reveal = Self.stageResults
            }
            return
        }

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

    private func assistant(
        node: ThreadNode?,
        narrativeContext: ThreadNode?,
        text: String,
        intentEvents: [ContinuationEvent]
    ) async throws -> AssistantResponse {
        switch assistantSourceMode {
        case .narrativeMock:
            // Authored queries unlock exact golden-path pages. Everything else
            // stays local and deterministic through baked or generic mock data.
            if let resolution = NarrativeData.resolve(current: narrativeContext, text: text) {
                return resolution.response
            }
            if node == nil, let baked = DestinationData.response(text: text) {
                return baked
            }
            let fallback = Mock.generateResponse(node: node, text: text)
            guard fallback.thread != nil || fallback.prebuiltThread != nil else {
                throw DataSourceError.narrativeMockUnavailable
            }
            return fallback

        case .genUI:
            return try await genUIDataSource.response(
                for: text,
                continuation: node?.continuation,
                intentEvents: intentEvents
            )
        }
    }

    private func continuationEvents(for action: RefinementAction) -> [ContinuationEvent] {
        guard action.kind == .selection, let value = action.value else { return [] }
        let values: [(String, JSONValue)]
        if case .object(let object) = value,
           object.keys.contains(where: { $0 == "departureDate" || $0 == "returnDate" }) {
            values = object.keys.sorted().compactMap { key in object[key].map { (key, $0) } }
        } else if let field = action.field {
            values = [(field, value)]
        } else {
            values = []
        }
        let timestamp = Date().timeIntervalSince1970 * 1_000
        return values.map { field, value in
            ContinuationEvent(
                id: UUID().uuidString,
                type: "ui-selection",
                timestamp: timestamp,
                field: field,
                newValue: value,
                strength: "hard",
                source: "user",
                rawInput: action.query,
                provenance: "native-clarification"
            )
        }
    }

    private func appendMessage(_ m: Message, toThread id: String?) {
        if let id, let idx = threads.firstIndex(where: { $0.id == id }) {
            threads[idx].messages.append(m)
        } else {
            tripMessages.append(m)
        }
    }

    private func failDataSource(_ message: String) {
        dataSourceErrorMessage = message
        isLoading = false
        homeSubmitLoading = false
        if launching {
            deliverLaunchThread(threadID: nil, activityID: nil)
        }
    }

    private func cap(_ s: String) -> String {
        guard let first = s.first else { return s }
        return first.uppercased() + s.dropFirst()
    }
}
