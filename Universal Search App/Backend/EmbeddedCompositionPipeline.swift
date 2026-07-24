import Foundation

struct SemanticRouteThresholds: Sendable {
    var itineraryMaximum = 0.45
    var resultsMinimum = 0.55
}

struct SemanticRouteScorer: Sendable {
    var thresholds = SemanticRouteThresholds()

    func score(intent: EmbeddedIntent) -> SearchRouteSpec {
        var value: Double
        switch intent.goal {
        case .explore: value = 0.18
        case .compare: value = 0.78
        case .find: value = 0.62
        }

        if intent.destinations.isEmpty { value -= 0.14 }
        if intent.relationship == "package" { value -= 0.08 }
        if intent.departureDate != nil { value += 0.08 }
        if intent.returnDate != nil { value += 0.05 }
        if intent.originAirport != nil { value += 0.04 }
        if intent.totalBudget != nil { value += 0.04 }
        if !intent.amenities.isEmpty || !intent.travelStyle.isEmpty { value += 0.03 }

        let bounded = min(1, max(0, value))
        let lean: SearchRouteLean
        if bounded <= thresholds.itineraryMaximum {
            lean = .itinerary
        } else if bounded >= thresholds.resultsMinimum {
            lean = .results
        } else {
            // Broad package searches sit near the midpoint and lean toward planning.
            lean = intent.goal == .explore || intent.relationship == "package" ? .itinerary : .results
        }
        return SearchRouteSpec(score: bounded, lean: lean)
    }
}

enum EmbeddedDataRequirementsResolver {
    static func resolve(intent: EmbeddedIntent, route: SearchRouteSpec) -> [DataRequirementSpec] {
        let needsFlight = intent.products.contains(.flight)
        let needsLodging = intent.products.contains(.lodging)
        return [
            .init(
                field: "destinations",
                level: route.lean == .results ? .required : .optional,
                isPresent: !intent.destinations.isEmpty,
                capturePrompt: intent.destinations.isEmpty ? "Add a destination to narrow these ideas" : nil
            ),
            .init(
                field: "departureDate",
                level: .optional,
                isPresent: intent.departureDate != nil,
                capturePrompt: intent.departureDate == nil ? "Add dates for live availability" : nil
            ),
            .init(
                field: "returnDate",
                level: .optional,
                isPresent: !needsLodging || intent.returnDate != nil,
                capturePrompt: needsLodging && intent.returnDate == nil ? "Add a return date for stay totals" : nil
            ),
            .init(
                field: "originAirport",
                level: .optional,
                isPresent: !needsFlight || intent.originAirport != nil,
                capturePrompt: needsFlight && intent.originAirport == nil ? "Add where you are leaving from for fares" : nil
            ),
            .init(
                field: "totalBudget",
                level: .optional,
                isPresent: intent.totalBudget != nil,
                capturePrompt: intent.totalBudget == nil ? "Set a budget to improve the ranking" : nil
            ),
        ]
    }
}

struct PageConstructRegistry: Sendable {
    func construct(route: SearchRouteSpec, trace: EmbeddedDecisionTrace) -> PageConstructSpec {
        let loadMap = trace.template.map == "results"
            && trace.composition.recipe != "flight"
            && trace.composition.recipe != "clarification"
        if route.lean == .itinerary || loadMap {
            return PageConstructSpec(
                kind: .mapOverlaySheet,
                loadMap: loadMap,
                showFilters: true,
                overlaySheet: true
            )
        }
        return PageConstructSpec(
            kind: .listOnly,
            loadMap: false,
            showFilters: true,
            overlaySheet: false
        )
    }
}

struct NarrativeSectionDraft: Sendable {
    var id: String
    var role: NarrativeRole
    var items: [A2UIComponent]
    var tradeoff: String?
}

protocol NarrativeSelecting: Sendable {
    func select(from items: [A2UIComponent]) -> [NarrativeSectionDraft]
}

struct DefaultNarrativeSelector: NarrativeSelecting {
    func select(from items: [A2UIComponent]) -> [NarrativeSectionDraft] {
        guard !items.isEmpty else { return [] }
        let individualRoles: [NarrativeRole] = [
            .topMatch, .closeAlternative, .furtherAlternative, .wildCard,
        ]
        var sections = individualRoles.enumerated().compactMap { index, role -> NarrativeSectionDraft? in
            guard items.indices.contains(index) else { return nil }
            return NarrativeSectionDraft(
                id: "narrative-\(role.rawValue)",
                role: role,
                items: [items[index]],
                tradeoff: index == 0 ? nil : Self.factualSummary(items[index])
            )
        }
        if items.count > individualRoles.count {
            sections.append(NarrativeSectionDraft(
                id: "narrative-rest",
                role: .rest,
                items: Array(items.dropFirst(individualRoles.count)),
                tradeoff: nil
            ))
        }
        return sections
    }

    static func factualSummary(_ item: A2UIComponent) -> String? {
        let props = item.props
        let values: [String?] = [
            props["rationale"]?.stringValue,
            props["description"]?.stringValue,
            props["highlight"]?.stringValue,
            props["location"]?.stringValue,
            props["priceBasis"]?.stringValue,
            props["airline"]?.stringValue,
        ]
        return values.compactMap { $0 }.first { !$0.isEmpty }
    }
}

struct SectionComponentRegistry: Sendable {
    func bind(_ section: NarrativeSectionDraft) -> SectionComponentType {
        if section.role == .topMatch || section.role == .wildCard {
            return section.items.count == 1 ? .highlight : .list
        }
        if section.role == .rest {
            return section.items.count >= 3 ? .carousel : .list
        }
        return section.items.count >= 3 ? .carousel : .list
    }
}

struct SectionCopyRequest: Sendable {
    var id: String
    var role: NarrativeRole
    var itemName: String
    var itemFacts: [String]
    var tradeoff: String?
    var querySummary: String
}

protocol SectionCopyGenerating: Sendable {
    func generate(_ requests: [SectionCopyRequest]) async throws -> [String: PageSectionCopy]
}

struct DeterministicSectionCopyGenerator: SectionCopyGenerating {
    func generate(_ requests: [SectionCopyRequest]) async throws -> [String: PageSectionCopy] {
        Dictionary(uniqueKeysWithValues: requests.map { request in
            let heading: String
            switch request.role {
            case .topMatch:
                heading = "Best match: \(request.itemName)"
            case .closeAlternative:
                heading = "\(request.itemName), with a different balance"
            case .furtherAlternative:
                heading = "Another direction: \(request.itemName)"
            case .wildCard:
                heading = "Worth the detour: \(request.itemName)"
            case .rest:
                heading = "More ways to shape this trip"
            }
            let grounded = request.tradeoff
                ?? request.itemFacts.first
                ?? "A distinct option from the current results."
            return (request.id, PageSectionCopy(heading: heading, subheading: grounded))
        })
    }
}

struct FallbackSectionCopyGenerator: SectionCopyGenerating {
    var primary: any SectionCopyGenerating
    var fallback: any SectionCopyGenerating

    func generate(_ requests: [SectionCopyRequest]) async throws -> [String: PageSectionCopy] {
        do {
            return try await primary.generate(requests)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await fallback.generate(requests)
        }
    }
}

struct EmbeddedPageComposer: Sendable {
    var routeScorer = SemanticRouteScorer()
    var constructRegistry = PageConstructRegistry()
    var narrativeSelector: any NarrativeSelecting = DefaultNarrativeSelector()
    var componentRegistry = SectionComponentRegistry()
    var copyGenerator: any SectionCopyGenerating = DeterministicSectionCopyGenerator()

    func compose(
        intent: EmbeddedIntent,
        semanticIntent: EmbeddedIntent,
        trace: EmbeddedDecisionTrace,
        querySummary: String,
        lodging: [EmbeddedLodging],
        flights: [EmbeddedFlight],
        destinations: [EmbeddedDestination],
        activities: [EmbeddedActivity]
    ) async throws -> GeneratedPageSpec? {
        let items = EmbeddedSurfaceBuilder.compositionItems(
            intent: intent,
            trace: trace,
            lodging: lodging,
            flights: flights,
            destinations: destinations,
            activities: activities
        )
        let drafts = narrativeSelector.select(from: items)
        guard !drafts.isEmpty else { return nil }

        let route = routeScorer.score(intent: semanticIntent)
        let requests = drafts.map {
            SectionCopyRequest(
                id: $0.id,
                role: $0.role,
                itemName: Self.itemName($0.items.first),
                itemFacts: $0.items.flatMap(Self.itemFacts),
                tradeoff: $0.tradeoff,
                querySummary: querySummary
            )
        }
        let generatedCopy = try await copyGenerator.generate(requests)
        let fallbackCopy = try await DeterministicSectionCopyGenerator().generate(requests)
        let sections = drafts.map { draft in
            GeneratedPageSection(
                id: draft.id,
                role: draft.role,
                component: componentRegistry.bind(draft),
                copy: generatedCopy[draft.id]
                    ?? fallbackCopy[draft.id]
                    ?? PageSectionCopy(heading: Self.itemName(draft.items.first), subheading: ""),
                items: draft.items
            )
        }
        return GeneratedPageSpec(
            route: route,
            requirements: EmbeddedDataRequirementsResolver.resolve(intent: semanticIntent, route: route),
            construct: constructRegistry.construct(route: route, trace: trace),
            sections: sections
        )
    }

    private static func itemName(_ item: A2UIComponent?) -> String {
        guard let item else { return "More options" }
        return item.props["title"]?.stringValue
            ?? item.props["name"]?.stringValue
            ?? item.props["area"]?.stringValue
            ?? [item.props["origin"]?.stringValue, item.props["destination"]?.stringValue]
                .compactMap { $0 }.joined(separator: " → ")
    }

    private static func itemFacts(_ item: A2UIComponent) -> [String] {
        let props = item.props
        var facts: [String] = []
        for key in ["rationale", "description", "location", "priceBasis", "airline"] {
            if let value = props[key]?.stringValue, !value.isEmpty { facts.append(value) }
        }
        for key in ["packageFrom", "totalPrice", "price", "reviewScore"] {
            if let value = props[key]?.doubleValue { facts.append("\(key): \(value.formatted())") }
        }
        if let highlights = props["highlights"]?.arrayValue?.compactMap(\.stringValue), !highlights.isEmpty {
            facts.append(highlights.prefix(3).joined(separator: " · "))
        }
        return facts
    }
}
