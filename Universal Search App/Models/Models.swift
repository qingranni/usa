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
    enum Style: String, Hashable { case text, heading, cards, carousel }
    let id: String
    var style: Style
    var text: String = ""     // body (text) / heading / carousel title
    var cards: [Card] = []    // for .cards and .carousel
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

enum ActivityType: String, Hashable { case compare, map }

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

/// A sub-action taken inside a thread (comparison or location/map question).
struct Activity: Identifiable, Hashable {
    let id: String
    var type: ActivityType
    var subtitle: String
    var comparison: Comparison? = nil
}

/// How a thread appears in its parent (header glyph / hero image / intro line).
struct Preview: Hashable {
    var icon: String?
    var imageURL: String?
    var sublabel: String
    var message: String
    var layoutId: String
}

struct Message: Hashable {
    enum Role: String { case user, assistant }
    var role: Role
    var text: String
}

// MARK: - Thread node

struct ThreadNode: Identifiable, Hashable {
    let id: String
    var kind: Kind
    var title: String
    var generated: Bool = true
    var preferences: [String] = []
    var preview: Preview
    var resultSets: [ResultSet] = []
    var activities: [Activity] = []
    var messages: [Message] = []
    var resultsLabel: String? = nil

    /// Latest result set's cards (data.js `activeCards`).
    var activeCards: [Card] { resultSets.last?.cards ?? [] }
    /// Latest result set's server-driven UI blocks (empty ⇒ render `activeCards`).
    var activeBlocks: [ResultBlock] { resultSets.last?.blocks ?? [] }

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
    /// Per-section image domain (flights/lodging/activities…) so a mixed response
    /// picks fitting imagery per block. Falls back to the thread's kind.
    var kind: Kind? = nil
}

/// Unified result of "ask the assistant" — mirrors the React `{ reply, thread }`
/// plus the mock root factory's prebuilt node (`newItem`).
struct AssistantResponse {
    var reply: String
    var thread: ThreadPayload? = nil
    var prebuiltThread: ThreadNode? = nil
}
