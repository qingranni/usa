import Foundation

struct EmbeddedGPTConfiguration: Sendable {
    var apiKey: String
    var model: String
    var baseURL: URL = URL(string: "https://api.openai.com/v1")!
    var timeout: TimeInterval = 30

    var configured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var endpoint: URL {
        if baseURL.path.hasSuffix("/chat/completions") { return baseURL }
        return baseURL.appending(path: "chat/completions")
    }
}

enum EmbeddedGPTProviderError: Error, Equatable, LocalizedError {
    case notConfigured
    case invalidConfiguration
    case transport(String)
    case httpStatus(Int)
    case missingContent
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "GPT is not configured."
        case .invalidConfiguration:
            return "GPT endpoint configuration is invalid."
        case .transport(let message):
            return "GPT transport failed: \(message)"
        case .httpStatus(let status):
            return "GPT returned HTTP \(status)."
        case .missingContent:
            return "GPT returned no structured content."
        case .invalidResponse:
            return "GPT returned an invalid structured response."
        }
    }
}

final class GPTPrototypeTLSDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    let prototypeTrustEnabled: Bool
    let trustedHost: String?

    init(prototypeTrustEnabled: Bool, trustedHost: String?) {
        self.prototypeTrustEnabled = prototypeTrustEnabled
        self.trustedHost = trustedHost
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        #if DEBUG
        if prototypeTrustEnabled,
           challenge.protectionSpace.host == trustedHost,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        #endif
        completionHandler(.performDefaultHandling, nil)
    }
}

enum EmbeddedGPTSessionFactory {
    static func session(
        for configuration: EmbeddedGPTConfiguration,
        enablePrototypeTrust: Bool
    ) -> URLSession {
        #if DEBUG
        let enabled = enablePrototypeTrust
        #else
        let enabled = false
        #endif
        let delegate = GPTPrototypeTLSDelegate(
            prototypeTrustEnabled: enabled,
            trustedHost: configuration.endpoint.host
        )
        return URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
    }
}

enum EmbeddedGPTRequest {
    static func send(
        configuration: EmbeddedGPTConfiguration,
        session: URLSession,
        schema: [String: Any],
        messages: [[String: String]]
    ) async throws -> Any {
        guard configuration.configured else { throw EmbeddedGPTProviderError.notConfigured }
        guard configuration.endpoint.scheme == "https" || configuration.endpoint.host == "localhost" else {
            throw EmbeddedGPTProviderError.invalidConfiguration
        }

        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": configuration.model,
            "messages": messages,
            "response_format": [
                "type": "json_schema",
                "json_schema": schema,
            ],
        ])

        let data: Data
        let response: URLResponse
        do {
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request)
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw EmbeddedGPTProviderError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw EmbeddedGPTProviderError.httpStatus(http.statusCode)
        }
        guard
            let envelope = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = envelope["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.isEmpty
        else {
            throw EmbeddedGPTProviderError.missingContent
        }
        guard let contentData = content.data(using: .utf8) else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        do {
            return try JSONSerialization.jsonObject(with: contentData)
        } catch {
            throw EmbeddedGPTProviderError.invalidResponse
        }
    }
}

protocol ComposerRouting: Sendable {
    var configured: Bool { get }
    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult
}

struct GPTComposerRouter: ComposerRouting, @unchecked Sendable {
    let configuration: EmbeddedGPTConfiguration
    let session: URLSession

    var configured: Bool { configuration.configured }

    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult {
        let contextObject: [String: Any] = [
            "surface": context.surface.rawValue,
            "threadId": context.threadID ?? "",
            "title": context.title ?? "",
            "summary": context.summary ?? "",
            "filters": context.filters,
            "results": context.results,
            "messages": context.messages.suffix(8).map {
                ["role": $0.role.rawValue, "text": $0.text]
            },
            "query": query,
        ]
        let input = String(
            decoding: try JSONSerialization.data(withJSONObject: contextObject),
            as: UTF8.self
        )
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.schema,
            messages: [
                ["role": "system", "content": Self.instructions],
                ["role": "user", "content": input],
            ]
        )
        guard let object = value as? [String: Any],
              let rawRoute = object["route"] as? String,
              let route = ComposerRoute(rawValue: rawRoute),
              let title = object["title"] as? String,
              let answer = object["answer"] as? String else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleanAnswer = Self.capped(answer.trimmingCharacters(in: .whitespacesAndNewlines))

        // Mirror of the "no '?' → never chat" rule enforced in
        // `FallbackComposerRouter.gated`: a query that literally contains "?" is
        // always a conversational turn. The model occasionally mis-routes a plain
        // question to a search route, which would dead-end in the structured
        // pipeline with no data (and, mid-launch, tear the canvas down). Coerce it
        // back to chat and, if the routing pass left the answer empty, make one
        // focused call to produce it.
        var finalRoute = route
        if query.contains("?"), route != .question, route != .continueConversation {
            finalRoute = (context.surface == .conversation || context.surface == .inlineAnswer)
                ? .continueConversation : .question
            if cleanAnswer.isEmpty {
                cleanAnswer = try await forcedAnswer(input: input)
            }
        }

        if finalRoute == .question || finalRoute == .continueConversation {
            guard !cleanAnswer.isEmpty else { throw EmbeddedGPTProviderError.invalidResponse }
        }
        return ComposerRoutingResult(route: finalRoute, title: cleanTitle, answer: cleanAnswer)
    }

    /// One focused call that produces only a conversational answer, used when a
    /// "?" query was coerced to chat but the routing pass returned an empty
    /// answer. Same voice and length cap as the routing instructions.
    private func forcedAnswer(input: String) async throws -> String {
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.answerSchema,
            messages: [
                ["role": "system", "content": Self.answerInstructions],
                ["role": "user", "content": input],
            ]
        )
        guard let object = value as? [String: Any],
              let answer = object["answer"] as? String else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        let clean = Self.capped(answer.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !clean.isEmpty else { throw EmbeddedGPTProviderError.invalidResponse }
        return clean
    }

    /// Maximum length of a single-turn conversational answer.
    static let answerCharacterLimit = 550

    /// Hard-caps an answer to `answerCharacterLimit`, trimming at a word
    /// boundary so we never cut mid-word. Acts as a safety net behind the
    /// model instruction to keep answers concise.
    static func capped(_ answer: String) -> String {
        guard answer.count > answerCharacterLimit else { return answer }
        let truncated = answer.prefix(answerCharacterLimit)
        if let lastSpace = truncated.lastIndex(of: " ") {
            return truncated[..<lastSpace].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(truncated).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let instructions = """
    You route input from a travel app composer and answer conversational turns.
    Return one route:
    - question: a factual, explanatory, advisory, or conversational request. Use ONLY when the input literally contains a question mark ("?"). If there is no "?", never use question — pick newSearch (or, on results, the matching action route) instead.
    - continueConversation: a reply to the inline answer or open conversation. Use ONLY when the input literally contains a question mark ("?"); if there is no "?", route the turn through newSearch/refine/compare/map instead, even inside a conversation.
    - refine: modify or narrow the currently open results while preserving their core destination/product.
    - compare: compare, rank, or choose among current options.
    - map: show or discuss current option locations, distance, neighborhoods, or directions.
    - newSearch: request a new destination, product, or materially different result set.

    On home, use question for informational travel questions and newSearch for requests to find inventory or trip ideas.
    Without current results, never return refine. Without an existing answer/chat, never return continueConversation.
    For question and continueConversation, answer as an upbeat, in-the-know travel guide — the context here is planning a Mexico beach spring-break trip (Cancún, Puerto Vallarta, Playa del Carmen), so lean into that vibe, but stay helpful for any destination the user raises.
    Be fun, warm, and genuinely useful: give confident, concrete guidance drawn from general travel knowledge — typical seasonal weather, what to pack, the feel and best-for of each spot, and things to do. Keep it lively, not a lecture. Under 550 characters.
    Never say you lack live/real-time/weather data, never hedge about missing context, and never ask the user to confirm dates before helping — just answer with typical, seasonally-appropriate advice. Do not fabricate specific facts (exact live prices or forecasts) about the supplied properties.
    Markdown bold (**text**) may emphasize at most two important phrases. Generate a short descriptive conversation title.
    For all non-conversation routes, return empty title and answer strings.
    """

    private static let answerInstructions = """
    The user typed a travel question into the app composer. Answer it directly as
    an upbeat, in-the-know travel guide — the context is planning a Mexico beach
    spring-break trip (Cancún, Puerto Vallarta, Playa del Carmen), so lean into
    that vibe but stay helpful for any destination raised. Be fun, warm, and
    concrete: typical seasonal weather, what to pack, the feel and best-for of each
    spot, things to do. Keep it lively, not a lecture. Never say you lack
    live/real-time/weather data, never hedge about missing context, and never ask
    the user to confirm dates before helping — just answer with typical,
    seasonally-appropriate advice. Do not fabricate specific facts (exact live
    prices or forecasts). Markdown bold (**text**) may emphasize at most two
    phrases. Under 550 characters.
    """

    private static let answerSchema: [String: Any] = [
        "name": "composer_answer",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "answer": ["type": "string"],
            ],
            "required": ["answer"],
        ],
    ]

    private static let schema: [String: Any] = [
        "name": "composer_route",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "route": [
                    "type": "string",
                    "enum": [
                        "question", "continueConversation", "newSearch",
                        "refine", "compare", "map",
                    ],
                ],
                "title": ["type": "string"],
                "answer": ["type": "string"],
            ],
            "required": ["route", "title", "answer"],
        ],
    ]
}

struct DeterministicComposerRouter: ComposerRouting {
    let configured = true

    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult {
        let route = classify(query, context: context)
        return ComposerRoutingResult(
            route: route,
            title: route == .question || route == .continueConversation ? shortTitle(query) : "",
            answer: ""
        )
    }

    private func classify(_ query: String, context: ComposerContext) -> ComposerRoute {
        let value = query.lowercased()
        if matches(value, #"\b(compare|comparison|versus|vs\.?|which is|which one|better|best|rank)\b"#) {
            return .compare
        }
        if matches(value, #"\b(show (?:it |them )?on (?:a |the )?map|directions?|how far|distance|located|location|neighbou?rhood)\b"#) {
            return .map
        }
        if matches(value, #"\b(new search|start over|instead|somewhere else|another destination)\b"#) {
            return .newSearch
        }
        // Chat — single-turn (.question) or multi-turn (.continueConversation)
        // — is only reachable when the user actually typed a question, i.e.
        // the input contains a question mark. Interrogative-sounding phrasing
        // alone ("tell me about Tokyo") is treated as a search, not a chat
        // answer. Everything else falls through to the intent routes below.
        if query.contains("?") {
            if context.surface == .conversation || context.surface == .inlineAnswer {
                return .continueConversation
            }
            return .question
        }
        if context.surface == .results,
           matches(value, #"\b(make it|only|filter|cheaper|closer|with|without|under|at least|change (?:the )?dates?)\b"#) {
            return .refine
        }
        return .newSearch
    }

    private func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func shortTitle(_ query: String) -> String {
        let clean = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[?.!]+$"#, with: "", options: .regularExpression)
        return clean.split(separator: " ").prefix(6).joined(separator: " ")
    }
}

struct FallbackComposerRouter: ComposerRouting {
    let primary: any ComposerRouting
    let fallback: any ComposerRouting

    var configured: Bool { primary.configured || fallback.configured }

    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult {
        let result: ComposerRoutingResult
        if primary.configured {
            do {
                result = try await primary.route(query: query, context: context)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                result = try await fallback.route(query: query, context: context)
            }
        } else {
            result = try await fallback.route(query: query, context: context)
        }
        return Self.gated(result, query: query)
    }

    /// Enforces the product rule that an LLM chat response — single-turn
    /// (`.question`) or multi-turn (`.continueConversation`) — is only ever
    /// reachable when the user actually typed a question, i.e. the input
    /// contains a question mark. Every other input routes through the intent
    /// router and surface generation. This is the single guarantee point, so
    /// it holds no matter which underlying router produced the result.
    static func gated(_ result: ComposerRoutingResult, query: String) -> ComposerRoutingResult {
        let isChat = result.route == .question || result.route == .continueConversation
        guard isChat, !query.contains("?") else { return result }
        return ComposerRoutingResult(route: .newSearch, title: "", answer: "")
    }
}

struct GPTIntentProvider: EmbeddedIntentProviding, @unchecked Sendable {
    private static let fields = [
        "goal", "productScope", "emotionalRegister", "referencePoint", "searchMode",
        "destinations", "destinationCoordinates", "departureDate", "returnDate", "flexibility",
        "tripDurationDays", "adults", "children", "totalBudget", "perNightBudget", "flightClass",
        "maxStops", "preferredAirlines", "originAirport", "tripType", "starRating", "amenities",
        "accommodationType", "travelStyle", "priorities",
    ]

    let configuration: EmbeddedGPTConfiguration
    let session: URLSession
    var configured: Bool { configuration.configured }

    init(configuration: EmbeddedGPTConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func parse(
        query: String,
        previousEvents: [IntentEvent],
        previousQuerySummary: String?
    ) async throws -> EmbeddedIntentParseResult {
        let input: String
        if previousEvents.isEmpty {
            input = query
        } else {
            let context = previousEvents.compactMap(Self.eventContext)
            let contextData = try JSONSerialization.data(withJSONObject: context)
            let contextJSON = String(decoding: contextData, as: UTF8.self)
            input = "Previous summary: \(previousQuerySummary ?? "")\nPrevious events: \(contextJSON)\nUser refinement: \(query)"
        }
        let today = Date.ISO8601FormatStyle().year().month().day().format(Date())
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.schema,
            messages: [
                ["role": "system", "content": Self.instructions(today: today)],
                ["role": "user", "content": input],
            ]
        )
        return try Self.parse(value, rawInput: query, refinement: !previousEvents.isEmpty)
    }

    private static func eventContext(_ event: IntentEvent) -> [String: Any]? {
        guard let field = event.field else { return nil }
        var result: [String: Any] = ["field": field, "type": event.type.rawValue]
        if let value = event.newValue { result["newValue"] = foundationValue(value) }
        return result
    }

    private static func parse(_ value: Any, rawInput: String, refinement: Bool) throws -> EmbeddedIntentParseResult {
        guard
            let object = value as? [String: Any],
            let rawEvents = object["events"] as? [[String: Any]],
            let summary = object["querySummary"] as? String,
            let suggestions = object["suggestions"] as? [Any],
            let refinements = object["refinements"] as? [Any]
        else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        let timestamp = Date().timeIntervalSince1970 * 1_000
        let events = try rawEvents.enumerated().map { index, item -> IntentEvent in
            guard
                let field = item["field"] as? String, fields.contains(field),
                let valueJSON = item["valueJSON"] as? String,
                let valueData = valueJSON.data(using: .utf8),
                let rawValue = try? JSONSerialization.jsonObject(with: valueData, options: [.fragmentsAllowed]),
                valid(rawValue, for: field),
                let strengthString = item["strength"] as? String,
                let sourceString = item["source"] as? String,
                let confidence = item["confidence"] as? Double
            else {
                throw EmbeddedGPTProviderError.invalidResponse
            }
            return IntentEvent(
                id: UUID().uuidString,
                type: refinement ? .refinement : .inference,
                timestamp: timestamp + Double(index),
                field: field,
                newValue: jsonValue(rawValue),
                strength: strengthString == "hard" ? .hard : .soft,
                source: sourceString == "user" ? .user : .agent,
                confidence: min(1, max(0, confidence)),
                rawInput: rawInput,
                provenance: "gpt-schema"
            )
        }
        let cleanStrings: ([Any]) -> [String] = {
            $0.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return EmbeddedIntentParseResult(
            events: events,
            querySummary: summary.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))),
            suggestions: Array(cleanStrings(suggestions).prefix(8)),
            refinements: Array(cleanStrings(refinements).prefix(5))
        )
    }

    private static func valid(_ value: Any, for field: String) -> Bool {
        let strings = { (value: Any) in (value as? [Any])?.allSatisfy { $0 is String } == true }
        let number = { (value: Any) in value is NSNumber }
        switch field {
        case "goal": return ["find", "explore", "compare"].contains(value as? String)
        case "searchMode": return ["product-search", "explore"].contains(value as? String)
        case "emotionalRegister": return ["warm", "neutral", "flat"].contains(value as? String)
        case "destinations", "amenities", "preferredAirlines", "travelStyle", "priorities": return strings(value)
        case "children": return (value as? [Any])?.allSatisfy(number) == true
        case "adults", "tripDurationDays", "maxStops", "starRating": return number(value)
        case "departureDate", "returnDate":
            return (value as? String)?.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        case "destinationCoordinates":
            guard let point = value as? [String: Any] else { return false }
            return point["lat"].map(number) == true && point["lng"].map(number) == true
        case "totalBudget", "perNightBudget":
            guard let money = value as? [String: Any] else { return false }
            return money["amount"].map(number) == true && money["currency"] is String
        case "productScope":
            guard
                let scope = value as? [String: Any],
                let included = scope["included"] as? [String],
                included.allSatisfy({ $0 == "lodging" || $0 == "flight" || $0 == "activities" }),
                let relationship = scope["relationship"] as? String,
                ["single", "package", "sequence"].contains(relationship)
            else { return false }
            return scope["confidence"].map(number) == true
        case "referencePoint":
            guard let reference = value as? [String: Any] else { return false }
            return ["alternative-to", "similar-to"].contains(reference["type"] as? String)
                && reference["label"] is String
        default: return value is String
        }
    }

    private static let schema: [String: Any] = [
        "name": "travel_intent_events",
        "strict": true,
        "schema": [
            "type": "object", "additionalProperties": false,
            "properties": [
                "events": [
                    "type": "array",
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "properties": [
                            "field": ["type": "string", "enum": fields],
                            "valueJSON": ["type": "string", "description": "JSON encoding of the field value."],
                            "strength": ["type": "string", "enum": ["hard", "soft"]],
                            "source": ["type": "string", "enum": ["user", "agent"]],
                            "confidence": ["type": "number", "minimum": 0, "maximum": 1],
                        ],
                        "required": ["field", "valueJSON", "strength", "source", "confidence"],
                    ],
                ],
                "querySummary": ["type": "string"],
                "suggestions": ["type": "array", "items": ["type": "string"]],
                "refinements": ["type": "array", "minItems": 5, "maxItems": 5, "items": ["type": "string"]],
            ],
            "required": ["events", "querySummary", "suggestions", "refinements"],
        ],
    ]

    private static func instructions(today: String) -> String {
        """
        Today's date is \(today). You are a travel intent parser. Return only schema-constrained data and never choose UI or tools.
        Extract every stated or safely inferred field as a separate event. Dates are ISO YYYY-MM-DD. destinations is a JSON string array and destinationCoordinates is a JSON object with lat/lng. Budgets are {"amount":number,"currency":"USD"}. children is an array of ages.
        Always include independent goal (find/explore/compare), productScope (included lodging/flight/activities, optional primary, relationship single/package/sequence, confidence), emotionalRegister (warm/neutral/flat), and legacy searchMode (product-search/explore).
        Treat explicit package/packages/bundle/bundles as a lodging+flight package. Treat vacation/trip/getaway without an explicit package term as destination exploration, even when a broad region is supplied.
        Explicit activities, attractions, tours, excursions, tickets, or things-to-do requests include activities only unless the user also explicitly requests another product.
        Do not invent dates when omitted. Relative dates use today's date. On refinement, emit only changed fields. querySummary must read as a fresh complete search phrase, never "now with" or "updated". Return exactly five contextual refinement labels not already present.
        """
    }
}

struct FallbackIntentProvider: EmbeddedIntentProviding {
    let primary: any EmbeddedIntentProviding
    let fallback: any EmbeddedIntentProviding
    var configured: Bool { primary.configured || fallback.configured }

    func parse(
        query: String,
        previousEvents: [IntentEvent],
        previousQuerySummary: String?
    ) async throws -> EmbeddedIntentParseResult {
        guard primary.configured else {
            return try await fallback.parse(query: query, previousEvents: previousEvents, previousQuerySummary: previousQuerySummary)
        }
        do {
            return try await primary.parse(query: query, previousEvents: previousEvents, previousQuerySummary: previousQuerySummary)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            #if DEBUG
            print("[EmbeddedIntent] Live GPT unavailable; using deterministic fallback: \(error.localizedDescription)")
            #endif
            return try await fallback.parse(query: query, previousEvents: previousEvents, previousQuerySummary: previousQuerySummary)
        }
    }
}

protocol EmbeddedInspirationProviding: Sendable {
    var configured: Bool { get }
    func suggest(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination]
}

struct GPTInspirationProvider: EmbeddedInspirationProviding, @unchecked Sendable {
    let configuration: EmbeddedGPTConfiguration
    let session: URLSession
    var configured: Bool { configuration.configured }

    init(configuration: EmbeddedGPTConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func suggest(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        let inputData = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "travelStyle": intent.travelStyle,
            "budget": intent.totalBudget as Any,
        ])
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.schema,
            messages: [
                ["role": "system", "content": "Rank only the grounded candidates supplied by the user. Give each a concise factual rationale in description. Never add a destination that is not in that candidate list."],
                ["role": "user", "content": String(decoding: inputData, as: UTF8.self)],
            ]
        )
        guard let object = value as? [String: Any], let candidates = object["candidates"] as? [[String: Any]] else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        let parsed = candidates.enumerated().compactMap { index, item -> EmbeddedDestination? in
            guard
                let name = item["name"] as? String, !name.isEmpty,
                let country = item["country"] as? String,
                let description = item["description"] as? String,
                let highlights = item["highlights"] as? [String]
            else { return nil }
            return .init(
                id: "gpt-inspiration-\(index)",
                name: name,
                country: country,
                description: description,
                highlights: Array(highlights.prefix(5)),
                dataSource: "gpt-provisional"
            )
        }
        guard !parsed.isEmpty else { throw EmbeddedGPTProviderError.invalidResponse }
        return Array(parsed.prefix(6))
    }

    private static let schema: [String: Any] = [
        "name": "destination_inspiration",
        "strict": true,
        "schema": [
            "type": "object", "additionalProperties": false,
            "properties": [
                "candidates": [
                    "type": "array", "minItems": 1, "maxItems": 6,
                    "items": [
                        "type": "object", "additionalProperties": false,
                        "properties": [
                            "name": ["type": "string"],
                            "country": ["type": "string"],
                            "description": ["type": "string"],
                            "highlights": ["type": "array", "items": ["type": "string"], "maxItems": 5],
                        ],
                        "required": ["name", "country", "description", "highlights"],
                    ],
                ],
            ],
            "required": ["candidates"],
        ],
    ]
}

struct FixtureInspirationProvider: EmbeddedInspirationProviding {
    let configured = true

    func suggest(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        try await FixtureTravelProvider().search(intent: intent, query: query)
    }
}

struct FallbackInspirationProvider: EmbeddedInspirationProviding {
    let primary: any EmbeddedInspirationProviding
    let fallback: any EmbeddedInspirationProviding
    var configured: Bool { primary.configured || fallback.configured }

    func suggest(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        guard primary.configured else { return try await fallback.suggest(intent: intent, query: query) }
        do {
            return try await primary.suggest(intent: intent, query: query)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            #if DEBUG
            print("[EmbeddedInspiration] Live GPT unavailable; using fixture fallback: \(error.localizedDescription)")
            #endif
            return try await fallback.suggest(intent: intent, query: query)
        }
    }
}

struct GPTSectionCopyGenerator: SectionCopyGenerating, @unchecked Sendable {
    let configuration: EmbeddedGPTConfiguration
    let session: URLSession

    func generate(_ requests: [SectionCopyRequest]) async throws -> [String: PageSectionCopy] {
        guard !requests.isEmpty else { return [:] }
        let input: [[String: Any]] = requests.map { request in
            [
                "id": request.id,
                "role": request.role.rawValue,
                "itemName": request.itemName,
                "facts": request.itemFacts,
                "tradeoff": (request.tradeoff as Any?) ?? NSNull(),
                "query": request.querySummary,
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: ["sections": input])
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.schema,
            messages: [
                [
                    "role": "system",
                    "content": """
                    Write concise travel-result section copy grounded only in the supplied item names and facts.
                    The heading and subheading must express the narrative role: top-match is confident, close and
                    further alternatives state a useful trade-off, wild-card signals a deliberate departure, and
                    rest groups remaining choices. Never use generic filler such as "review the strongest options".
                    Return exactly one entry for every supplied id.
                    """,
                ],
                ["role": "user", "content": String(decoding: data, as: UTF8.self)],
            ]
        )
        guard let object = value as? [String: Any],
              let sections = object["sections"] as? [[String: Any]] else {
            throw EmbeddedGPTProviderError.invalidResponse
        }
        var result: [String: PageSectionCopy] = [:]
        for section in sections {
            guard let id = section["id"] as? String,
                  let heading = section["heading"] as? String, !heading.isEmpty,
                  let subheading = section["subheading"] as? String, !subheading.isEmpty else {
                throw EmbeddedGPTProviderError.invalidResponse
            }
            result[id] = PageSectionCopy(heading: heading, subheading: subheading)
        }
        guard result.count == requests.count else { throw EmbeddedGPTProviderError.invalidResponse }
        return result
    }

    private static let schema: [String: Any] = [
        "name": "narrative_section_copy",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "sections": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "id": ["type": "string"],
                            "heading": ["type": "string"],
                            "subheading": ["type": "string"],
                        ],
                        "required": ["id", "heading", "subheading"],
                    ],
                ],
            ],
            "required": ["sections"],
        ],
    ]
}

struct GPTTripOverviewClusterer: TripOverviewClustering, @unchecked Sendable {
    let configuration: EmbeddedGPTConfiguration
    let session: URLSession

    var configured: Bool { configuration.configured }

    func cluster(_ items: [TripOverviewClusterItem]) async throws -> [TripOverviewCluster] {
        guard items.count > 3 else { return [] }
        let payload = items.map { item -> [String: Any] in
            [
                "id": item.id,
                "title": item.title,
                "label": item.label,
                "productType": item.kind,
                "parentSearch": item.parentTitle,
                "activityType": item.entryType,
                "recencyIndex": item.recencyIndex,
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: ["items": payload])
        let value = try await EmbeddedGPTRequest.send(
            configuration: configuration,
            session: session,
            schema: Self.schema,
            messages: [
                [
                    "role": "system",
                    "content": """
                    Organize Trip Overview history into 2 to 4 useful clusters. Group items by what they have in
                    common — the destination, the kind of trip, the product, the parent search, or the way the user
                    engaged with them. Use every supplied id exactly once and never invent ids.

                    Then write the heading and description like a thoughtful travel concierge recapping the trip so
                    far, not a system labeling folders. Read the items and say something genuinely specific and a
                    little warm about what this group is. Vary your phrasing across clusters — do not reuse the same
                    sentence shape. The heading is a short, natural phrase; the description is one relaxed sentence
                    that adds a detail the heading doesn't. Prefer concrete nouns from the actual items (place names,
                    hotel styles, questions asked) over abstract summaries.

                    Do NOT follow a template such as "<subject> you <verb>" — that reads robotic. Do NOT organize or
                    name clusters by recency; never use time/freshness words like "Recent", "Latest", "Earlier",
                    "Previous", or a bare "Activity". recencyIndex (0 is newest) may only break ties for ordering.
                    Avoid generic filler such as "Cluster 1", "Other", or "More activity".
                    """,
                ],
                ["role": "user", "content": String(decoding: data, as: UTF8.self)],
            ]
        )
        guard let object = value as? [String: Any],
              let rawClusters = object["clusters"] as? [[String: Any]],
              (2...4).contains(rawClusters.count) else {
            throw EmbeddedGPTProviderError.invalidResponse
        }

        let validIDs = Set(items.map(\.id))
        var seen: Set<String> = []
        let clusters = try rawClusters.enumerated().map { index, raw -> TripOverviewCluster in
            guard let heading = clean(raw["heading"] as? String),
                  let description = clean(raw["description"] as? String),
                  let itemIDs = raw["itemIds"] as? [String],
                  !itemIDs.isEmpty,
                  itemIDs.allSatisfy({ validIDs.contains($0) && seen.insert($0).inserted })
            else {
                throw EmbeddedGPTProviderError.invalidResponse
            }
            return TripOverviewCluster(
                id: "trip-overview-cluster-\(index)",
                heading: heading,
                description: description,
                itemIDs: itemIDs
            )
        }
        guard seen == validIDs else { throw EmbeddedGPTProviderError.invalidResponse }
        return clusters
    }

    private static let schema: [String: Any] = [
        "name": "trip_overview_clusters",
        "strict": true,
        "schema": [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "clusters": [
                    "type": "array",
                    "minItems": 2,
                    "maxItems": 4,
                    "items": [
                        "type": "object",
                        "additionalProperties": false,
                        "properties": [
                            "heading": ["type": "string"],
                            "description": ["type": "string"],
                            "itemIds": [
                                "type": "array",
                                "minItems": 1,
                                "items": ["type": "string"],
                            ],
                        ],
                        "required": ["heading", "description", "itemIds"],
                    ],
                ],
            ],
            "required": ["clusters"],
        ],
    ]

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum EmbeddedLiveProviderFactory {
    static let defaultModel = "gpt-5.4-nano-2026-03-17"
    static let defaultBaseURL = URL(
        string: "https://generative-ai-proxy.rcp.us-east-1.data.test.exp-aws.net/v1/proxy/azure-openai/chat/completions"
    )!

    static func intentProvider(session: URLSession? = nil) -> any EmbeddedIntentProviding {
        let configuration = configuration
        let live = GPTIntentProvider(
            configuration: configuration,
            session: session ?? EmbeddedGPTSessionFactory.session(
                for: configuration,
                enablePrototypeTrust: true
            )
        )
        return FallbackIntentProvider(primary: live, fallback: FixtureIntentProvider())
    }

    static func composerRouter(session: URLSession? = nil) -> any ComposerRouting {
        let configuration = configuration
        let live = GPTComposerRouter(
            configuration: configuration,
            session: session ?? EmbeddedGPTSessionFactory.session(
                for: configuration,
                enablePrototypeTrust: true
            )
        )
        return FallbackComposerRouter(primary: live, fallback: DeterministicComposerRouter())
    }

    static func inspirationProvider(session: URLSession? = nil) -> any EmbeddedInspirationProviding {
        let configuration = configuration
        return GPTInspirationProvider(
            configuration: configuration,
            session: session ?? EmbeddedGPTSessionFactory.session(
                for: configuration,
                enablePrototypeTrust: true
            )
        )
    }

    static func sectionCopyGenerator(session: URLSession? = nil) -> any SectionCopyGenerating {
        let configuration = configuration
        let live = GPTSectionCopyGenerator(
            configuration: configuration,
            session: session ?? EmbeddedGPTSessionFactory.session(
                for: configuration,
                enablePrototypeTrust: true
            )
        )
        return FallbackSectionCopyGenerator(
            primary: live,
            fallback: DeterministicSectionCopyGenerator()
        )
    }

    static func tripOverviewClusterer(session: URLSession? = nil) -> any TripOverviewClustering {
        let configuration = configuration
        let live = GPTTripOverviewClusterer(
            configuration: configuration,
            session: session ?? EmbeddedGPTSessionFactory.session(
                for: configuration,
                enablePrototypeTrust: true
            )
        )
        return FallbackTripOverviewClusterer(
            primary: live,
            fallback: DeterministicTripOverviewClusterer()
        )
    }

    private static var configuration: EmbeddedGPTConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let environmentKey = environment["OPENAI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let environmentModel = environment["OPENAI_MODEL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let environmentBaseURL = (
            environment["OPENAI_BASE_URL"] ?? environment["GENAI_PROXY_BASE_URL"]
        )?.trimmingCharacters(in: .whitespacesAndNewlines)
        return EmbeddedGPTConfiguration(
            apiKey: environmentKey.flatMap { $0.isEmpty ? nil : $0 } ?? Secrets.genAIProxyToken,
            model: environmentModel.flatMap { $0.isEmpty ? nil : $0 } ?? defaultModel,
            baseURL: environmentBaseURL
                .flatMap { $0.isEmpty ? nil : URL(string: $0) }
                ?? defaultBaseURL
        )
    }
}

private func jsonValue(_ value: Any) -> JSONValue {
    switch value {
    case is NSNull: return .null
    case let value as String: return .string(value)
    case let value as NSNumber:
        return CFGetTypeID(value) == CFBooleanGetTypeID() ? .bool(value.boolValue) : .number(value.doubleValue)
    case let value as [Any]: return .array(value.map(jsonValue))
    case let value as [String: Any]: return .object(value.mapValues(jsonValue))
    default: return .null
    }
}

private func foundationValue(_ value: JSONValue) -> Any {
    switch value {
    case .null: return NSNull()
    case .bool(let value): return value
    case .number(let value): return value
    case .string(let value): return value
    case .array(let value): return value.map(foundationValue)
    case .object(let value): return value.mapValues(foundationValue)
    }
}
