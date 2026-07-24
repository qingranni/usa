import Foundation

struct ComposerPredictionContext {
    let text: String
    let hasDestination: Bool
    let hasDates: Bool
    let hasGuests: Bool
    let hasStructuredMatches: Bool
}

struct ComposerPredictionAction: Identifiable, Equatable {
    enum Kind: Equatable {
        case filter(String)
        case append(String)
    }

    let slot: Int
    let label: String
    let kind: Kind

    var id: Int { slot }
}

enum ComposerPredictionState: Equatable {
    case defaults([ComposerPredictionAction])
    case nextWords([ComposerPredictionAction])
    case confirmations

    var actions: [ComposerPredictionAction] {
        switch self {
        case .defaults(let actions), .nextWords(let actions):
            return actions
        case .confirmations:
            return []
        }
    }
}

enum ComposerPredictionEngine {
    /// Continuation phrases that are proper nouns and must keep their capital
    /// when appended mid-sentence (everything else is lowercased to read as a
    /// natural continuation, e.g. "beach vacation").
    private static let properNounContinuations: Set<String> = [
        "London", "Tokyo", "Bali", "Mexico", "Paris", "Rome", "Lisbon", "Barcelona",
        "Caribbean", "Orlando", "San Diego", "Miami", "Cancun", "Maldives",
        "Aspen", "Whistler", "Banff", "Santorini",
    ]

    static func state(for context: ComposerPredictionContext) -> ComposerPredictionState {
        if context.hasStructuredMatches {
            return .confirmations
        }

        let query = context.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.count < 3 && !context.hasDestination && !context.hasDates && !context.hasGuests {
            return .defaults(defaultActions(for: context))
        }

        let nextWords = nextWordActions(for: query, context: context)
        if !nextWords.isEmpty {
            return .nextWords(nextWords)
        }
        return .defaults(defaultActions(for: context))
    }

    static func applying(_ action: ComposerPredictionAction, to text: String) -> String {
        guard case .append(let phrase) = action.kind else { return text }
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return phrase }
        let insertion = properNounContinuations.contains(phrase)
            ? phrase
            : phrase.prefix(1).lowercased() + phrase.dropFirst()
        return base + " " + insertion
    }

    private static func defaultActions(
        for context: ComposerPredictionContext
    ) -> [ComposerPredictionAction] {
        var actions: [ComposerPredictionAction] = []
        if !context.hasDestination {
            actions.append(
                ComposerPredictionAction(
                    slot: actions.count,
                    label: "Add destination",
                    kind: .filter("Destination")
                )
            )
        }
        if !context.hasDates {
            actions.append(
                ComposerPredictionAction(
                    slot: actions.count,
                    label: "Add dates",
                    kind: .filter("Dates")
                )
            )
        }
        if !context.hasGuests {
            actions.append(
                ComposerPredictionAction(
                    slot: actions.count,
                    label: "Add travelers",
                    kind: .filter("Guests")
                )
            )
        }
        return actions
    }

    private static func nextWordActions(
        for query: String,
        context: ComposerPredictionContext
    ) -> [ComposerPredictionAction] {
        let normalized = SearchInputParser.normalize(query)
        let hasDestination = context.hasDestination || containsKnownDestination(in: normalized)
        let endsWithConnector = normalized.hasSuffix(" in") || normalized.hasSuffix(" to")

        var candidates: [String]
        if endsWithConnector && !hasDestination {
            // Mid-phrase right after "to"/"in" with no place chosen yet — the
            // next word is a *destination*. Bias the picks to the intent.
            candidates = destinationSuggestions(forIntent: normalized)
        } else {
            // Otherwise, natural next words for the detected intent. Each set is
            // ordered to read as continuing the sentence early on ("family" →
            // "trip to") and shift to concrete details once the earlier phrases
            // are typed (the filter below drops whatever's already in the text).
            candidates = topicContinuations(for: normalized)
            if candidates.isEmpty {
                candidates = hasDestination
                    ? ["For a week", "For 2 guests", "With a pool"]
                    : ["Somewhere warm", "For a week", "On a budget"]
            }
        }

        var seen = Set<String>()
        return candidates
            .filter { candidate in
                let normalizedCandidate = SearchInputParser.normalize(candidate)
                if normalized.contains(normalizedCandidate) { return false }
                if context.hasDates && isDatePhrase(normalizedCandidate) { return false }
                if context.hasGuests && isGuestPhrase(normalizedCandidate) { return false }
                if seen.contains(candidate) { return false }
                seen.insert(candidate)
                return true
            }
            .prefix(3)
            .enumerated()
            .map { index, candidate in
                ComposerPredictionAction(
                    slot: index,
                    label: candidate,
                    kind: .append(candidate)
                )
            }
    }

    /// Intent-driven next words. First match wins (branches ordered most-specific
    /// first). Each set is ordered so the *first* item reads as continuing the
    /// sentence ("family" → "trip to") and the rest are concrete details; as the
    /// user types, the caller's filter drops whatever's already present, so the
    /// row naturally advances from phrase-completion to refinement.
    private static func topicContinuations(for normalized: String) -> [String] {
        if normalized.contains("spring break") {
            return ["Getaway", "On the beach", "All-inclusive", "Somewhere warm"]
        }
        if normalized.hasSuffix("spring") {
            return ["Break", "Getaway", "In Europe"]
        }
        if normalized.containsAny(of: ["honeymoon", "romantic", "anniversary", "couples"]) {
            return ["Getaway", "Adults-only", "With a private pool", "Ocean view"]
        }
        if normalized.containsAny(of: ["family", "kids", "children", "toddler"]) {
            return ["Trip to", "For a week", "With the kids", "With a pool"]
        }
        if normalized.containsAny(of: ["ski", "snow", "slopes", "snowboard", "mountain"]) {
            return ["Trip to", "For a long weekend", "Ski-in ski-out", "With a hot tub"]
        }
        if normalized.containsAny(of: ["beach", "coast", "ocean", "island", "seaside", "resort"]) {
            return ["Vacation", "All-inclusive", "Beachfront", "For a week"]
        }
        if normalized.containsAny(of: ["luxury", "5 star", "five star", "fancy", "upscale"]) {
            return ["Escape", "5-star only", "With a spa", "A suite"]
        }
        if normalized.containsAny(of: ["budget", "cheap", "affordable", "deal", "deals"]) {
            return ["Getaway", "Under $150 a night", "Free cancellation", "Great deals"]
        }
        if normalized.containsAny(of: ["business", "work", "conference", "meeting"]) {
            return ["Trip to", "Near downtown", "With fast wifi", "Next week"]
        }
        if normalized.containsAny(of: ["foodie", "food", "restaurant", "culinary", "wine"]) {
            return ["Trip to", "In the old town", "Near great restaurants", "Breakfast included"]
        }
        if normalized.containsAny(of: ["nightlife", "party", "bars", "clubs"]) {
            return ["Getaway", "Walkable to bars", "A rooftop pool", "Downtown"]
        }
        if normalized.containsAny(of: ["nature", "hiking", "outdoors", "camping", "national park"]) {
            return ["Escape", "A cabin", "With mountain views", "Pet-friendly"]
        }
        if normalized.containsAny(of: ["road trip", "roadtrip", "drive"]) {
            return ["Along the coast", "With free parking", "Pet-friendly", "For a week"]
        }
        if normalized.containsAny(of: ["cruise", "sailing"]) {
            return ["In the Caribbean", "For 7 nights", "With a balcony", "All-inclusive"]
        }
        if normalized.containsAny(of: ["spa ", "wellness", "retreat"]) || normalized.hasSuffix("spa") {
            return ["Retreat", "For the weekend", "With hot springs", "Adults-only"]
        }
        if normalized.containsAny(of: ["weekend", "getaway", "city break", "quick trip"]) {
            return ["Getaway", "Somewhere close", "A boutique hotel", "Just 2 nights"]
        }
        if normalized.containsAny(of: ["hotel", "hotels", "stay", "lodging", "accommodation"]) {
            return ["In the city center", "With a pool", "Breakfast included", "Free cancellation"]
        }
        if normalized.containsAny(of: ["trip", "vacation", "holiday", "travel", "explore"]) {
            return ["Somewhere warm", "For a week", "On a budget", "With a pool"]
        }
        return []
    }

    /// Destinations to offer right after "to"/"in" when no place is chosen yet,
    /// biased to the detected intent so "family trip to …" suggests family spots
    /// rather than a generic city list.
    private static func destinationSuggestions(forIntent normalized: String) -> [String] {
        if normalized.containsAny(of: ["family", "kids", "children", "toddler"]) {
            return ["Orlando", "San Diego", "Miami"]
        }
        if normalized.containsAny(of: ["beach", "coast", "ocean", "island", "seaside"]) {
            return ["Cancun", "Maldives", "Bali"]
        }
        if normalized.containsAny(of: ["ski", "snow", "slopes", "snowboard", "mountain"]) {
            return ["Aspen", "Whistler", "Banff"]
        }
        if normalized.containsAny(of: ["honeymoon", "romantic", "anniversary", "couples"]) {
            return ["Bali", "Santorini", "Maldives"]
        }
        return ["London", "Tokyo", "Bali"]
    }

    private static func containsKnownDestination(in normalizedQuery: String) -> Bool {
        ChipComposerCatalog.destinationSuggestions.contains { suggestion in
            let names = suggestion.name.components(separatedBy: ",").map {
                SearchInputParser.normalize($0.trimmingCharacters(in: .whitespaces))
            }
            return names.contains { name in
                normalizedQuery == name || normalizedQuery.hasSuffix(" " + name)
            }
        }
    }

    private static func isDatePhrase(_ normalized: String) -> Bool {
        normalized.containsAny(of: [
            "today", "tomorrow", "week", "weekend", "month",
            "monday", "tuesday", "wednesday", "thursday", "friday",
            "saturday", "sunday",
        ])
    }

    private static func isGuestPhrase(_ normalized: String) -> Bool {
        normalized.containsAny(of: [
            "people", "person", "guest", "adult", "child", "kid",
        ])
    }
}

private extension String {
    func containsAny(of candidates: [String]) -> Bool {
        candidates.contains { contains($0) }
    }
}
