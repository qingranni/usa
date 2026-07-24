import Foundation

enum EmbeddedProduct: String, Sendable {
    case lodging
    case flight
    case activities
}

enum EmbeddedGoal: String, Sendable {
    case find
    case explore
    case compare
}

struct EmbeddedIntent: Sendable {
    var destinations: [String] = []
    var goal: EmbeddedGoal = .find
    var products: [EmbeddedProduct] = [.lodging]
    var relationship = "single"
    var departureDate: String?
    var returnDate: String?
    var originAirport: String?
    var adults = 1
    var children: [Int] = []
    var totalBudget: Double?
    var amenities: [String] = []
    var travelStyle: [String] = []
    var flightClass: String?
}

private enum EmbeddedQueryIntentLexicon {
    private static let flightPattern = #"\b(flights?|fares?|airlines?|airports?|nonstop|cabin)\b"#
    private static let lodgingPattern = #"\b(hotels?|resorts?|stays?|lodging|properties|rooms?)\b"#
    private static let activitiesPattern = #"\b(activities|activity|things?\s+to\s+do|attractions?|tours?|excursions?|tickets?)\b"#
    private static let packagePattern = #"\b(packages?|bundles?)\b"#
    private static let productPattern = #"(?:packages?|vacations?|holidays?|trips?|getaways?|hotels?|resorts?|stays?|lodging|properties|rooms?|flights?|fares?|activities|activity|things?\s+to\s+do|attractions?|tours?|excursions?|tickets?)"#

    static func productScope(in query: String) -> (products: [EmbeddedProduct], relationship: String)? {
        let flight = contains(flightPattern, in: query)
        let lodging = contains(lodgingPattern, in: query)
        let activities = contains(activitiesPattern, in: query)
        let package = contains(packagePattern, in: query)
        if package || (flight && lodging) {
            return ([.flight, .lodging] + (activities ? [.activities] : []), "package")
        }
        if activities && (flight || lodging) {
            return ((flight ? [.flight] : []) + (lodging ? [.lodging] : []) + [.activities], "sequence")
        }
        if flight { return ([.flight], "single") }
        if lodging { return ([.lodging], "single") }
        if activities { return ([.activities], "single") }
        return nil
    }

    static func destination(in query: String) -> String? {
        let introduced = #"\b(?:to|in|near)\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]{1,50}?)(?=\s+(?:need(?:s)?|want(?:s)?|with|from|under|for|on|\#(productPattern))\b|$)"#
        if let destination = capture(introduced, in: query) {
            return destination
        }

        let destinationFirst = #"^\s*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]{1,50}?)\s+\#(productPattern)\b"#
        if let destination = capture(destinationFirst, in: query) {
            return destination
        }

        let known = [
            "Mexico City", "Los Angeles", "Mexico", "Cancun", "London", "Paris",
            "Miami", "Seattle", "Lisbon", "Tokyo", "Vancouver", "Tampa",
        ]
        return known.first { query.localizedCaseInsensitiveContains($0) }
    }

    private static func contains(_ pattern: String, in query: String) -> Bool {
        query.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func capture(_ pattern: String, in query: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let range = Range(match.range(at: 1), in: query) else { return nil }
        let value = query[range].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum EmbeddedRetrievalPolicy {
    static let prototypeOrigin = "SEA"

    static func enriched(_ compiled: EmbeddedIntent, query: String, now: Date = Date()) -> EmbeddedIntent {
        var intent = compiled
        if let scope = EmbeddedQueryIntentLexicon.productScope(in: query) {
            intent.products = scope.products
            intent.relationship = scope.relationship
        }
        if let route = route(in: query) {
            intent.originAirport = route.origin
            intent.destinations = [route.destination]
        } else if intent.destinations.isEmpty,
                  let destination = EmbeddedQueryIntentLexicon.destination(in: query) {
            intent.destinations = [destination]
        }
        if let adults = partyCount(in: query) { intent.adults = adults }
        if let dates = naturalLanguageDates(in: query, now: now) {
            intent.departureDate = dates.0
            intent.returnDate = dates.1
        }

        let open = intent.goal == .explore && intent.destinations.isEmpty
        guard !open else { return intent }
        let calendar = utcCalendar
        if intent.departureDate == nil {
            intent.departureDate = iso(calendar.date(byAdding: .day, value: 7, to: now) ?? now)
        }
        if intent.products.contains(.lodging), intent.returnDate == nil, let departure = intent.departureDate.flatMap(parseISO) {
            let stayLength = intent.relationship == "package" ? 5 : 1
            intent.returnDate = iso(
                calendar.date(byAdding: .day, value: stayLength, to: departure) ?? departure
            )
        }
        if intent.products.contains(.flight), intent.originAirport == nil {
            intent.originAirport = prototypeOrigin
        }
        return intent
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func route(in query: String) -> (origin: String, destination: String)? {
        let pattern = #"\b(?:flights?\s+)?to\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]{1,30}?)\s+from\s+([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]{1,30}?)(?=\s+(?:\d|for\b|on\b|depart|return)|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let destinationRange = Range(match.range(at: 1), in: query),
              let originRange = Range(match.range(at: 2), in: query) else { return nil }
        return (
            String(query[originRange]).trimmingCharacters(in: .whitespaces),
            String(query[destinationRange]).trimmingCharacters(in: .whitespaces)
        )
    }

    private static func partyCount(in query: String) -> Int? {
        let pattern = #"\b(\d{1,2})\s+(?:people|persons?|travel(?:l)?ers?|adults?)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)),
              let range = Range(match.range(at: 1), in: query) else { return nil }
        return Int(query[range])
    }

    private static func naturalLanguageDates(in query: String, now: Date) -> (String, String)? {
        if query.range(of: #"\bnext month\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            let calendar = utcCalendar
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  let start = calendar.date(
                    from: DateComponents(
                        year: calendar.component(.year, from: nextMonth),
                        month: calendar.component(.month, from: nextMonth),
                        day: 1
                    )
                  ),
                  let end = calendar.date(byAdding: .day, value: 4, to: start)
            else { return nil }
            return (iso(start), iso(end))
        }
        let months = "January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec"
        let patterns = [
            #"\b(\d{1,2})(?:st|nd|rd|th)?\s+(\#(months))\s+(?:to|through|-)\s+(\d{1,2})(?:st|nd|rd|th)?(?:\s+(\#(months)))?\b"#,
            #"\b(\#(months))\s+(\d{1,2})(?:st|nd|rd|th)?\s+(?:to|through|-)\s+(?:(\#(months))\s+)?(\d{1,2})(?:st|nd|rd|th)?\b"#,
        ]
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: query, range: NSRange(query.startIndex..., in: query)) else { continue }
            func capture(_ position: Int) -> String? {
                guard match.range(at: position).location != NSNotFound,
                      let range = Range(match.range(at: position), in: query) else { return nil }
                return String(query[range])
            }
            let startDay = Int(capture(index == 0 ? 1 : 2) ?? "")
            let startMonth = capture(index == 0 ? 2 : 1)
            let endDay = Int(capture(index == 0 ? 3 : 4) ?? "")
            let endMonth = capture(index == 0 ? 4 : 3) ?? startMonth
            guard let startDay, let startMonth, let endDay, let endMonth,
                  let startMonthNumber = monthNumber(startMonth),
                  let endMonthNumber = monthNumber(endMonth) else { continue }
            let calendar = utcCalendar
            var year = calendar.component(.year, from: now)
            guard var start = calendar.date(from: DateComponents(year: year, month: startMonthNumber, day: startDay)) else { continue }
            if start < calendar.startOfDay(for: now) {
                year += 1
                guard let rolled = calendar.date(from: DateComponents(year: year, month: startMonthNumber, day: startDay)) else { continue }
                start = rolled
            }
            var endYear = endMonthNumber < startMonthNumber ? year + 1 : year
            var end = calendar.date(from: DateComponents(year: endYear, month: endMonthNumber, day: endDay))
            if let candidate = end, candidate < start {
                endYear += 1
                end = calendar.date(from: DateComponents(year: endYear, month: endMonthNumber, day: endDay))
            }
            if let end { return (iso(start), iso(end)) }
        }
        return nil
    }

    private static func monthNumber(_ value: String) -> Int? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in ["MMMM", "MMM"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return utcCalendar.component(.month, from: date) }
        }
        return nil
    }

    private static func iso(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseISO(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = utcCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}

struct EmbeddedIntentParseResult: Sendable {
    var events: [IntentEvent]
    var querySummary: String
    var suggestions: [String]
    var refinements: [String]
}

protocol EmbeddedIntentProviding: Sendable {
    var configured: Bool { get }
    func parse(
        query: String,
        previousEvents: [IntentEvent],
        previousQuerySummary: String?
    ) async throws -> EmbeddedIntentParseResult
}

struct FixtureIntentProvider: EmbeddedIntentProviding {
    let configured = true

    func parse(
        query: String,
        previousEvents: [IntentEvent],
        previousQuerySummary: String?
    ) async throws -> EmbeddedIntentParseResult {
        let lower = query.lowercased()
        var values: [(String, JSONValue)] = []
        let explore = lower.range(
            of: #"\b(ideas|inspiration|anywhere|somewhere|where should|best place|vacations?|trips?|getaways?)\b"#,
            options: .regularExpression
        ) != nil && lower.range(of: #"\b(packages?|bundles?)\b"#, options: .regularExpression) == nil
        let compare = lower.range(of: #"\b(compare|versus|vs\.?)\b"#, options: .regularExpression) != nil
        let explicitScope = EmbeddedQueryIntentLexicon.productScope(in: query)
        let products = explicitScope?.products ?? [.lodging]
        let included = products.map(\.rawValue)
        let relationship = explicitScope?.relationship ?? "single"
        values.append(("goal", .string(compare ? "compare" : explore ? "explore" : "find")))
        values.append(("searchMode", .string(explore ? "explore" : "product-search")))
        values.append(("productScope", .object([
            "included": .array(included.map(JSONValue.string)),
            "relationship": .string(relationship),
            "confidence": .number(explicitScope == nil ? 0.72 : 0.92),
        ])))

        let destination = Self.destination(in: query)
        if let destination { values.append(("destinations", .array([.string(destination)]))) }
        if let origin = Self.origin(in: query) { values.append(("originAirport", .string(origin))) }
        let dates = Self.isoDates(in: query)
        if let departure = dates.first { values.append(("departureDate", .string(departure))) }
        if dates.count > 1 { values.append(("returnDate", .string(dates[1]))) }
        if lower.contains("pool") { values.append(("amenities", .array([.string("Pool")]))) }
        if let budget = Self.budget(in: lower) {
            values.append(("totalBudget", .object(["amount": .number(budget), "currency": .string("USD")])))
        }

        let timestamp = Date().timeIntervalSince1970 * 1_000
        let type: IntentEventType = previousEvents.isEmpty ? .inference : .refinement
        let events = values.enumerated().map { index, pair in
            IntentEvent(
                id: UUID().uuidString,
                type: type,
                timestamp: timestamp + Double(index),
                field: pair.0,
                newValue: pair.1,
                strength: .hard,
                source: .user,
                confidence: 0.9,
                rawInput: query,
                provenance: "embedded-fixture-intent"
            )
        }
        return EmbeddedIntentParseResult(
            events: events,
            querySummary: previousEvents.isEmpty ? query : [previousQuerySummary, query].compactMap { $0 }.joined(separator: " · "),
            suggestions: [],
            refinements: []
        )
    }

    private static func destination(in query: String) -> String? {
        EmbeddedQueryIntentLexicon.destination(in: query)
    }

    private static func origin(in query: String) -> String? {
        guard let range = query.range(of: #"\bfrom\s+([A-Za-z]{3}|[A-Za-zÀ-ÿ][A-Za-zÀ-ÿ .'-]{2,25})"#, options: [.regularExpression, .caseInsensitive]) else { return nil }
        return String(query[range]).replacingOccurrences(of: #"^from\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"\s+to\b.*$"#, with: "", options: [.regularExpression, .caseInsensitive])
    }

    private static func isoDates(in query: String) -> [String] {
        let regex = try? NSRegularExpression(pattern: #"\b20\d{2}-\d{2}-\d{2}\b"#)
        let range = NSRange(query.startIndex..., in: query)
        return regex?.matches(in: query, range: range).compactMap { Range($0.range, in: query).map { String(query[$0]) } } ?? []
    }

    private static func budget(in query: String) -> Double? {
        guard let range = query.range(of: #"\$[\d,]+"#, options: .regularExpression) else { return nil }
        return Double(query[range].filter(\.isNumber))
    }
}

enum EmbeddedSourceMode: Sendable {
    case fixture
    case live
}

struct EmbeddedProviderConfiguration: Sendable {
    var mode: EmbeddedSourceMode = .fixture
}

struct EmbeddedLodging: Sendable {
    var id: String
    var name: String
    var location: String
    var amenities: [String]
    var nightly: Double
    var total: Double
    var rating: Double
    var reviews: Int
    var refundable: Bool
    var latitude: Double?
    var longitude: Double?
    var imageURL: String? = nil
    var dataSource = "fixture"
}

struct EmbeddedFlight: Sendable {
    var id: String
    var airline: String
    var number: String
    var origin: String
    var destination: String
    var departure: String
    var arrival: String
    var duration: Int
    var price: Double
    var total: Double
    var stops: Int
    var cabin: String
    var dataSource = "fixture"
}

struct EmbeddedDestination: Sendable {
    var id: String
    var name: String
    var country: String
    var description: String
    var highlights: [String]
    var imageURL: String? = nil
    var airportCode: String? = nil
    var rationale: String? = nil
    var packageFrom: Double? = nil
    var currency = "USD"
    var dataSource = "fixture"
}

struct EmbeddedActivity: Sendable {
    var id: String
    var name: String
    var description: String
    var highlights: [String]
    var price: Double?
    var formattedPrice: String?
    var currency = "USD"
    var rating: Double?
    var reviews: Int?
    var imageURL: String?
    var dataSource = "fixture"
}

struct EmbeddedPackage: Sendable {
    var id: String
    var lodging: EmbeddedLodging
    var flight: EmbeddedFlight
    var destination: String
    var departureDate: String
    var returnDate: String
    var rationale: String
    var total: Double
    var listPrice: Double?
    var currency: String
    var provenance: [String]
}

protocol EmbeddedLodgingProviding: Sendable {
    var available: Bool { get }
    func readiness() async -> Bool
    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging]
}

protocol EmbeddedFlightProviding: Sendable {
    var available: Bool { get }
    func readiness() async -> Bool
    func search(intent: EmbeddedIntent) async throws -> [EmbeddedFlight]
}

protocol EmbeddedDestinationProviding: Sendable {
    var available: Bool { get }
    func readiness() async -> Bool
    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination]
}

protocol EmbeddedActivityProviding: Sendable {
    var available: Bool { get }
    func readiness() async -> Bool
    func search(intent: EmbeddedIntent) async throws -> [EmbeddedActivity]
}

extension EmbeddedLodgingProviding { func readiness() async -> Bool { available } }
extension EmbeddedFlightProviding { func readiness() async -> Bool { available } }
extension EmbeddedDestinationProviding { func readiness() async -> Bool { available } }
extension EmbeddedActivityProviding { func readiness() async -> Bool { available } }

struct FixtureTravelProvider: EmbeddedLodgingProviding, EmbeddedFlightProviding, EmbeddedDestinationProviding, EmbeddedActivityProviding {
    let available = true

    func readiness() async -> Bool { available }

    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        let place = intent.destinations.joined(separator: ", ")
        return [
            .init(id: "fixture-harbor", name: "Harbor House", location: place, amenities: ["Pool", "Free WiFi"], nightly: 189, total: 567, rating: 9.1, reviews: 842, refundable: true, latitude: 20.6534, longitude: -105.2253, imageURL: ImageLibrary.imageURL(forKey: "lodging_beach_resort", kind: .lodging)),
            .init(id: "fixture-garden", name: "Garden Courtyard Hotel", location: place, amenities: ["Breakfast included"], nightly: 154, total: 462, rating: 8.7, reviews: 516, refundable: false, latitude: 20.6597, longitude: -105.2378, imageURL: ImageLibrary.imageURL(forKey: "lodging_city_boutique", kind: .lodging)),
            .init(id: "fixture-sunset", name: "Sunset Beach Suites", location: place, amenities: ["Ocean view", "Kitchenette"], nightly: 221, total: 663, rating: 8.9, reviews: 391, refundable: false, latitude: 20.6489, longitude: -105.2415, imageURL: ImageLibrary.imageURL(forKey: "lodging_design_stay", kind: .lodging)),
        ]
    }

    func search(intent: EmbeddedIntent) async throws -> [EmbeddedFlight] {
        let origin = Self.airport(intent.originAirport ?? "SEA")
        let destination = Self.airport(intent.destinations.first ?? "LAX")
        let party = max(1, intent.adults + intent.children.count)
        return [("Delta", "DL", 238, 210, 0), ("United", "UA", 279, 238, 0), ("American", "AA", 320, 266, 1)]
            .enumerated().map { index, value in
                let hour = 7 + index * 3
                return EmbeddedFlight(
                    id: "fixture-\(value.1)-\(index)", airline: value.0, number: "\(value.1)\(120 + index * 83)",
                    origin: origin, destination: destination, departure: String(format: "%02d:10", hour),
                    arrival: String(format: "%02d:%02d", (hour + value.3 / 60) % 24, value.3 % 60),
                    duration: value.3, price: Double(value.2), total: Double(value.2 * party), stops: value.4,
                    cabin: intent.flightClass ?? "economy"
                )
            }
    }

    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        let styles = intent.travelStyle.isEmpty ? ["Culture", "Food", "Outdoors"] : intent.travelStyle
        return [
            .init(id: "fixture-lisbon", name: "Lisbon", country: "Portugal", description: "Walkable neighborhoods, coast, and food", highlights: styles),
            .init(id: "fixture-mexico-city", name: "Mexico City", country: "Mexico", description: "Museums, markets, and acclaimed dining", highlights: styles),
            .init(id: "fixture-vancouver", name: "Vancouver", country: "Canada", description: "Mountains and waterfront in one city", highlights: styles),
        ]
    }

    func search(intent: EmbeddedIntent) async throws -> [EmbeddedActivity] {
        MexicoFixtureCatalog.activities.map {
            EmbeddedActivity(
                id: $0.id,
                name: $0.name,
                description: $0.duration,
                highlights: [],
                price: Double($0.priceFrom),
                formattedPrice: "$\($0.priceFrom)",
                imageURL: ImageLibrary.imageURL(forKey: $0.imageURL, kind: .activities)
            )
        }
    }

    private static func airport(_ value: String) -> String {
        let airports = ["los angeles": "LAX", "london": "LHR", "mexico": "MEX", "cancun": "CUN", "paris": "CDG", "tokyo": "HND", "miami": "MIA", "seattle": "SEA", "vancouver": "YVR", "lisbon": "LIS", "tampa": "TPA"]
        if let match = airports.first(where: { value.lowercased().contains($0.key) }) { return match.value }
        if let code = value.range(of: #"\b[A-Z]{3}\b"#, options: .regularExpression) { return String(value[code]) }
        return String(value.prefix(3)).uppercased()
    }
}

enum DisambiguationLevel: String, Sendable { case none, immersive, blocking, partial }
enum SourceReadiness: String, Sendable { case ready, blocked, unavailable }

struct EmbeddedAction: Sendable {
    var type: String
    var field: String
    var reason: String
    var suggestion: JSONValue?
}

struct DisambiguationDecision: Sendable {
    var level: DisambiguationLevel
    var actions: [EmbeddedAction]
}

struct SourceTask: Sendable {
    var source: String
    var readiness: SourceReadiness
}

struct SourcingDecision: Sendable {
    var tasks: [SourceTask]
    var mode: String
}

struct TemplateDecision: Sendable {
    var template: String
    var map: String
}

struct CompositionDecision: Sendable {
    var recipe: String
    var tone: String
}

struct GuidanceDecision: Sendable {
    var intensity: String
    var suggestionDensity: Double
    var foregroundAttributes: [String]
    var promptPlacement: String
    var usherCopy: String
}

struct EmbeddedDecisionTrace: Sendable {
    var disambiguation: DisambiguationDecision
    var sourcing: SourcingDecision
    var template: TemplateDecision
    var composition: CompositionDecision
    var guidance: GuidanceDecision

    var json: JSONValue {
        .object([
            "phases": .array(["disambiguation", "sourcing", "template", "composition", "guidance"].map(JSONValue.string)),
            "disambiguation": .object(["level": .string(disambiguation.level.rawValue)]),
            "sourcing": .object(["mode": .string(sourcing.mode)]),
            "template": .object(["template": .string(template.template), "map": .string(template.map)]),
            "composition": .object(["recipe": .string(composition.recipe), "tone": .string(composition.tone)]),
            "guidance": .object([
                "intensity": .string(guidance.intensity),
                "suggestionDensity": .number(guidance.suggestionDensity),
                "foregroundAttributes": .array(guidance.foregroundAttributes.map(JSONValue.string)),
                "promptPlacement": .string(guidance.promptPlacement),
            ]),
        ])
    }
}

enum EmbeddedDecisionPipeline {
    static func decide(
        intent: EmbeddedIntent,
        lodgingAvailable: Bool,
        flightAvailable: Bool,
        destinationAvailable: Bool,
        activityAvailable: Bool = true,
        now: Date = Date()
    ) -> EmbeddedDecisionTrace {
        let open = intent.goal == .explore
        var actions: [EmbeddedAction] = []
        let calendar = Calendar(identifier: .gregorian)
        let departure = calendar.date(byAdding: .day, value: 7, to: now) ?? now
        let returning = calendar.date(byAdding: .day, value: 1, to: departure) ?? departure
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dates: JSONValue = .object([
            "departureDate": .string(formatter.string(from: departure)),
            "returnDate": .string(formatter.string(from: returning)),
        ])
        if !open && intent.destinations.isEmpty {
            actions.append(.init(type: "ask-blocking", field: "destinations", reason: "A destination is required for retrieval."))
        }
        if !open && intent.departureDate == nil {
            actions.append(.init(type: "ask-blocking", field: "departureDate", reason: "Confirmed dates are required for current inventory.", suggestion: dates))
        }
        if intent.products.contains(.lodging), !open, intent.returnDate == nil, intent.departureDate != nil {
            actions.append(.init(type: "ask-blocking", field: "returnDate", reason: "A confirmed check-out date is required for lodging inventory.", suggestion: dates))
        }
        if intent.products.contains(.flight), intent.originAirport == nil {
            actions.append(.init(type: "ask-blocking", field: "originAirport", reason: "An origin is required to price flights."))
        }
        if intent.totalBudget == nil {
            actions.append(.init(type: "ask-conversational", field: "totalBudget", reason: "Budget can improve result relevance."))
        }
        if intent.products.contains(.lodging), intent.amenities.isEmpty {
            actions.append(.init(type: "infer", field: "amenities", reason: "Amenities can improve result relevance."))
        }
        let blocking = actions.contains { $0.type == "ask-blocking" }
        let canRenderDestination = !intent.destinations.isEmpty || open
        let level: DisambiguationLevel = open ? .immersive : blocking && canRenderDestination ? .partial : blocking ? .blocking : .none

        func inventoryBlocked(_ source: EmbeddedProduct) -> Bool {
            intent.destinations.isEmpty || intent.departureDate == nil
                || (source == .lodging && intent.returnDate == nil)
                || (source == .flight && intent.originAirport == nil)
        }
        var tasks: [SourceTask] = []
        if open || level == .partial || level == .immersive {
            tasks.append(.init(source: "destination", readiness: destinationAvailable ? .ready : .unavailable))
        }
        if !open, intent.products.contains(.lodging) {
            tasks.append(.init(source: "lodging", readiness: inventoryBlocked(.lodging) ? .blocked : lodgingAvailable ? .ready : .unavailable))
        }
        if !open, intent.products.contains(.flight) {
            tasks.append(.init(source: "flight", readiness: inventoryBlocked(.flight) ? .blocked : flightAvailable ? .ready : .unavailable))
        }
        if !open, intent.products.contains(.activities) {
            tasks.append(.init(source: "activity", readiness: inventoryBlocked(.activities) ? .blocked : activityAvailable ? .ready : .unavailable))
        }
        if !open, intent.relationship == "package" {
            let dependencies = tasks.filter { $0.source == "lodging" || $0.source == "flight" }
            let readiness: SourceReadiness = dependencies.allSatisfy { $0.readiness == .ready } ? .ready
                : dependencies.contains { $0.readiness == .ready } ? .blocked : .unavailable
            tasks.append(.init(source: "package", readiness: readiness))
        }
        if intent.goal == .compare {
            tasks.append(.init(source: "comparison", readiness: tasks.first { $0.source == "lodging" }?.readiness ?? .blocked))
        }
        let ready = tasks.filter { $0.readiness == .ready }
        let blockedTasks = tasks.filter { $0.readiness == .blocked }
        let mode = ready.isEmpty ? "none" : ready.count > 1 && !blockedTasks.isEmpty ? "partial"
            : ready.count > 1 ? "mixed" : intent.destinations.count > 1 && ready.first?.source == "lodging" ? "grouped"
            : !blockedTasks.isEmpty ? "partial" : "single"
        let template = ready.isEmpty ? "clarification"
            : intent.goal == .compare && ready.contains { $0.source == "comparison" } ? "comparison"
            : ready.contains { $0.source == "package" } ? "itinerary-package"
            : mode == "mixed" || mode == "partial" ? "mixed-results"
            : ready.first?.source == "destination" ? "destination-carousel" : "results"
        let flightOnly = !ready.isEmpty && ready.allSatisfy { $0.source == "flight" }
        let map = template == "clarification" || flightOnly ? "none" : "results"
        let recipe = template == "clarification" && tasks.contains { $0.readiness == .unavailable } ? "capability"
            : template == "clarification" ? "clarification" : template == "comparison" ? "comparison"
            : template == "itinerary-package" ? "package" : mode == "partial" ? "partial"
            : mode == "mixed" ? "mixed" : mode == "grouped" ? "grouped-lodging"
            : ready.first?.source == "destination" ? "destination"
            : ready.first?.source == "flight" ? "flight"
            : ready.first?.source == "activity" ? "activity" : "lodging"
        let stage = open ? "inspire" : blocking ? "orient" : "decide"
        let intensity = level == .immersive ? "immersive" : level == .blocking || level == .partial || stage == "orient" ? "active" : stage == "inspire" ? "light" : "minimal"
        let foreground = actions.filter { $0.type != "skip" }.prefix(4).map(\.field)
        return EmbeddedDecisionTrace(
            disambiguation: .init(level: level, actions: actions),
            sourcing: .init(tasks: tasks, mode: mode),
            template: .init(template: template, map: map),
            composition: .init(recipe: recipe, tone: stage == "decide" ? "direct" : "exploratory"),
            guidance: .init(
                intensity: intensity,
                suggestionDensity: intensity == "immersive" ? 5 : intensity == "active" ? 3 : intensity == "light" ? 2 : 0,
                foregroundAttributes: foreground,
                promptPlacement: intensity == "minimal" ? "none" : level == .blocking || level == .immersive ? "leading" : "inline",
                usherCopy: stage == "decide" ? "Review the strongest current options." : "A few directions to help you explore."
            )
        )
    }
}

struct EmbeddedSearchResult {
    var state: AgentState
    var trace: EmbeddedDecisionTrace
    var retrievedItems: [String: Int] = [:]
    var sourceErrors: [String: String] = [:]
    var provenance: [String] = []
}

struct EmbeddedProviderOutcome<Value: Sendable>: Sendable {
    var value: Value
    var error: String?
    var provenance: String?
}

struct EmbeddedSearchAgent: Sendable {
    var intentProvider: any EmbeddedIntentProviding
    var inspirationProvider: any EmbeddedInspirationProviding
    var lodgingProvider: any EmbeddedLodgingProviding
    var flightProvider: any EmbeddedFlightProviding
    var destinationProvider: any EmbeddedDestinationProviding
    var activityProvider: any EmbeddedActivityProviding
    var pageComposer: EmbeddedPageComposer

    init(
        intentProvider: any EmbeddedIntentProviding = EmbeddedLiveProviderFactory.intentProvider(),
        inspirationProvider: any EmbeddedInspirationProviding = EmbeddedLiveProviderFactory.inspirationProvider(),
        lodgingProvider: (any EmbeddedLodgingProviding)? = nil,
        flightProvider: (any EmbeddedFlightProviding)? = nil,
        destinationProvider: (any EmbeddedDestinationProviding)? = nil,
        activityProvider: (any EmbeddedActivityProviding)? = nil,
        pageComposer: EmbeddedPageComposer = EmbeddedPageComposer()
    ) {
        let direct = DirectMCPProviderFactory.providers()
        self.intentProvider = intentProvider
        self.inspirationProvider = inspirationProvider
        self.lodgingProvider = lodgingProvider ?? direct.0
        self.flightProvider = flightProvider ?? direct.1
        self.destinationProvider = destinationProvider ?? direct.2
        self.activityProvider = activityProvider ?? direct.3
        self.pageComposer = pageComposer
    }

    func run(
        query: String,
        continuation: SearchContinuation?,
        newEvents: [ContinuationEvent]
    ) async throws -> EmbeddedSearchResult {
        let retained = continuation?.intentEvents.map(\.intentEvent) ?? []
        let supplied = newEvents.map(\.intentEvent)
        let parsed = try await intentProvider.parse(
            query: query,
            previousEvents: retained + supplied,
            previousQuerySummary: continuation?.querySummary
        )
        let allEvents = retained + supplied + parsed.events
        let compiled = EmbeddedIntentCompiler.compile(events: allEvents, query: query)
        var intent = EmbeddedRetrievalPolicy.enriched(compiled, query: query)
        if intent.relationship == "package",
           intent.destinations.count == 1,
           let resolved = try? await destinationProvider.search(intent: intent, query: query).first {
            intent.destinations = [resolved.name]
        }
        async let lodgingReady = lodgingProvider.readiness()
        async let flightReady = flightProvider.readiness()
        async let destinationReady = destinationProvider.readiness()
        async let activityReady = activityProvider.readiness()
        let readiness = await (lodgingReady, flightReady, destinationReady, activityReady)
        var trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: readiness.0,
            flightAvailable: readiness.1,
            destinationAvailable: readiness.2,
            activityAvailable: readiness.3
        )
        async let lodging = retrieveLodging(ifReadyIn: trace, intent: intent, summary: parsed.querySummary)
        async let flights = retrieveFlights(ifReadyIn: trace, intent: intent)
        async let destinations = retrieveDestinations(ifReadyIn: trace, intent: intent, query: query)
        async let activities = retrieveActivities(ifReadyIn: trace, intent: intent)
        let items = await (lodging, flights, destinations, activities)
        let errors = [
            "lodging": items.0.error,
            "flight": items.1.error,
            "destination": items.2.error,
            "activity": items.3.error,
        ].compactMapValues { $0 }
        for source in errors.keys {
            if let index = trace.sourcing.tasks.firstIndex(where: { $0.source == source }) {
                trace.sourcing.tasks[index].readiness = .unavailable
            }
        }
        if let packageIndex = trace.sourcing.tasks.firstIndex(where: { $0.source == "package" }),
           errors["lodging"] != nil || errors["flight"] != nil {
            trace.sourcing.tasks[packageIndex].readiness = .unavailable
        }
        let resultSurface = EmbeddedSurfaceBuilder.results(
            intent: intent,
            trace: trace,
            lodging: items.0.value,
            flights: items.1.value,
            destinations: items.2.value,
            activities: items.3.value,
            sourceErrors: errors
        )
        let pageSpec = try await pageComposer.compose(
            intent: intent,
            semanticIntent: compiled,
            trace: trace,
            querySummary: parsed.querySummary,
            lodging: items.0.value,
            flights: items.1.value,
            destinations: items.2.value,
            activities: items.3.value
        )
        let template: TemplateType = trace.template.template == "clarification" ? .clarification
            : trace.template.template == "comparison" ? .comparisonTable
            : trace.template.template == "itinerary-package" ? .packageOverview
            : trace.template.template == "destination-carousel" ? .destinationCarousel
            : trace.composition.recipe == "flight" ? .flightList
            : trace.composition.recipe == "activity" ? .activitiesSearch
            : trace.composition.recipe == "grouped-lodging" ? .lodgingGroups : .lodgingList
        return EmbeddedSearchResult(
            state: AgentState(
                surfaces: [
                    "header-bar": SurfaceState(components: EmbeddedSurfaceBuilder.header(intent: intent, refinements: [])),
                    "search-results": SurfaceState(components: resultSurface),
                ],
                pageSpec: pageSpec,
                intentEvents: allEvents,
                sessionId: continuation?.sessionId ?? UUID().uuidString,
                template: template,
                querySummary: parsed.querySummary
            ),
            trace: trace,
            retrievedItems: [
                "lodging": items.0.value.count,
                "flight": items.1.value.count,
                "destination": items.2.value.count,
                "activity": items.3.value.count,
            ],
            sourceErrors: errors,
            provenance: [items.0.provenance, items.1.provenance, items.2.provenance, items.3.provenance].compactMap { $0 }
        )
    }

    private func retrieveLodging(ifReadyIn trace: EmbeddedDecisionTrace, intent: EmbeddedIntent, summary: String) async -> EmbeddedProviderOutcome<[EmbeddedLodging]> {
        guard trace.sourcing.tasks.contains(where: { $0.source == "lodging" && $0.readiness == .ready }) else {
            return .init(value: [])
        }
        do {
            let value = try await lodgingProvider.search(intent: intent, summary: summary)
            return .init(value: value, provenance: value.first?.dataSource)
        } catch {
            return .init(value: [], error: Self.diagnostic(error))
        }
    }

    private func retrieveFlights(ifReadyIn trace: EmbeddedDecisionTrace, intent: EmbeddedIntent) async -> EmbeddedProviderOutcome<[EmbeddedFlight]> {
        guard trace.sourcing.tasks.contains(where: { $0.source == "flight" && $0.readiness == .ready }) else {
            return .init(value: [])
        }
        do {
            let value = try await flightProvider.search(intent: intent)
            return .init(value: value, provenance: value.first?.dataSource)
        } catch {
            return .init(value: [], error: Self.diagnostic(error))
        }
    }

    private func retrieveDestinations(ifReadyIn trace: EmbeddedDecisionTrace, intent: EmbeddedIntent, query: String) async -> EmbeddedProviderOutcome<[EmbeddedDestination]> {
        guard trace.sourcing.tasks.contains(where: { $0.source == "destination" && $0.readiness == .ready }) else {
            return .init(value: [])
        }
        do {
            let grounded = try await destinationProvider.search(intent: intent, query: query)
            let value: [EmbeddedDestination]
            if inspirationProvider.configured {
                let ranked = try await inspirationProvider.suggest(
                    intent: intent,
                    query: "\(query)\nGrounded candidates: \(grounded.map(\.name).joined(separator: ", "))"
                )
                let groundedByName = Dictionary(
                    grounded.map { ($0.name.lowercased(), $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                value = ranked.compactMap { candidate in
                    guard var item = groundedByName[candidate.name.lowercased()] else { return nil }
                    item.rationale = candidate.description
                    item.highlights = candidate.highlights
                    return item
                }
            } else {
                value = grounded
            }
            let ranked = value.isEmpty ? grounded : value
            let priced = await priceDestinations(Array(ranked.prefix(4)), baseIntent: intent)
            return .init(value: priced, provenance: priced.first?.dataSource)
        } catch {
            return .init(value: [], error: Self.diagnostic(error))
        }
    }

    private func retrieveActivities(
        ifReadyIn trace: EmbeddedDecisionTrace,
        intent: EmbeddedIntent
    ) async -> EmbeddedProviderOutcome<[EmbeddedActivity]> {
        guard trace.sourcing.tasks.contains(where: { $0.source == "activity" && $0.readiness == .ready }) else {
            return .init(value: [])
        }
        do {
            let value = try await activityProvider.search(intent: intent)
            return .init(value: value, provenance: value.first?.dataSource)
        } catch {
            return .init(value: [], error: Self.diagnostic(error))
        }
    }

    private static func diagnostic(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return String(describing: error)
    }

    private func priceDestinations(
        _ destinations: [EmbeddedDestination],
        baseIntent: EmbeddedIntent
    ) async -> [EmbeddedDestination] {
        await withTaskGroup(of: (Int, EmbeddedDestination).self) { group in
            for (index, destination) in destinations.enumerated() {
                group.addTask {
                    var item = destination
                    var candidateIntent = baseIntent
                    candidateIntent.destinations = [destination.name]
                    if candidateIntent.originAirport == nil {
                        candidateIntent.originAirport = EmbeddedRetrievalPolicy.prototypeOrigin
                    }
                    do {
                        async let stays = lodgingProvider.search(
                            intent: candidateIntent,
                            summary: destination.name
                        )
                        async let flights = flightProvider.search(intent: candidateIntent)
                        let values = try await (stays, flights)
                        if let stay = values.0.min(by: { $0.total < $1.total }),
                           let flight = values.1.min(by: { $0.total < $1.total }) {
                            item.packageFrom = stay.total + flight.total
                        }
                    } catch {
                        // Destination content remains useful when optional pricing fails.
                    }
                    return (index, item)
                }
            }
            var values: [(Int, EmbeddedDestination)] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

enum EmbeddedIntentCompiler {
    static func compile(events: [IntentEvent], query: String) -> EmbeddedIntent {
        var intent = EmbeddedIntent()
        for event in events {
            guard let field = event.field else { continue }
            if event.type == .retraction {
                retract(field, from: &intent)
                continue
            }
            guard let value = event.newValue else { continue }
            switch field {
            case "destinations": intent.destinations = value.arrayValue?.compactMap(\.stringValue) ?? []
            case "goal": intent.goal = value.stringValue.flatMap(EmbeddedGoal.init) ?? intent.goal
            case "productScope":
                let scope = value.objectValue
                intent.products = scope?["included"]?.arrayValue?.compactMap { $0.stringValue.flatMap(EmbeddedProduct.init) } ?? intent.products
                intent.relationship = scope?["relationship"]?.stringValue ?? intent.relationship
            case "departureDate": intent.departureDate = value.stringValue
            case "returnDate": intent.returnDate = value.stringValue
            case "originAirport": intent.originAirport = value.stringValue
            case "adults": intent.adults = Int(value.doubleValue ?? 1)
            case "children": intent.children = value.arrayValue?.compactMap { $0.doubleValue.map(Int.init) } ?? []
            case "totalBudget": intent.totalBudget = value.objectValue?["amount"]?.doubleValue
            case "amenities": intent.amenities = value.arrayValue?.compactMap(\.stringValue) ?? []
            case "travelStyle": intent.travelStyle = value.arrayValue?.compactMap(\.stringValue) ?? []
            case "flightClass": intent.flightClass = value.stringValue
            default: break
            }
        }
        return intent
    }

    private static func retract(_ field: String, from intent: inout EmbeddedIntent) {
        switch field {
        case "destinations": intent.destinations = []
        case "departureDate": intent.departureDate = nil
        case "returnDate": intent.returnDate = nil
        case "originAirport": intent.originAirport = nil
        case "totalBudget": intent.totalBudget = nil
        case "amenities": intent.amenities = []
        default: break
        }
    }
}

enum EmbeddedSurfaceBuilder {
    static func header(intent: EmbeddedIntent, refinements: [String]) -> [A2UIComponent] {
        var primary: [JSONValue] = []
        if let departure = intent.departureDate {
            primary.append(.object(["field": .string("departureDate"), "label": .string(dateRangeLabel(departure, intent.returnDate)), "type": .string("set"), "tier": .string("primary")]))
        } else {
            primary.append(.object(["field": .string("departureDate"), "label": .string("Dates"), "type": .string("missing"), "tier": .string("primary")]))
        }
        primary.append(.object(["field": .string("adults"), "label": .string("\(intent.adults) adult\(intent.adults == 1 ? "" : "s")"), "type": .string("set"), "tier": .string("primary")]))
        var secondary: [JSONValue] = []
        if let budget = intent.totalBudget {
            secondary.append(.object(["field": .string("totalBudget"), "label": .string("$\(Int(budget)) total"), "type": .string("set"), "tier": .string("secondary")]))
        }
        if !intent.amenities.isEmpty {
            secondary.append(.object(["field": .string("amenities"), "label": .string(intent.amenities.joined(separator: ", ")), "type": .string("set"), "tier": .string("secondary")]))
        }
        return [A2UIComponent(id: "constraint-bar", type: "constraint-bar", props: [
            "primary": .array(primary), "secondary": .array(secondary),
            "refinements": .array(refinements.map(JSONValue.string)),
        ])]
    }

    static func results(
        intent: EmbeddedIntent,
        trace: EmbeddedDecisionTrace,
        lodging: [EmbeddedLodging],
        flights: [EmbeddedFlight],
        destinations: [EmbeddedDestination],
        activities: [EmbeddedActivity] = [],
        sourceErrors: [String: String] = [:]
    ) -> [A2UIComponent] {
        var components: [A2UIComponent] = [
            A2UIComponent(id: "guidance-usher", type: "section-heading", props: [
                "text": .string(trace.guidance.usherCopy),
                "tone": .string(trace.composition.tone),
                "intensity": .string(trace.guidance.intensity),
                "decisionTrace": trace.json,
            ]),
        ]
        if trace.composition.recipe == "capability" {
            components.insert(capability(), at: 0)
            return components
        }
        if trace.composition.recipe == "clarification" {
            components.insert(capability(), at: 0)
            return components
        }
        let hasItems = !lodging.isEmpty || !flights.isEmpty || !destinations.isEmpty || !activities.isEmpty
        if !hasItems {
            if sourceErrors.isEmpty {
                components.insert(
                    capability(
                        title: "No provider results",
                        message: "The configured source returned no usable inventory for this search."
                    ),
                    at: 0
                )
            } else {
                for (source, message) in sourceErrors.sorted(by: { $0.key < $1.key }).reversed() {
                    components.insert(
                        capability(
                            title: "\(source.capitalized) results unavailable",
                            message: message
                        ),
                        at: 0
                    )
                }
            }
            return components
        }
        if trace.composition.recipe == "comparison" {
            components.append(comparison(lodging))
        } else if trace.composition.recipe == "package" {
            let packageOptions = packages(intent: intent, lodging: lodging, flights: flights)
            if packageOptions.isEmpty {
                if !lodging.isEmpty { components.append(contentsOf: lodgingCards(lodging)) }
                if !flights.isEmpty { components.append(contentsOf: flightCards(flights)) }
            } else {
                components.append(contentsOf: packageOptions)
            }
        } else {
            if !destinations.isEmpty { components.append(contentsOf: destinationCards(destinations)) }
            if !lodging.isEmpty { components.append(contentsOf: lodgingCards(lodging)) }
            if !flights.isEmpty { components.append(contentsOf: flightCards(flights)) }
            if !activities.isEmpty { components.append(contentsOf: activityCards(activities)) }
        }
        let pins = lodging.compactMap { item -> JSONValue? in
            guard let latitude = item.latitude, let longitude = item.longitude,
                  validCoordinate(latitude: latitude, longitude: longitude) else { return nil }
            return .object([
                "id": .string(item.id), "lat": .number(latitude), "lng": .number(longitude), "label": .string(item.name),
            ])
        }
        if trace.template.map == "results", !pins.isEmpty {
            components.append(A2UIComponent(id: "results-map", type: "map-view", props: ["pins": .array(pins), "zoom": .number(11)]))
        }
        for (source, message) in sourceErrors.sorted(by: { $0.key < $1.key }) {
            components.append(capability(
                title: "\(source.capitalized) results unavailable",
                message: message
            ))
        }
        return components
    }

    static func compositionItems(
        intent: EmbeddedIntent,
        trace: EmbeddedDecisionTrace,
        lodging: [EmbeddedLodging],
        flights: [EmbeddedFlight],
        destinations: [EmbeddedDestination],
        activities: [EmbeddedActivity]
    ) -> [A2UIComponent] {
        switch trace.composition.recipe {
        case "capability", "clarification", "comparison":
            return []
        case "package":
            let packageOptions = packages(intent: intent, lodging: lodging, flights: flights)
            if !packageOptions.isEmpty { return packageOptions }
            return lodgingCards(lodging) + flightCards(flights)
        default:
            return destinationCards(destinations) + lodgingCards(lodging) + flightCards(flights) + activityCards(activities)
        }
    }

    private static func dateRangeLabel(_ departure: String, _ returning: String?) -> String {
        let input = DateFormatter()
        input.calendar = Calendar(identifier: .gregorian)
        input.locale = Locale(identifier: "en_US_POSIX")
        input.timeZone = TimeZone(secondsFromGMT: 0)
        input.dateFormat = "yyyy-MM-dd"
        let output = DateFormatter()
        output.calendar = input.calendar
        output.locale = input.locale
        output.timeZone = input.timeZone
        output.dateFormat = "MMM d"
        guard let start = input.date(from: departure) else {
            return [departure, returning].compactMap { $0 }.joined(separator: " – ")
        }
        guard let returning, let end = input.date(from: returning) else {
            return output.string(from: start)
        }
        return "\(output.string(from: start)) – \(output.string(from: end))"
    }

    private static func validCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }

    private static func capability(
        title: String = "This search path is unavailable",
        message: String = "No configured embedded provider can safely complete this request."
    ) -> A2UIComponent {
        A2UIComponent(id: "capability-search", type: "capability-state", props: [
            "product": .string("search"), "title": .string(title),
            "message": .string(message),
            "available": .bool(false), "fixture": .bool(false),
        ])
    }

    private static func clarifications(_ actions: [EmbeddedAction]) -> [A2UIComponent] {
        actions.filter { $0.type != "skip" }.map { action in
            var props: [String: JSONValue] = [
                "field": .string(action.field), "action": .string(action.type),
                "question": .string(question(action.field)), "reason": .string(action.reason),
                "required": .bool(action.type == "ask-blocking"),
            ]
            if let suggestion = action.suggestion {
                props["suggestion"] = suggestion
                props["suggestionLabel"] = .string("Suggested")
            }
            return A2UIComponent(id: "clarification-\(action.field)", type: "clarification", props: props)
        }
    }

    private static func question(_ field: String) -> String {
        switch field {
        case "departureDate", "returnDate": return "Are these travel dates right?"
        case "originAirport": return "Where will you be traveling from?"
        case "destinations": return "Where would you like to go?"
        default: return "What should we use for \(field)?"
        }
    }

    private static func lodgingCards(_ items: [EmbeddedLodging]) -> [A2UIComponent] {
        items.map { item in
            var props: [String: JSONValue] = [
                "id": .string(item.id), "name": .string(item.name), "location": .string(item.location),
                "amenities": .array(item.amenities.map { .object(["text": .string($0)]) }),
                "priceNightly": .string("$\(Int(item.nightly))"), "priceTotal": .string("$\(Int(item.total))"),
                "reviewScore": .number(item.rating), "reviewCount": .number(Double(item.reviews)),
                "refundableLabel": .string(item.refundable ? "Fully refundable" : ""),
                "dataSource": .string(item.dataSource), "provisional": .bool(item.dataSource != "authoritative"),
            ]
            if let imageURL = item.imageURL { props["imageUrl"] = .string(imageURL) }
            return A2UIComponent(id: "lodging-\(item.id)", type: "lodging-card", props: props)
        }
    }

    private static func flightCards(_ items: [EmbeddedFlight]) -> [A2UIComponent] {
        items.map { item in
            A2UIComponent(id: "flight-\(item.id)", type: "flight-card", props: [
                "id": .string(item.id), "airline": .string(item.airline), "flightNumber": .string(item.number),
                "origin": .string(item.origin), "destination": .string(item.destination),
                "departureTime": .string(item.departure), "arrivalTime": .string(item.arrival),
                "durationMinutes": .number(Double(item.duration)), "price": .number(item.price),
                "totalPrice": .number(item.total), "currency": .string("USD"), "stops": .number(Double(item.stops)),
                "class": .string(item.cabin), "bagsIncluded": .string("1 carry-on"),
                "dataSource": .string(item.dataSource), "provisional": .bool(item.dataSource != "authoritative"),
                "priceBasis": .string(item.dataSource == "authoritative" ? "Live offer" : "Fixture fare"),
            ])
        }
    }

    private static func destinationCards(_ items: [EmbeddedDestination]) -> [A2UIComponent] {
        items.map { item in
            var props: [String: JSONValue] = [
                "id": .string(item.id), "name": .string(item.name), "country": .string(item.country),
                "description": .string(item.description), "highlights": .array(item.highlights.map(JSONValue.string)),
                "dataSource": .string(item.dataSource),
                "currency": .string(item.currency),
            ]
            if let imageURL = item.imageURL { props["imageUrl"] = .string(imageURL) }
            if let airportCode = item.airportCode { props["airportCode"] = .string(airportCode) }
            if let rationale = item.rationale { props["rationale"] = .string(rationale) }
            if let packageFrom = item.packageFrom { props["packageFrom"] = .number(packageFrom) }
            return A2UIComponent(id: "destination-\(item.id)", type: "destination-card", props: props)
        }
    }

    private static func activityCards(_ items: [EmbeddedActivity]) -> [A2UIComponent] {
        items.map { item in
            var props: [String: JSONValue] = [
                "id": .string(item.id),
                "name": .string(item.name),
                "description": .string(item.description),
                "highlights": .array(item.highlights.map(JSONValue.string)),
                "currency": .string(item.currency),
                "dataSource": .string(item.dataSource),
            ]
            if let price = item.price { props["price"] = .number(price) }
            if let formattedPrice = item.formattedPrice { props["formattedPrice"] = .string(formattedPrice) }
            if let rating = item.rating { props["reviewScore"] = .number(rating) }
            if let reviews = item.reviews { props["reviewCount"] = .number(Double(reviews)) }
            if let imageURL = item.imageURL { props["imageUrl"] = .string(imageURL) }
            return A2UIComponent(id: "activity-\(item.id)", type: "activity-card", props: props)
        }
    }

    private static func comparison(_ items: [EmbeddedLodging]) -> A2UIComponent {
        let candidates = Array(items.prefix(3))
        let headers = ["Fact"] + candidates.map(\.name)
        func row(_ fact: String, _ values: [String]) -> JSONValue {
            var object = ["fact": JSONValue.string(fact)]
            for (index, candidate) in candidates.enumerated() { object[candidate.id] = .string(values[index]) }
            return .object(object)
        }
        return A2UIComponent(id: "comparison", type: "comparison-table", props: [
            "title": .string("Stay comparison"), "headers": .array(headers.map(JSONValue.string)),
            "rows": .array([
                row("Total price", candidates.map { "$\(Int($0.total))" }),
                row("Location", candidates.map(\.location)),
                row("Guest rating", candidates.map { String($0.rating) }),
                row("Cancellation", candidates.map { $0.refundable ? "Refundable option shown" : "Unknown" }),
            ]),
            "candidateIds": .array(candidates.map { .string($0.id) }), "unknownLabel": .string("Unknown"),
            "dataSource": .string(candidates.allSatisfy { $0.dataSource == "authoritative" } ? "authoritative" : "fixture"),
        ])
    }

    private static func packages(intent: EmbeddedIntent, lodging: [EmbeddedLodging], flights: [EmbeddedFlight]) -> [A2UIComponent] {
        guard let flight = flights.min(by: { $0.total < $1.total }),
              let departure = intent.departureDate,
              let returning = intent.returnDate else { return [] }
        return lodging.sorted { $0.total < $1.total }.prefix(5).enumerated().map { index, stay in
            let total = stay.total + flight.total
            let authoritative = stay.dataSource == "authoritative" && flight.dataSource == "authoritative"
            var props: [String: JSONValue] = [
                "id": .string("package-\(stay.id)"),
                "title": .string(stay.name),
                "area": .string(stay.location),
                "destination": .string(intent.destinations.joined(separator: ", ")),
                "airportCodes": .array([.string(flight.destination)]),
                "currency": .string("USD"),
                "flightTotal": .number(flight.total),
                "packageFrom": .number(total),
                "fitCount": .number(1),
                "priceBasis": .string("Live flight and stay total"),
                "dataSource": .string(authoritative ? "authoritative" : "fixture"),
                "departureDate": .string(departure),
                "returnDate": .string(returning),
                "rationale": .string(stay.amenities.prefix(2).joined(separator: " · ")),
                "highlights": .array(stay.amenities.map(JSONValue.string)),
            ]
            if let imageURL = stay.imageURL { props["imageUrl"] = .string(imageURL) }
            return A2UIComponent(id: "package-\(index)-\(stay.id)", type: "package-summary", props: props)
        }
    }
}

@MainActor
struct EmbeddedGenUIDataSource: GenUIDataSourceProviding {
    var agent: EmbeddedSearchAgent

    init(
        agent: EmbeddedSearchAgent = EmbeddedSearchAgent(
            pageComposer: EmbeddedPageComposer(
                copyGenerator: EmbeddedLiveProviderFactory.sectionCopyGenerator()
            )
        )
    ) {
        self.agent = agent
    }

    func response(
        for query: String,
        continuation: SearchContinuation? = nil,
        intentEvents: [ContinuationEvent] = []
    ) async throws -> AssistantResponse {
        let result = try await agent.run(query: query, continuation: continuation, newEvents: intentEvents)
        return try AgentStateMapper.map(state: result.state, query: query)
    }
}
