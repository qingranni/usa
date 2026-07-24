import Foundation

@MainActor
protocol GenUIDataSourceProviding {
    func response(
        for query: String,
        continuation: SearchContinuation?,
        intentEvents: [ContinuationEvent]
    ) async throws -> AssistantResponse
}

enum GenUIDataSourceError: LocalizedError {
    case noResults
    case server(String)

    var errorDescription: String? {
        switch self {
        case .noResults:
            return "Gen-UI returned no supported results for this search."
        case .server(let message):
            return "Gen-UI is unavailable: \(message)"
        }
    }
}

enum AgentStateMapper {
    static func map(state: AgentState, query: String) throws -> AssistantResponse {
        guard let surface = state.surfaces["search-results"] else {
            throw GenUIDataSourceError.noResults
        }
        if let pageSpec = state.pageSpec {
            return try map(pageSpec: pageSpec, state: state, surface: surface, query: query)
        }

        var pieces: [Piece] = []
        for component in surface.components {
            collect(component, into: &pieces)
        }

        var blocks: [BlockSpec] = []
        var options: [Option] = []
        var pendingCards: [Option] = []
        var pendingKind: Kind?
        let optionStyle = preferredOptionStyle(for: state.template)

        func flushCards() {
            guard !pendingCards.isEmpty else { return }
            blocks.append(BlockSpec(
                style: optionStyle,
                items: pendingCards,
                cardPresentation: cardPresentation(for: pendingKind),
                kind: pendingKind
            ))
            pendingCards.removeAll()
            pendingKind = nil
        }

        for piece in pieces {
            switch piece {
            case .heading(let text):
                flushCards()
                blocks.append(BlockSpec(style: .heading, text: text))
            case .text(let text):
                flushCards()
                blocks.append(BlockSpec(style: .text, text: text))
            case .option(let option, let kind):
                if let pendingKind, pendingKind != kind {
                    flushCards()
                }
                pendingKind = kind
                pendingCards.append(option)
                options.append(option)
            case .semantic(let type, let props, let fallback):
                flushCards()
                blocks.append(BlockSpec(
                    style: .text,
                    text: fallback,
                    semanticType: type,
                    semanticProps: props
                ))
            }
        }
        flushCards()

        guard !options.isEmpty || !blocks.isEmpty else {
            throw GenUIDataSourceError.noResults
        }

        let title = nonempty(state.querySummary) ?? query
        let summary = pieces.compactMap { piece -> String? in
            switch piece {
            case .text(let text):
                return text
            case .semantic(_, _, let fallback):
                return fallback
            default:
                return nil
            }
        }.first ?? "Gen-UI results for \(title)."
        let countLabel = options.count == 1 ? "1 result" : "\(options.count) results"
        let kind = resultKind(template: state.template, pieces: pieces)
        let presentation = ResultsPresentation(
            showsMap: shouldShowMap(state: state, resultSurface: surface, kind: kind),
            filters: outputFilters(from: state),
            refinements: outputRefinements(from: state),
            map: serverMap(in: surface.components)
        )
        var continuationEvents: [ContinuationEvent] = []
        for event in state.intentEvents {
            continuationEvents.append(ContinuationEvent(event))
        }
        let continuation = SearchContinuation(
            sessionId: state.sessionId,
            intentEvents: continuationEvents,
            querySummary: state.querySummary
        )
        let decision = decisionPresentation(
            envelope: state.intentEnvelope,
            components: surface.components
        )
        let payload = ThreadPayload(
            kind: kind,
            title: title,
            summary: summary,
            label: countLabel,
            chip: "",
            options: options,
            source: .genUI,
            composition: composition(for: state.template),
            presentation: presentation,
            continuation: continuation,
            decision: decision,
            blocks: blocks
        )

        return AssistantResponse(reply: summary, thread: payload)
    }

    private static func map(
        pageSpec: GeneratedPageSpec,
        state: AgentState,
        surface: SurfaceState,
        query: String
    ) throws -> AssistantResponse {
        var blocks: [BlockSpec] = []
        var options: [Option] = []
        var allPieces: [Piece] = []

        for section in pageSpec.sections {
            var sectionPieces: [Piece] = []
            for item in section.items {
                collect(item, into: &sectionPieces)
            }
            let sectionOptions = sectionPieces.compactMap { piece -> (Option, Kind)? in
                guard case .option(let option, let kind) = piece else { return nil }
                return (option, kind)
            }
            guard !sectionOptions.isEmpty else { continue }
            allPieces.append(contentsOf: sectionPieces)
            options.append(contentsOf: sectionOptions.map(\.0))
            blocks.append(BlockSpec(style: .heading, text: section.copy.heading))
            if !section.copy.subheading.isEmpty {
                blocks.append(BlockSpec(style: .text, text: section.copy.subheading))
            }
            let sectionKind = sectionOptions.first?.1
            let style: ResultBlock.Style
            switch section.component {
            case .highlight: style = .highlight
            case .list: style = .cards
            case .carousel: style = .carousel
            }
            let presentation: ResultCardPresentation = section.items.allSatisfy {
                $0.type == "destination-card"
            } ? .destinationHero : cardPresentation(for: sectionKind)
            blocks.append(BlockSpec(
                style: style,
                items: sectionOptions.map(\.0),
                cardPresentation: presentation,
                kind: sectionKind
            ))
        }

        // Capability and provider-error blocks remain visible after composed content.
        var surfacePieces: [Piece] = []
        for component in surface.components {
            collect(component, into: &surfacePieces)
        }
        for piece in surfacePieces {
            guard case .semantic(let type, let props, let fallback) = piece else { continue }
            blocks.append(BlockSpec(
                style: .text,
                text: fallback,
                semanticType: type,
                semanticProps: props
            ))
        }

        guard !options.isEmpty else { throw GenUIDataSourceError.noResults }
        let title = nonempty(state.querySummary) ?? query
        let summary = pageSpec.sections.first?.copy.subheading ?? ""
        let kind = resultKind(template: state.template, pieces: allPieces)
        let presentation = ResultsPresentation(
            showsMap: pageSpec.construct.loadMap,
            showsFilters: pageSpec.construct.showFilters,
            overlaySheet: pageSpec.construct.overlaySheet,
            filters: pageSpec.construct.showFilters ? outputFilters(from: state) : [],
            refinements: pageSpec.construct.showFilters ? outputRefinements(from: state) : [],
            map: serverMap(in: surface.components)
        )
        let continuation = SearchContinuation(
            sessionId: state.sessionId,
            intentEvents: state.intentEvents.map(ContinuationEvent.init),
            querySummary: state.querySummary
        )
        let decision = decisionPresentation(
            envelope: state.intentEnvelope,
            components: surface.components
        )
        let payload = ThreadPayload(
            kind: kind,
            title: title,
            summary: summary,
            label: options.count == 1 ? "1 result" : "\(options.count) results",
            chip: "",
            options: options,
            source: .genUI,
            composition: .blocks,
            presentation: presentation,
            continuation: continuation,
            decision: decision,
            blocks: blocks
        )
        return AssistantResponse(reply: summary, thread: payload)
    }

    private static func shouldShowMap(
        state: AgentState,
        resultSurface: SurfaceState,
        kind: Kind
    ) -> Bool {
        if containsComponent(type: "map-view", in: resultSurface.components) {
            return true
        }
        if state.template == .clarification || state.template == .comparisonTable {
            return false
        }
        if kind == .lodging, decisionMapPolicy(in: resultSurface.components) == "results" {
            return true
        }

        let hasDestination = state.intent?.destinations.value.isEmpty == false
        let isGeographicResult = [.lodging, .flights, .cars, .activities, .other].contains(kind)
        return hasDestination && isGeographicResult
    }

    private static func outputFilters(from state: AgentState) -> [String] {
        guard let header = state.surfaces["header-bar"] else { return [] }
        var labels: [String] = []
        for component in header.components {
            collectFilters(component, into: &labels)
        }
        return labels.reduce(into: []) { result, label in
            guard !result.contains(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) else {
                return
            }
            result.append(label)
        }
    }

    private static func outputRefinements(from state: AgentState) -> [RefinementAction] {
        guard let header = state.surfaces["header-bar"] else { return [] }
        var values: [String] = []
        for component in header.components {
            collectRefinements(component, into: &values)
        }
        return values.enumerated().map { index, value in
            RefinementAction(
                id: "refinement-\(index)-\(value)",
                label: value,
                query: value,
                kind: .query
            )
        }
    }

    private static func collectRefinements(_ component: A2UIComponent, into values: inout [String]) {
        if component.type == "constraint-bar",
           let props = try? component.constraintBarProps() {
            values.append(contentsOf: props.refinements)
        }
        for child in component.children ?? [] {
            collectRefinements(child, into: &values)
        }
    }

    private static func serverMap(in components: [A2UIComponent]) -> ServerMapPresentation? {
        for component in components {
            if component.type == "map-view", let props = try? component.mapProps() {
                let pins = props.pins.compactMap { pin -> ServerMapPin? in
                    guard validCoordinate(latitude: pin.lat, longitude: pin.lng) else { return nil }
                    return ServerMapPin(
                        id: pin.id,
                        latitude: pin.lat,
                        longitude: pin.lng,
                        label: pin.label
                    )
                }
                guard !pins.isEmpty else { continue }
                let centerIsValid = props.center.map {
                    validCoordinate(latitude: $0.lat, longitude: $0.lng)
                } ?? false
                return ServerMapPresentation(
                    pins: pins,
                    centerLatitude: centerIsValid ? props.center?.lat : nil,
                    centerLongitude: centerIsValid ? props.center?.lng : nil,
                    zoom: props.zoom
                )
            }
            if let nested = serverMap(in: component.children ?? []) { return nested }
        }
        return nil
    }

    private static func decisionMapPolicy(in components: [A2UIComponent]) -> String? {
        guidanceUsher(in: components)?
            .props["decisionTrace"]?
            .objectValue?["template"]?
            .objectValue?["map"]?
            .stringValue
    }

    private static func validCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }

    private static func decisionPresentation(
        envelope: IntentEnvelope?,
        components: [A2UIComponent]
    ) -> DecisionPresentation? {
        let usher = guidanceUsher(in: components)
        let trace = usher?.props["decisionTrace"]?.objectValue
        guard envelope != nil || trace != nil else { return nil }

        let disambiguation = trace?["disambiguation"]?.objectValue
        let template = trace?["template"]?.objectValue
        let composition = trace?["composition"]?.objectValue
        let guidance = trace?["guidance"]?.objectValue
        return DecisionPresentation(
            completeness: envelope?.completeness.rawValue,
            stage: envelope?.stage.rawValue,
            register: envelope?.register.rawValue,
            actions: envelope?.actions.map(\.type.rawValue) ?? [],
            disambiguationLevel: disambiguation?["level"]?.stringValue,
            templateKind: template?["template"]?.stringValue,
            mapPolicy: template?["map"]?.stringValue,
            compositionRecipe: composition?["recipe"]?.stringValue,
            compositionTone: composition?["tone"]?.stringValue
                ?? usher?.props["tone"]?.stringValue,
            guidanceIntensity: guidance?["intensity"]?.stringValue
                ?? usher?.props["intensity"]?.stringValue,
            suggestionDensity: guidance?["suggestionDensity"]?.doubleValue,
            foregroundAttributes: guidance?["foregroundAttributes"]?
                .arrayValue?.compactMap(\.stringValue) ?? [],
            promptPlacement: guidance?["promptPlacement"]?.stringValue
        )
    }

    private static func guidanceUsher(in components: [A2UIComponent]) -> A2UIComponent? {
        for component in components {
            if component.id == "guidance-usher",
               component.type == "section-heading" {
                return component
            }
            if let nested = guidanceUsher(in: component.children ?? []) { return nested }
        }
        return nil
    }

    private static func collectFilters(_ component: A2UIComponent, into labels: inout [String]) {
        if component.type == "constraint-bar",
           let props = try? component.constraintBarProps() {
            labels.append(contentsOf: (props.primary + props.secondary).compactMap { pill in
                guard pill.type != "missing" else { return nil }
                return nonempty(pill.label)
            })
        }
        for child in component.children ?? [] {
            collectFilters(child, into: &labels)
        }
    }

    private static func containsComponent(type: String, in components: [A2UIComponent]) -> Bool {
        components.contains { component in
            component.type == type || containsComponent(type: type, in: component.children ?? [])
        }
    }

    private enum Piece {
        case heading(String)
        case text(String)
        case option(Option, Kind)
        case semantic(String, [String: JSONValue], String)
    }

    private static func collect(_ component: A2UIComponent, into pieces: inout [Piece]) {
        switch component.type {
        case "section-heading":
            if let props = try? component.typedProps(as: SectionHeadingProps.self),
               let text = nonempty(props.text) {
                pieces.append(.heading(text))
            }
        case "egds-heading", "heading":
            if let text = nonempty(component.props["text"]?.stringValue) {
                pieces.append(.heading(text))
            }
        case "text-block":
            if let props = try? component.typedProps(as: TextBlockProps.self),
               let text = nonempty(props.content) {
                pieces.append(.text(text))
            }
        case "egds-text", "text":
            if let text = nonempty(
                component.props["text"]?.stringValue
                    ?? component.props["content"]?.stringValue
            ) {
                pieces.append(.text(text))
            }
        case "lodging-card":
            if let props = try? component.lodgingProps() {
                pieces.append(.option(lodgingOption(props), .lodging))
            }
        case "flight-card":
            if let props = try? component.flightProps() {
                pieces.append(.option(flightOption(props), .flights))
            }
        case "destination-card":
            if let props = try? component.destinationProps() {
                pieces.append(.option(destinationOption(props), .other))
            }
        case "activity-card":
            if let props = try? component.activityProps() {
                pieces.append(.option(activityOption(props), .activities))
            }
        case "package-summary":
            if let props = try? component.packageSummaryProps() {
                pieces.append(.option(packageOption(props), .other))
            }
        case "result-state-summary":
            if let props = try? component.resultStateSummaryProps() {
                let fallback = [props.headline, props.detail].compactMap { $0 }.joined(separator: "\n")
                pieces.append(.semantic(component.type, component.props, fallback))
            }
        case "clarification":
            if let props = try? component.clarificationProps() {
                var semanticProps = component.props
                semanticProps["mappedActions"] = .array(
                    clarificationActions(props, rawProps: component.props).map { action in
                    .object([
                        "id": .string(action.id),
                        "label": .string(action.label),
                        "field": action.field.map(JSONValue.string) ?? .null,
                        "value": action.value ?? .null,
                        "query": .string(action.query),
                        "kind": .string(action.kind.rawValue),
                        "required": .bool(action.required),
                    ])
                })
                pieces.append(.semantic(component.type, semanticProps, props.question))
            }
        case "comparison-table":
            if let props = try? component.comparisonTableProps() {
                pieces.append(.semantic(component.type, component.props, props.title ?? "Comparison"))
            }
        case "validation-block":
            if let props = try? component.validationBlockProps() {
                pieces.append(.semantic(component.type, component.props, props.title))
            }
        case "explainability-note":
            if let props = try? component.explainabilityNoteProps() {
                pieces.append(.semantic(component.type, component.props, props.content))
            }
        case "capability-state":
            if let props = try? component.capabilityStateProps() {
                pieces.append(.semantic(component.type, component.props, "\(props.title)\n\(props.message)"))
            }
        default:
            break
        }

        for child in component.children ?? [] {
            collect(child, into: &pieces)
        }
    }

    private static func lodgingOption(_ props: LodgingCardProps) -> Option {
        let amenityText = props.amenities?
            .map(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let detail = [
            nonempty(props.location),
            nonempty(props.distance),
            nonempty(amenityText),
        ].compactMap { $0 }.joined(separator: " · ")
        let highlights = [
            nonempty(props.highlight),
            nonempty(props.refundableLabel),
            nonempty(props.refundableSublabel),
        ].compactMap { $0 }.joined(separator: " · ")

        return Option(
            title: props.name,
            detail: detail,
            price: nonempty(props.priceNightly) ?? nonempty(props.priceTotal),
            imageURL: nonempty(props.imageUrl),
            priceValue: numericPrice(props.priceNightly),
            highlights: nonempty(highlights),
            rating: props.reviewScore,
            reviewCount: props.reviewCount.map { Int($0) },
            city: nonempty(props.location),
            totalPrice: nonempty(props.priceTotal)
        )
    }

    private static func destinationOption(_ props: DestinationCardProps) -> Option {
        let highlights = props.highlights.filter { !$0.isEmpty }.joined(separator: " · ")
        let detail = [nonempty(props.country), nonempty(props.description)]
            .compactMap { $0 }
            .joined(separator: " · ")

        return Option(
            title: props.name,
            detail: detail,
            price: props.packageFrom.map { currency($0, code: props.currency ?? "USD") },
            imageURL: nonempty(props.imageUrl),
            priceValue: props.packageFrom.map { Int($0.rounded()) },
            highlights: nonempty(props.rationale) ?? nonempty(highlights),
            city: nonempty(props.airportCode)
        )
    }

    private static func activityOption(_ props: ActivityCardProps) -> Option {
        let highlights = props.highlights.filter { !$0.isEmpty }.joined(separator: " · ")
        return Option(
            title: props.name,
            detail: nonempty(props.description) ?? nonempty(highlights) ?? "",
            price: nonempty(props.formattedPrice)
                ?? props.price.map { currency($0, code: props.currency ?? "USD") },
            imageURL: nonempty(props.imageUrl),
            priceValue: props.price.map { Int($0.rounded()) },
            highlights: nonempty(highlights),
            rating: props.reviewScore,
            reviewCount: props.reviewCount.map(Int.init)
        )
    }

    private static func flightOption(_ props: FlightCardProps) -> Option {
        Option(
            title: "\(props.origin) → \(props.destination)",
            detail: "\(props.airline) \(props.flightNumber)",
            price: currency(props.totalPrice ?? props.price, code: props.currency),
            priceValue: Int((props.totalPrice ?? props.price).rounded()),
            departTime: props.departureTime,
            arriveTime: props.arrivalTime,
            stops: props.stops == 0 ? "Nonstop" : "\(props.stops) stop\(props.stops == 1 ? "" : "s")",
            duration: "\(props.durationMinutes / 60)h \(props.durationMinutes % 60)m",
            cabin: props.class.capitalized,
            tripType: props.priceBasis,
            airlines: [props.airline],
            logoURLs: airlineLogos(props.airline),
            highlights: props.provisional == true
                ? "Prototype fixture — not bookable inventory"
                : props.bagsIncluded
        )
    }

    private static func packageOption(_ props: PackageSummaryProps) -> Option {
        Option(
            title: nonempty(props.title) ?? props.area,
            detail: [
                props.airportCodes.joined(separator: ", "),
                [props.departureDate, props.returnDate].compactMap { $0 }.joined(separator: " – "),
                props.rationale,
            ].compactMap(nonempty).joined(separator: " · "),
            price: currency(props.packageFrom, code: props.currency),
            imageURL: nonempty(props.imageUrl),
            priceValue: Int(props.packageFrom.rounded()),
            highlights: props.savings.map { "\(currency($0, code: props.currency)) savings" } ?? props.priceBasis,
            city: props.destination,
            totalPrice: props.lodgingBudgetRemaining.map {
                "\(currency($0, code: props.currency)) lodging budget"
            }
        )
    }

    private static func clarificationActions(
        _ props: ClarificationProps,
        rawProps: [String: JSONValue]
    ) -> [RefinementAction] {
        if let options = props.options, !options.isEmpty {
            return options.enumerated().map { index, option in
                RefinementAction(
                    id: "clarification-\(props.field)-option-\(index)",
                    label: option.label,
                    field: props.field,
                    value: option.value,
                    query: option.label,
                    kind: .selection,
                    required: props.required
                )
            }
        }
        if let suggestion = props.suggestion ?? rawProps["inferredValue"] {
            let label = nonempty(props.suggestionLabel) ?? readable(suggestion)
            return [
                RefinementAction(
                    id: "clarification-\(props.field)-suggestion",
                    label: label,
                    field: props.field,
                    value: suggestion,
                    query: readable(suggestion),
                    kind: .selection,
                    required: props.required
                ),
            ]
        }
        return [
            RefinementAction(
                id: "clarification-\(props.field)-composer",
                label: "Add details",
                field: props.field,
                query: "",
                kind: .openComposer,
                required: props.required
            ),
        ]
    }

    private static func readable(_ value: JSONValue) -> String {
        switch value {
        case .null: return ""
        case .bool(let value): return value ? "Yes" : "No"
        case .number(let value): return value.formatted()
        case .string(let value): return value
        case .array(let values): return values.map { readable($0) }.joined(separator: ", ")
        case .object(let object):
            return object.keys.sorted().compactMap { key in
                object[key].map { "\(key): \(readable($0))" }
            }.joined(separator: ", ")
        }
    }

    private static func currency(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(Int(value.rounded()))"
    }

    private static func airlineLogos(_ airline: String) -> [String] {
        switch airline.lowercased() {
        case let value where value.contains("delta"): return ["airline-dl"]
        case let value where value.contains("united"): return ["airline-ua"]
        case let value where value.contains("jetblue"): return ["airline-b6"]
        case let value where value.contains("southwest"): return ["airline-wn"]
        case let value where value.contains("alaska"): return ["airline-as"]
        default: return []
        }
    }

    private static func resultKind(template: TemplateType?, pieces: [Piece]) -> Kind {
        switch template {
        case .lodgingSearch, .lodgingList, .lodgingGroups:
            return .lodging
        case .flightsSearch, .flightList:
            return .flights
        case .activitiesSearch:
            return .activities
        case .destinationExplore, .destinationCarousel, .packageOverview:
            return .other
        case .comparisonTable, .mixedResults, .clarification, .mixed, nil:
            if pieces.contains(where: { piece in
                guard case .option(_, let kind) = piece else { return false }
                return kind == .lodging
            }) { return .lodging }
            if pieces.contains(where: { piece in
                guard case .option(_, let kind) = piece else { return false }
                return kind == .activities
            }) { return .activities }
            return .other
        }
    }

    private static func preferredOptionStyle(for template: TemplateType?) -> ResultBlock.Style {
        switch template {
        case .destinationCarousel, .lodgingGroups:
            return .carousel
        default:
            return .cards
        }
    }

    private static func composition(for template: TemplateType?) -> ResultComposition {
        switch template {
        case .flightList, .flightsSearch:
            return .flightList
        case .packageOverview:
            return .packageShelves
        default:
            return .blocks
        }
    }

    private static func cardPresentation(for kind: Kind?) -> ResultCardPresentation {
        switch kind {
        case .lodging: return .lodging
        case .flights: return .flight
        case .activities, .cars, .other, nil: return .generic
        }
    }

    private static func numericPrice(_ value: String?) -> Int? {
        guard let value else { return nil }
        let numeric = value.filter { $0.isNumber || $0 == "." }
        return Double(numeric).map { Int($0.rounded()) }
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Compatibility name retained for existing mapper and remote diagnostic tests.
typealias GenUIDataSource = AgentStateMapper

extension ContinuationEvent {
    init(_ event: IntentEvent) {
        self.init(
            id: event.id,
            type: event.type.rawValue,
            timestamp: event.timestamp,
            field: event.field,
            previousValue: event.previousValue,
            newValue: event.newValue,
            strength: event.strength?.rawValue,
            source: event.source.rawValue,
            confidence: event.confidence,
            rawInput: event.rawInput,
            provenance: event.provenance
        )
    }

    var intentEvent: IntentEvent {
        IntentEvent(
            id: id,
            type: IntentEventType(rawValue: type) ?? .refinement,
            timestamp: timestamp,
            field: field,
            previousValue: previousValue,
            newValue: newValue,
            strength: strength.flatMap(ConstraintStrength.init(rawValue:)),
            source: IntentEventSource(rawValue: source) ?? .user,
            confidence: confidence,
            rawInput: rawInput,
            provenance: provenance
        )
    }
}
