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
        let insertion = ["London", "Mexico"].contains(phrase)
            ? phrase
            : phrase.prefix(1).lowercased() + phrase.dropFirst()
        return base + " " + insertion
    }

    private static func defaultActions(
        for context: ComposerPredictionContext
    ) -> [ComposerPredictionAction] {
        var actions: [ComposerPredictionAction] = []
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
                    label: "Add people",
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
        let candidates: [String]

        if context.hasDestination || containsKnownDestination(in: normalized) {
            candidates = ["For next week", "Hotels"]
        } else if normalized.hasSuffix(" in") || normalized.hasSuffix(" to") {
            candidates = ["London", "Mexico"]
        } else if normalized.hasSuffix("spring") {
            candidates = ["Break", "Vacation"]
        } else if normalized.contains("spring break") {
            candidates = ["Beach vacation", "For next week"]
        } else if normalized.containsAny(of: ["hotel", "hotels", "stay", "lodging"]) {
            candidates = ["For next week", "Near city center"]
        } else if normalized.containsAny(of: ["beach", "coast", "ocean", "resort"]) {
            candidates = ["Hotels", "All-inclusive"]
        } else if normalized.containsAny(of: ["family", "kids", "children"]) {
            candidates = ["Trip", "For 4 people"]
        } else if normalized.containsAny(of: ["ski", "snow", "mountain"]) {
            candidates = ["Hotels", "Next weekend"]
        } else if normalized.contains("spa") {
            candidates = ["Hotels", "For the weekend"]
        } else if normalized.containsAny(of: ["trip", "vacation", "getaway", "holiday"]) {
            candidates = ["To Mexico", "For next week"]
        } else {
            candidates = ["Hotels", "For next week"]
        }

        return candidates
            .filter { candidate in
                let normalizedCandidate = SearchInputParser.normalize(candidate)
                if normalized.contains(normalizedCandidate) { return false }
                if context.hasDates && isDatePhrase(normalizedCandidate) { return false }
                if context.hasGuests && isGuestPhrase(normalizedCandidate) { return false }
                return true
            }
            .prefix(2)
            .enumerated()
            .map { index, candidate in
                ComposerPredictionAction(
                    slot: index,
                    label: candidate,
                    kind: .append(candidate)
                )
            }
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
