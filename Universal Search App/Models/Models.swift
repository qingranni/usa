//
//  Models.swift
//  Universal Search App
//
//  Typed value model mirroring the React node graph (data.js). The standalone
//  prototype has a single trip whose ordered children are "threads"; each
//  thread owns result sets (one per refinement; the latest is shown), activity
//  entries (compare/map), and a message log (used only for AI context).
//

import Foundation

// MARK: - Kind

enum Kind: String, Hashable {
    case lodging, flights, cars, activities, other

    /// Material icon name (mapped to an SF Symbol via IconMap). Mirrors KIND_ICON.
    var icon: String {
        switch self {
        case .flights: return "flight"
        case .lodging: return "hotel"
        case .cars: return "directions_car"
        case .activities: return "local_activity"
        case .other: return "place"
        }
    }
}

/// The producer responsible for the result content and its layout policy.
enum ResultSource: String, Hashable {
    case narrative, mock, genUI
}

/// Top-level renderer selected by the producer. `blocks` preserves the ordered
/// result grammar; specialized renderers are explicit rather than inferred from
/// the resource kind.
enum ResultComposition: String, Hashable {
    case blocks
    case packageShelves
    case flightList
}

/// Visual treatment for cards inside a list or carousel. Placement remains the
/// responsibility of `ResultBlock.Style`.
enum ResultCardPresentation: String, Hashable {
    case automatic
    case destinationHero
    case destinationCarousel
    case lodging
    case flight
    case generic
}

/// Producer-selected map composition. Most result maps use the standard detent
/// sheet; destinationCarousel is the full-map inspiration treatment with
/// floating destination cards.
enum ResultsMapLayout: String, Hashable {
    case standard
    case destinationCarousel
}

/// Producer-selected canvas chrome. The default layout remains shared across
/// data sources; authored scenarios opt into a focused visual treatment.
enum ResultsCanvasLayout: String, Hashable {
    case standard
    case mexicoOrientation
}

// MARK: - Leaf types

/// One option as produced by the mock factories or the AI payload.
struct Option: Hashable {
    var title: String
    var detail: String = ""
    var price: String? = nil
    /// Explicit card image (bundled asset name or remote URL). When set, the
    /// thread builder uses it verbatim instead of scoring the ImageLibrary.
    var imageURL: String? = nil
    /// Numeric nightly/ticket price used for lightweight budget filtering.
    var priceValue: Int? = nil
    // Flight-specific fields (nil for other kinds).
    var departTime: String? = nil
    var arriveTime: String? = nil
    var stops: String? = nil        // "Nonstop", "1 stop"…
    var duration: String? = nil     // "6h 25m"
    var cabin: String? = nil        // "Economy", "Business, Economy"
    var tripType: String? = nil     // "Round trip", "One-way"
    var airlines: [String] = []     // ["Lufthansa", "SAS"]
    /// Badge overlays (airline logos) — supports connecting-carrier pairs.
    var logoURLs: [String] = []
    /// Free-form highlights slot (refundable/cancellation, property attributes,
    /// or AI-generated copy). Stubbed for now; one slot reserved on the card.
    var highlights: String? = nil
    // Lodging-specific rating fields (nil for other kinds).
    var rating: Double? = nil       // guest score on a 0–10 scale, e.g. 9.2
    var reviewCount: Int? = nil     // number of reviews backing the score
    var city: String? = nil         // resolved property city, e.g. "Cancún"
    /// Stay total (nightly × nights), shown as the primary price on lodging cards.
    var totalPrice: String? = nil
    // Package-specific merchandising fields.
    var dateRange: String? = nil
    var crossedOutPrice: String? = nil
    var discountText: String? = nil
    var nights: Int? = nil
    var travelers: Int? = nil
    // Flight merchandising extras.
    var aircraft: String? = nil     // "Boeing 777"
    var flightNumber: String? = nil // "UA 507"
}

/// A single canvas/result card.
struct Card: Identifiable, Hashable {
    let id: String
    var title: String?
    var price: String?
    var sublabel: String
    /// Material icon name, used only when `imageURL` is nil.
    var icon: String?
    /// Either an "http…" remote URL or a local path like "/v1/hotel-1.jpg".
    var imageURL: String?
    /// Badge overlays (airline logo asset names or remote URLs) — up to two.
    var logoURLs: [String] = []
    // Flight-specific fields (nil for other kinds).
    var departTime: String? = nil
    var arriveTime: String? = nil
    var stops: String? = nil
    var duration: String? = nil
    var cabin: String? = nil
    var tripType: String? = nil
    var airlines: [String] = []
    /// Free-form highlights slot (refundable/cancellation, attributes, AI copy).
    var highlights: String? = nil
    // Lodging-specific rating fields (nil for other kinds).
    var rating: Double? = nil       // guest score on a 0–10 scale, e.g. 9.2
    var reviewCount: Int? = nil     // number of reviews backing the score
    var city: String? = nil         // resolved property city, e.g. "Cancún"
    /// Stay total (nightly × nights), shown as the primary price on lodging cards.
    var totalPrice: String? = nil
    // Package-specific merchandising fields.
    var dateRange: String? = nil
    var crossedOutPrice: String? = nil
    var discountText: String? = nil
    var nights: Int? = nil
    var travelers: Int? = nil
    // Flight merchandising extras.
    var aircraft: String? = nil     // "Boeing 777"
    var flightNumber: String? = nil // "UA 507"
    /// Stable shared-element identity for morphs.
    var layoutId: String

    /// The bold guest score, formatted for the rating line (e.g. "9.2", "10").
    var ratingScoreText: String? {
        guard let r = rating else { return nil }
        return r >= 10 ? "10" : String(format: "%.1f", r)
    }

    /// The trailing detail after the score, e.g. " (994) · Cancún".
    var ratingDetailText: String {
        var parts: [String] = []
        if let c = reviewCount { parts.append("(\(c))") }
        if let city, !city.isEmpty { parts.append(city) }
        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: " · ")
    }
}

/// One hydrated UI block in a result view — the server-driven layout the LLM
/// (or the mock) composes: an intro paragraph, a section heading, a stack of
/// hero cards, or a horizontal carousel.
struct ResultBlock: Identifiable, Hashable {
    enum Style: String, Hashable { case text, heading, highlight, cards, carousel }
    let id: String
    var style: Style
    var text: String = ""     // body (text) / heading / carousel title
    var cards: [Card] = []    // for .cards and .carousel
    var cardPresentation: ResultCardPresentation = .automatic
    /// Original server semantic component, retained so native presentation can
    /// specialize without flattening the contract into generic text/cards.
    var semanticType: String? = nil
    var semanticProps: [String: JSONValue] = [:]
}

/// One stack of results (a refinement snapshot).
struct ResultSet: Identifiable, Hashable {
    let id: String
    var title: String
    var summary: String
    var label: String
    var options: [Option]
    var cards: [Card]
    /// Ordered UI blocks for the results canvas (empty ⇒ fall back to `cards`).
    var blocks: [ResultBlock] = []
}

enum ActivityType: String, Hashable { case compare, map, conversation }

/// One row of a side-by-side comparison.
struct CompareHighlight: Hashable, Identifiable {
    var label: String
    var a: String
    var b: String
    var id: String { label }
}

/// A group of comparison rows (Price, Location, Amenities, Rooms) — the unit a
/// "Compare on" chip toggles.
struct CompareCategory: Hashable, Identifiable {
    var name: String
    var rows: [CompareHighlight]
    var id: String { name }
}

/// A two-option comparison (built from a thread's current cards).
struct Comparison: Hashable {
    var titleA: String
    var titleB: String
    var imageA: String?
    var imageB: String?
    var priceA: String?
    var priceB: String?
    var categories: [CompareCategory]

    var images: [String] { [imageA, imageB].compactMap { $0 } }
    var versusTitle: String { "\(titleA) vs \(titleB)" }
}

/// A sub-action taken inside a thread (comparison, map, or conversation).
struct Activity: Identifiable, Hashable {
    let id: String
    var type: ActivityType
    var subtitle: String
    var comparison: Comparison? = nil
    var conversation: Conversation? = nil
}

/// How a thread appears in its parent (header glyph / hero image / intro line).
struct Preview: Hashable {
    var icon: String?
    var imageURL: String?
    var sublabel: String
    var message: String
    var layoutId: String
}

struct Message: Hashable, Sendable {
    enum Role: String, Sendable { case user, assistant }
    var role: Role
    var text: String
}

enum ComposerRoute: String, Hashable, Sendable {
    case question
    case continueConversation
    case newSearch
    case refine
    case compare
    case map
}

enum ComposerSurface: String, Hashable, Sendable {
    case home
    case results
    case inlineAnswer
    case conversation
}

struct ComposerContext: Hashable, Sendable {
    var surface: ComposerSurface
    var threadID: String?
    var title: String?
    var summary: String?
    var filters: [String] = []
    var results: [String] = []
    var messages: [Message] = []
}

struct ComposerRoutingResult: Hashable, Sendable {
    var route: ComposerRoute
    var title: String = ""
    var answer: String = ""
}

struct Conversation: Hashable {
    var title: String
    var messages: [Message]
}

/// An assistant turn mid-arrival: a "thinking" shim while the answer resolves,
/// then the text revealed word by word before it commits into the conversation.
struct StreamingTurn: Equatable {
    var fullText: String = ""
    /// The portion revealed so far, kept as an `AttributedString` so Markdown
    /// bold renders progressively as words arrive — revealing raw text and
    /// letting SwiftUI re-parse `**…**` per tick makes the asterisks flash in
    /// then vanish on each bolded phrase.
    var revealed: AttributedString = AttributedString("")
    var thinking: Bool = true
}

struct InlineAnswerDraft: Identifiable, Hashable {
    let id: String
    var originThreadID: String
    var conversation: Conversation
}

/// Source-resolved canvas presentation. Views consume this contract instead of
/// inferring layout from product names, titles, or card contents.
struct ResultsPresentation: Hashable {
    var showsMap: Bool = true
    var showsFilters: Bool = true
    var overlaySheet: Bool = true
    var mapLayout: ResultsMapLayout = .standard
    var canvasLayout: ResultsCanvasLayout = .standard
    var filters: [String] = []
    var refinements: [RefinementAction] = []
    var map: ServerMapPresentation? = nil
}

/// Server continuation data retained on the thread that produced it. This is
/// transport state only; decision policy remains owned by the backend.
struct SearchContinuation: Hashable {
    var sessionId: String?
    var intentEvents: [ContinuationEvent] = []
    var querySummary: String?
}

struct ContinuationEvent: Hashable {
    var id: String
    var type: String
    var timestamp: Double
    var field: String?
    var previousValue: JSONValue?
    var newValue: JSONValue?
    var strength: String?
    var source: String
    var confidence: Double?
    var rawInput: String?
    var provenance: String?
}

enum RefinementActionKind: String, Hashable {
    case selection
    case query
    case openComposer
}

/// A backend-provided confirmation, suggestion, or refinement affordance.
struct RefinementAction: Identifiable, Hashable {
    var id: String
    var label: String
    var field: String?
    var value: JSONValue?
    var query: String
    var kind: RefinementActionKind
    var required: Bool = false
}

struct DecisionPresentation: Hashable {
    var completeness: String?
    var stage: String?
    var register: String?
    var actions: [String] = []
    var disambiguationLevel: String?
    var templateKind: String?
    var mapPolicy: String?
    var compositionRecipe: String?
    var compositionTone: String?
    var guidanceIntensity: String?
    var suggestionDensity: Double?
    var foregroundAttributes: [String] = []
    var promptPlacement: String?
}

struct ServerMapPin: Identifiable, Hashable {
    var id: String
    var latitude: Double
    var longitude: Double
    var label: String
}

struct ServerMapPresentation: Hashable {
    var pins: [ServerMapPin]
    var centerLatitude: Double?
    var centerLongitude: Double?
    var zoom: Double?
}

// MARK: - Thread node

struct ThreadNode: Identifiable, Hashable {
    let id: String
    var kind: Kind
    var title: String
    var generated: Bool = true
    var source: ResultSource = .mock
    var composition: ResultComposition = .blocks
    /// Optional deterministic scenario provenance used to resolve authored
    /// follow-up content. Entry creation versus mutation remains AppStore policy.
    var scenarioID: String? = nil
    var scenarioStep: String? = nil
    var presentation: ResultsPresentation = ResultsPresentation()
    var continuation: SearchContinuation? = nil
    var decision: DecisionPresentation? = nil
    var preview: Preview
    var resultSets: [ResultSet] = []
    var activities: [Activity] = []
    var messages: [Message] = []
    var resultsLabel: String? = nil
    /// Home questions have no Results entry; their sole trip entry is chat.
    var conversationOnly = false

    /// Latest result set's cards (data.js `activeCards`).
    var activeCards: [Card] { resultSets.last?.cards ?? [] }
    /// Latest result set's server-driven UI blocks (empty ⇒ render `activeCards`).
    var activeBlocks: [ResultBlock] { resultSets.last?.blocks ?? [] }
    /// Semantic status/guidance/clarification blocks that must remain visible
    /// when a specialized card renderer owns the rest of the layout.
    var specializedSemanticBlocks: [ResultBlock] {
        activeBlocks.filter { $0.semanticType != nil }
    }

    /// The primary hero cards actually rendered at the top of the results — the
    /// first `.cards` block (falling back to the flat card list). These are the
    /// cards whose frames the reverse-fan morph measures, so the fan assets are
    /// derived from the same source to keep the flying elements in sync.
    var heroCards: [Card] {
        activeBlocks.first { $0.style == .cards }?.cards ?? activeCards
    }

    /// Assets shown in the trip card's thumbnail fan: hero photos for image
    /// kinds, airline logos for flights (their cards carry logos, not photos).
    var fanAssets: [String] {
        if fanIsLogo {
            return Array((heroCards.first?.logoURLs ?? []).prefix(2))
        }
        return Array(heroCards.prefix(2).compactMap { $0.imageURL })
    }
    /// Whether `fanAssets` are logo chips (flights) rather than full-bleed photos.
    var fanIsLogo: Bool { kind == .flights }
}

// MARK: - Assistant payloads (shared by the mock + AI paths)

/// Structured thread description returned by the AI, or by the mock on a
/// same-thread refinement.
struct ThreadPayload {
    var kind: Kind
    var title: String
    var summary: String
    var label: String
    var chip: String
    var options: [Option]
    var source: ResultSource = .mock
    var composition: ResultComposition = .blocks
    var scenarioID: String? = nil
    var scenarioStep: String? = nil
    var presentation: ResultsPresentation = ResultsPresentation()
    var continuation: SearchContinuation? = nil
    var decision: DecisionPresentation? = nil
    /// Server-driven UI blocks for the result view (empty ⇒ mock synthesizes a
    /// default layout from `options`).
    var blocks: [BlockSpec] = []
}

/// Pre-hydration UI block from the AI/mock — items are hydrated into `Card`s
/// (with images) by the thread builder.
struct BlockSpec {
    var style: ResultBlock.Style
    var text: String = ""
    var items: [Option] = []
    var cardPresentation: ResultCardPresentation = .automatic
    /// Per-section image domain (flights/lodging/activities…) so a mixed response
    /// picks fitting imagery per block. Falls back to the thread's kind.
    var kind: Kind? = nil
    var semanticType: String? = nil
    var semanticProps: [String: JSONValue] = [:]
}

/// Unified result of "ask the assistant" — mirrors the React `{ reply, thread }`
/// plus the mock root factory's prebuilt node (`newItem`).
struct AssistantResponse {
    var reply: String
    var thread: ThreadPayload? = nil
    var prebuiltThread: ThreadNode? = nil
}
