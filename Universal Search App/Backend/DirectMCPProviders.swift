import CryptoKit
import Foundation

struct MCPTool: Sendable, Equatable {
    var name: String
    var propertyNames: Set<String>?
    var required: Set<String>
}

enum MCPClientError: Error, Equatable {
    case invalidConfiguration
    case transport
    case httpStatus(Int)
    case malformedResponse
    case rpc(code: Int?, message: String)
    case capabilityUnavailable(String)
    case missingRequiredArgument(String)
    case unusableResult(String)
}

struct MCPConfiguration: Sendable {
    static let defaultGatewayURL = URL(
        string: "https://mcp-gateway-1p.rcp.us-west-2.partnerexperiences.prod.exp-aws.net/mcp"
    )!

    var url: URL = Self.defaultGatewayURL
    var timeout: TimeInterval = 15
    var headers: [String: String] = [:]
    var allowInsecureTLS = false

    static func environment(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        var value = Self()
        if let raw = environment["MCP_GATEWAY_URL"], let url = URL(string: raw) { value.url = url }
        if let raw = environment["MCP_TIMEOUT_MS"], let milliseconds = Double(raw), milliseconds > 0 {
            value.timeout = milliseconds / 1_000
        }
        if let raw = environment["MCP_AUTH_HEADER"], let separator = raw.firstIndex(of: ":") {
            let name = raw[..<separator].trimmingCharacters(in: .whitespaces)
            let headerValue = raw[raw.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { value.headers[name] = headerValue }
        } else if let token = environment["MCP_AUTH_TOKEN"], !token.isEmpty {
            value.headers["Authorization"] = "Bearer \(token)"
        }
        #if DEBUG
        value.allowInsecureTLS = environment["MCP_ALLOW_INSECURE_TLS"]?.lowercased() == "true"
        #endif
        return value
    }
}

final class MCPPrototypeTLSDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let allowInsecureTLS: Bool
    private let trustedHost: String?

    init(allowInsecureTLS: Bool, trustedHost: String?) {
        self.allowInsecureTLS = allowInsecureTLS
        self.trustedHost = trustedHost
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        #if DEBUG
        if allowInsecureTLS,
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

actor StreamableHTTPMCPClient {
    private let configuration: MCPConfiguration
    private let session: URLSession
    private var sessionID: String?
    private var nextID = 1
    private var initialized = false
    private var cachedTools: [MCPTool] = []

    init(configuration: MCPConfiguration, session: URLSession? = nil) {
        self.configuration = configuration
        if let session {
            self.session = session
        } else {
            let delegate = MCPPrototypeTLSDelegate(
                allowInsecureTLS: configuration.allowInsecureTLS,
                trustedHost: configuration.url.host
            )
            self.session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        }
    }

    func discover() async throws -> [MCPTool] {
        if !initialized {
            _ = try await rpc(method: "initialize", params: .object([
                "protocolVersion": .string("2025-03-26"),
                "capabilities": .object([:]),
                "clientInfo": .object([
                    "name": .string("universal-search-ios"),
                    "version": .string("1.0.0"),
                ]),
            ]))
            try await notify(method: "notifications/initialized")
            initialized = true
        }
        let result = try await rpc(method: "tools/list", params: .object([:]))
        cachedTools = Self.decodeTools(result)
        return cachedTools
    }

    func callTool(name: String, arguments: [String: JSONValue]) async throws -> JSONValue {
        if !initialized { _ = try await discover() }
        return try await rpc(method: "tools/call", params: .object([
            "name": .string(name),
            "arguments": .object(arguments),
        ]))
    }

    private func request(body: JSONValue) throws -> URLRequest {
        guard configuration.url.scheme == "https" || configuration.url.host == "localhost" else {
            throw MCPClientError.invalidConfiguration
        }
        var request = URLRequest(url: configuration.url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "mcp-session-id") }
        for (name, value) in configuration.headers { request.setValue(value, forHTTPHeaderField: name) }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private func send(_ body: JSONValue, allowsAccepted: Bool = false) async throws -> JSONValue? {
        let data: Data
        let response: URLResponse
        do {
            try Task.checkCancellation()
            (data, response) = try await session.data(for: request(body: body))
            try Task.checkCancellation()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MCPClientError {
            throw error
        } catch {
            throw MCPClientError.transport
        }
        guard let http = response as? HTTPURLResponse else { throw MCPClientError.malformedResponse }
        guard (200..<300).contains(http.statusCode) || (allowsAccepted && http.statusCode == 202) else {
            throw MCPClientError.httpStatus(http.statusCode)
        }
        sessionID = http.value(forHTTPHeaderField: "mcp-session-id") ?? sessionID
        guard !data.isEmpty else { return nil }
        if http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/event-stream") == true {
            return Self.parseSSE(String(decoding: data, as: UTF8.self))
        }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    private func rpc(method: String, params: JSONValue) async throws -> JSONValue {
        let id = nextID
        nextID += 1
        guard let message = try await send(.object([
            "jsonrpc": .string("2.0"), "id": .number(Double(id)),
            "method": .string(method), "params": params,
        ])), let object = message.objectValue else {
            throw MCPClientError.malformedResponse
        }
        if let error = object["error"]?.objectValue {
            throw MCPClientError.rpc(
                code: error["code"]?.doubleValue.map(Int.init),
                message: error["message"]?.stringValue ?? "unknown error"
            )
        }
        guard let result = object["result"] else { throw MCPClientError.malformedResponse }
        return result
    }

    private func notify(method: String) async throws {
        _ = try await send(.object([
            "jsonrpc": .string("2.0"), "method": .string(method),
        ]), allowsAccepted: true)
    }

    static func parseSSE(_ text: String) -> JSONValue? {
        let blocks = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n\n")
        let messages = blocks.compactMap { block -> JSONValue? in
            let payload = block.split(separator: "\n")
                .filter { $0.hasPrefix("data:") }
                .map { $0.dropFirst(5).trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
            guard !payload.isEmpty, payload != "[DONE]", let data = payload.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(JSONValue.self, from: data)
        }
        return messages.reversed().first { value in
            value.objectValue?["result"] != nil || value.objectValue?["error"] != nil
        } ?? messages.last
    }

    private static func decodeTools(_ value: JSONValue) -> [MCPTool] {
        value.objectValue?["tools"]?.arrayValue?.compactMap { item in
            guard let object = item.objectValue, let name = object["name"]?.stringValue else { return nil }
            let schema = object["inputSchema"]?.objectValue
            return MCPTool(
                name: name,
                propertyNames: schema?["properties"]?.objectValue.map { Set($0.keys) },
                required: Set(schema?["required"]?.arrayValue?.compactMap(\.stringValue) ?? [])
            )
        } ?? []
    }
}

actor MCPCapabilityCatalog {
    private let client: StreamableHTTPMCPClient
    private var tools: [MCPTool] = []

    init(client: StreamableHTTPMCPClient) { self.client = client }

    func discover() async throws { tools = try await client.discover() }

    func supports(_ logicalName: String) async -> Bool {
        do {
            if tools.isEmpty { try await discover() }
            return resolve(logicalName) != nil
        } catch {
            return false
        }
    }

    func resolve(_ logicalName: String) -> MCPTool? {
        tools.first { $0.name == logicalName }
            ?? tools.first { $0.name.hasSuffix("-\(logicalName)") }
    }

    func call(_ logicalName: String, params: [String: JSONValue]) async throws -> JSONValue {
        if tools.isEmpty { try await discover() }
        guard let tool = resolve(logicalName) else {
            throw MCPClientError.capabilityUnavailable(logicalName)
        }
        let filtered = tool.propertyNames.map { allowed in
            params.filter { allowed.contains($0.key) }
        } ?? params
        if let missing = tool.required.first(where: { filtered[$0] == nil }) {
            throw MCPClientError.missingRequiredArgument(missing)
        }
        return try await client.callTool(name: tool.name, arguments: filtered)
    }
}

enum MCPNormalizers {
    static func lodging(_ result: JSONValue, destination: String) -> [EmbeddedLodging] {
        findItems(textPayload(result), keys: ["properties", "results", "lodgings", "items", "data"]).enumerated().compactMap { index, item in
            guard let object = item.objectValue,
                  let name = string(object, ["propertyName", "name"]), !name.isEmpty else { return nil }
            let amenities = object["amenities"]?.arrayValue?.compactMap {
                $0.stringValue ?? $0.objectValue?["text"]?.stringValue
            } ?? []
            let coordinate = coordinate(in: item)
            return EmbeddedLodging(
                id: string(object, ["propertyId"]) ?? "authoritative-lodging-\(index)",
                name: name,
                location: string(object, ["location", "address"]) ?? destination,
                amenities: amenities,
                nightly: money(object["priceNightly"]) ?? 0,
                total: money(object["priceTotal"]) ?? 0,
                rating: object["reviewScore"]?.doubleValue ?? 0,
                reviews: Int(object["reviewCount"]?.doubleValue ?? 0),
                refundable: object["refundable"]?.boolValue ?? false,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                imageURL: imageURL(in: item),
                dataSource: "authoritative"
            )
        }
    }

    static func destinations(_ result: JSONValue) -> [EmbeddedDestination] {
        findItems(textPayload(result), keys: ["entities", "destinations", "relatedPlaces", "places", "results", "items", "data", "content", "result"])
            .enumerated().compactMap { index, item in
                guard let name = deepString(item, ["destinationName", "placeName", "name", "title"])
                else { return nil }
                let description = deepString(
                    item,
                    ["description", "desc", "summary", "shortDescription", "caption"]
                ) ?? "Grounded destination in the requested region"
                let object = item.objectValue
                let rawHighlights = object?["highlights"] ?? object?["affinities"] ?? object?["tags"] ?? object?["themes"]
                let highlights = rawHighlights?.arrayValue?.compactMap {
                    $0.stringValue ?? deepString($0, ["name", "label"])
                } ?? []
                return EmbeddedDestination(
                    id: deepString(item, ["destinationId", "placeId", "id"]) ?? "mcp-destination-\(index)",
                    name: name,
                    country: deepString(item, ["countryName", "country"]) ?? "",
                    description: description,
                    highlights: highlights,
                    imageURL: imageURL(in: item),
                    airportCode: deepString(item, ["airportCode", "iataCode", "nearestAirport"]),
                    dataSource: "authoritative"
                )
            }
    }

    static func flights(_ result: JSONValue, intent: EmbeddedIntent) -> [EmbeddedFlight] {
        let payload = textPayload(result)
        let offerKeys = ["offer", "offers", "flightOffers", "airOffers"]
        let keyedOffers = offerKeys.flatMap { key in
            deepValues(payload, key: key).flatMap { $0.arrayValue ?? [$0] }
        }
        let offers = keyedOffers.isEmpty
            ? findItems(payload, keys: ["data", "results", "items"])
            : keyedOffers
        let party = max(1, intent.adults + intent.children.count)
        return offers.enumerated().compactMap { index, offer in
            let flightOffer = offer.objectValue?["flightOffer"] ?? deepValues(offer, key: "flightOffer").first ?? offer
            let products = flightOffer.objectValue?["airProducts"]?.arrayValue
                ?? deepValues(flightOffer, key: "airProducts").flatMap { $0.arrayValue ?? [$0] }
            let product = products.first ?? flightOffer
            let journeys = deepValues(product, key: "airOriginDestinations").flatMap { $0.arrayValue ?? [$0] }
            let outbound = journeys.first ?? product
            let segments = deepValues(outbound, key: "airSegment").flatMap { $0.arrayValue ?? [$0] }
            let legs = (segments.isEmpty ? [outbound] : segments).flatMap {
                deepValues($0, key: "airLegs").flatMap { $0.arrayValue ?? [$0] }
            }
            guard let first = legs.first, let last = legs.last else {
                return standardFlight(offer, intent: intent, party: party, index: index)
            }
            let origin = deepString(first, ["originAirportCode", "departureAirportCode", "origin"]) ?? airport(intent.originAirport ?? "")
            let destination = deepString(last, ["destinationAirportCode", "arrivalAirportCode", "destination"]) ?? airport(intent.destinations.first ?? "")
            guard let departure = deepString(first, ["departureDateTime", "departureTime", "departureDate"]),
                  let arrival = deepString(last, ["arrivalDateTime", "arrivalTime", "arrivalDate"]) else {
                return standardFlight(offer, intent: intent, party: party, index: index)
            }
            let priceSummary = flightOffer.objectValue?["priceSummary"]
            let totalMoney = priceSummary?.objectValue?["total"]
            guard let total = money(totalMoney) ?? directMoney(offer, ["totalPrice", "totalAmount", "grandTotal"]) else {
                return standardFlight(offer, intent: intent, party: party, index: index)
            }
            let details = flightOffer.objectValue?["priceDetails"] ?? deepValues(flightOffer, key: "priceDetails").first
            let firstCategory = details?.objectValue?["travelerCategoryPrice"]?.arrayValue?.first
            let perTraveler = directMoney(firstCategory, ["total"]) ?? total / Double(party)
            let duration = segments.isEmpty ? durationMinutes(outbound) : segments.reduce(0) { $0 + durationMinutes($1) }
            return EmbeddedFlight(
                id: "\(deepString(offer, ["offerId", "id"]) ?? "mcp-flight")-\(index)",
                airline: deepString(segments.first ?? first, ["marketingCarrierCode", "operatingAirCarrierCode"])
                    ?? deepString(product, ["airlineName", "carrierName", "airlineCode"]) ?? "Airline",
                number: deepString(segments.first ?? first, ["marketingFlightNumber", "operatingFlightNumber", "flightNumber"]) ?? "",
                origin: origin, destination: destination,
                departure: isoTime(departure), arrival: isoTime(arrival),
                duration: duration, price: perTraveler, total: total,
                stops: max(0, (segments.isEmpty ? legs.count : segments.count) - 1),
                cabin: deepString(product, ["cabinClass", "cabin"]) ?? intent.flightClass ?? "economy",
                dataSource: "authoritative"
            )
        }
    }

    static func activities(_ result: JSONValue) -> [EmbeddedActivity] {
        findItems(textPayload(result), keys: ["activities", "results", "items", "data"])
            .enumerated().compactMap { index, item in
                guard let object = item.objectValue,
                      let name = string(object, ["title", "name"]), !name.isEmpty else { return nil }
                let leadPrice = object["leadPrice"]?.objectValue
                let amount = money(leadPrice?["amount"])
                let currency = string(leadPrice ?? [:], ["currency", "currencyCode"]) ?? "USD"
                let features = object["features"]?.arrayValue?.compactMap(\.stringValue) ?? []
                let duration = deepString(item, ["durationText", "duration"])
                    ?? object["duration"]?.objectValue?["text"]?.stringValue
                return EmbeddedActivity(
                    id: string(object, ["id", "activityId"]) ?? "mcp-activity-\(index)",
                    name: name,
                    description: string(object, ["description", "summary"]) ?? "",
                    highlights: ([duration] + features).compactMap { $0 },
                    price: amount,
                    formattedPrice: amount.map { String(format: "$%.2f", $0) },
                    currency: currency,
                    rating: deepValues(item, key: "rating").compactMap(\.doubleValue).first,
                    reviews: deepValues(item, key: "reviewCount").compactMap(\.doubleValue).first.map(Int.init),
                    imageURL: imageURL(in: item),
                    dataSource: "authoritative"
                )
            }
    }

    private static func textPayload(_ result: JSONValue) -> JSONValue {
        if let text = result.stringValue, let decoded = decodeEmbeddedJSON(text) {
            return textPayload(decoded)
        }
        guard let object = result.objectValue else { return result }
        if let structured = object["structuredContent"] { return structured }
        if let text = object["content"]?.arrayValue?.first(where: { $0.objectValue?["type"]?.stringValue == "text" })?
            .objectValue?["text"]?.stringValue,
           let decoded = decodeEmbeddedJSON(text) { return textPayload(decoded) }
        return result
    }

    static func failureDetail(_ result: JSONValue) -> String {
        if let object = result.objectValue {
            if let text = object["content"]?.arrayValue?
                .compactMap({ $0.objectValue?["text"]?.stringValue })
                .first {
                return sanitized(text)
            }
            return "response keys: \(object.keys.sorted().joined(separator: ", "))"
        }
        if let array = result.arrayValue {
            return "response array with \(array.count) item\(array.count == 1 ? "" : "s")"
        }
        if let text = result.stringValue { return sanitized(text) }
        return "unsupported response value"
    }

    private static func sanitized(_ text: String) -> String {
        let singleLine = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        return String(singleLine.prefix(240))
    }

    private static func decodeEmbeddedJSON(_ text: String) -> JSONValue? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^```(?:json)?\s*|\s*```$"#, with: "", options: .regularExpression)
        if let data = trimmed.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(JSONValue.self, from: data) {
            return decoded
        }
        guard let start = trimmed.firstIndex(where: { $0 == "{" || $0 == "[" }),
              let end = trimmed.lastIndex(where: { $0 == "}" || $0 == "]" }),
              start <= end,
              let data = String(trimmed[start...end]).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: data)
    }

    private static func standardFlight(
        _ offer: JSONValue,
        intent: EmbeddedIntent,
        party: Int,
        index: Int
    ) -> EmbeddedFlight? {
        let itineraries = deepValues(offer, key: "itineraries").flatMap { $0.arrayValue ?? [$0] }
        let segments = itineraries.flatMap {
            deepValues($0, key: "segments").flatMap { $0.arrayValue ?? [$0] }
        }
        guard let first = segments.first?.objectValue,
              let last = segments.last?.objectValue else { return nil }
        let departureObject = first["departure"]?.objectValue
        let arrivalObject = last["arrival"]?.objectValue
        guard let departure = string(departureObject ?? [:], ["at", "dateTime", "time"]),
              let arrival = string(arrivalObject ?? [:], ["at", "dateTime", "time"]) else { return nil }
        let price = offer.objectValue?["price"]
        guard let total = directMoney(price, ["grandTotal", "total", "amount"])
            ?? directMoney(offer, ["totalPrice", "totalAmount", "grandTotal", "price"]) else { return nil }
        let origin = string(departureObject ?? [:], ["iataCode", "airportCode"])
            ?? airport(intent.originAirport ?? "")
        let destination = string(arrivalObject ?? [:], ["iataCode", "airportCode"])
            ?? airport(intent.destinations.first ?? "")
        let carrier = string(first, ["carrierCode", "marketingCarrierCode", "airlineCode"]) ?? "Airline"
        let duration = itineraries.first.map(durationMinutes) ?? segments.reduce(0) {
            $0 + durationMinutes($1)
        }
        return EmbeddedFlight(
            id: "\(deepString(offer, ["id", "offerId"]) ?? "mcp-flight")-\(index)",
            airline: carrier,
            number: string(first, ["number", "flightNumber"]) ?? "",
            origin: origin,
            destination: destination,
            departure: isoTime(departure),
            arrival: isoTime(arrival),
            duration: duration,
            price: total / Double(party),
            total: total,
            stops: max(0, segments.count - max(1, itineraries.count)),
            cabin: deepString(offer, ["cabin", "cabinClass"]) ?? intent.flightClass ?? "economy",
            dataSource: "authoritative"
        )
    }

    private static func findItems(_ value: JSONValue, keys: [String]) -> [JSONValue] {
        if let array = value.arrayValue { return array.filter { $0.objectValue != nil } }
        guard let object = value.objectValue else { return [] }
        for key in keys {
            if let child = object[key] {
                let found = findItems(child, keys: keys)
                if !found.isEmpty { return found }
            }
        }
        return deepString(value, ["name", "destinationName", "title"]) == nil ? [] : [value]
    }

    private static func deepValues(_ value: JSONValue, key: String) -> [JSONValue] {
        if let array = value.arrayValue { return array.flatMap { deepValues($0, key: key) } }
        guard let object = value.objectValue else { return [] }
        return object.flatMap { name, child in (name == key ? [child] : []) + deepValues(child, key: key) }
    }

    private static func deepString(_ value: JSONValue, _ keys: [String]) -> String? {
        guard let object = value.objectValue else { return nil }
        if let found = string(object, keys) { return found }
        return object.values.compactMap { deepString($0, keys) }.first
    }

    private static func coordinate(in value: JSONValue) -> (latitude: Double, longitude: Double)? {
        if let object = value.objectValue {
            let latitude = number(object, ["latitude", "lat"])
            let longitude = number(object, ["longitude", "lng", "lon"])
            if let latitude, let longitude, validCoordinate(latitude: latitude, longitude: longitude) {
                return (latitude, longitude)
            }
            if let coordinates = object["coordinates"]?.arrayValue,
               coordinates.count >= 2,
               let longitude = number(coordinates[0]),
               let latitude = number(coordinates[1]),
               validCoordinate(latitude: latitude, longitude: longitude) {
                return (latitude, longitude)
            }
            let preferred = ["coordinates", "coordinate", "geo", "geolocation", "location", "position", "mapMarker"]
            for key in preferred {
                if let child = object[key], let found = coordinate(in: child) { return found }
            }
            for child in object.values {
                if let found = coordinate(in: child) { return found }
            }
        } else if let array = value.arrayValue {
            for child in array {
                if let found = coordinate(in: child) { return found }
            }
        }
        return nil
    }

    private static func imageURL(in value: JSONValue) -> String? {
        guard let object = value.objectValue else { return nil }
        for key in ["imageUrl", "imageURL"] {
            if let url = validWebURL(object[key]?.stringValue) { return url }
        }
        for key in ["image", "images", "media", "mediaGallery", "gallery", "propertyImage", "propertyImages"] {
            guard let child = object[key] else { continue }
            if let url = imageURLValue(child) { return url }
        }
        return nil
    }

    private static func imageURLValue(_ value: JSONValue) -> String? {
        if let url = validWebURL(value.stringValue) { return url }
        if let array = value.arrayValue {
            return array.compactMap(imageURLValue).first
        }
        guard let object = value.objectValue else { return nil }
        for key in ["imageUrl", "imageURL", "url", "src", "href"] {
            if let url = validWebURL(object[key]?.stringValue) { return url }
        }
        return object.values.compactMap(imageURLValue).first
    }

    private static func validWebURL(_ value: String?) -> String? {
        guard let value,
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return value
    }

    private static func validCoordinate(latitude: Double, longitude: Double) -> Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }

    private static func number(_ object: [String: JSONValue], _ keys: [String]) -> Double? {
        keys.compactMap { number(object[$0]) }.first
    }

    private static func number(_ value: JSONValue?) -> Double? {
        guard let value else { return nil }
        return value.doubleValue ?? value.stringValue.flatMap(Double.init)
    }

    private static func string(_ object: [String: JSONValue], _ keys: [String]) -> String? {
        for key in keys {
            if let value = object[key]?.stringValue, !value.isEmpty { return value }
            if let value = object[key]?.doubleValue { return String(value) }
            if let value = object[key]?.boolValue { return String(value) }
        }
        return nil
    }

    private static func money(_ value: JSONValue?) -> Double? {
        guard let value else { return nil }
        if let number = value.doubleValue { return number }
        if let text = value.stringValue {
            return Double(text.filter { $0.isNumber || $0 == "." || $0 == "-" })
        }
        guard let object = value.objectValue else { return nil }
        guard let amount = money(object["amount"]) else { return nil }
        let places = Int(money(object["decimalPlaces"]) ?? 0)
        return places >= 0 ? amount / pow(10, Double(places)) : amount
    }

    private static func directMoney(_ value: JSONValue?, _ keys: [String]) -> Double? {
        guard let object = value?.objectValue else { return nil }
        return keys.compactMap { money(object[$0]) }.first
    }

    private static func durationMinutes(_ value: JSONValue) -> Int {
        let keys = ["durationMinutes", "durationInMinutes", "elapsedTime", "elapsedDuration", "accumulatedDuration", "duration"]
        if let object = value.objectValue {
            for key in keys {
                if let number = object[key]?.doubleValue { return Int(number) }
                if let text = object[key]?.stringValue {
                    if let number = Double(text) { return Int(number) }
                    let scanner = Scanner(string: text)
                    if scanner.scanString("PT") != nil {
                        let hours = scanner.scanInt() ?? 0
                        _ = scanner.scanString("H")
                        let minutes = scanner.scanInt() ?? 0
                        return hours * 60 + minutes
                    }
                }
            }
            return object.values.map(durationMinutes).first { $0 > 0 } ?? 0
        }
        return 0
    }

    private static func isoTime(_ value: String) -> String {
        guard let range = value.range(of: #"T\d{2}:\d{2}"#, options: .regularExpression) else { return value }
        return String(value[range].dropFirst())
    }

    static func knownAirport(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = normalized.uppercased()
        if code.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil { return code }
        let airports = [
            "los angeles": "LAX", "london": "LHR", "cancun": "CUN", "los cabos": "SJD",
            "new york": "JFK", "san francisco": "SFO", "washington": "DCA", "boston": "BOS",
            "paris": "CDG", "tokyo": "HND", "chicago": "ORD", "miami": "MIA",
            "seattle": "SEA", "vancouver": "YVR", "lisbon": "LIS", "mexico city": "MEX",
            "tampa": "TPA",
        ]
        return airports.first(where: { normalized.lowercased().contains($0.key) })?.value
    }

    static func airport(_ value: String) -> String {
        if let known = knownAirport(value) { return known }
        return String(value.prefix(3)).uppercased()
    }
}

struct DirectMCPLodgingProvider: EmbeddedLodgingProviding {
    let catalog: MCPCapabilityCatalog
    let available = true

    func readiness() async -> Bool { await catalog.supports("search_lodging") }

    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        guard let checkIn = intent.departureDate, let checkOut = intent.returnDate else {
            throw MCPClientError.missingRequiredArgument("checkIn/checkOut")
        }
        let children = intent.children.map { JSONValue.number(Double($0)) }
        let destination = intent.destinations.joined(separator: ", ")
        let amenityQuery = intent.amenities.isEmpty
            ? ""
            : " with \(intent.amenities.joined(separator: ", "))"
        var params: [String: JSONValue] = [
            "query": .string("hotels in \(destination)\(amenityQuery)"),
            "checkIn": .string(checkIn), "checkOut": .string(checkOut), "limit": .number(25),
            "unitOccupants": .array([.object([
                "adults": .number(Double(intent.adults)), "childrenAges": .array(children),
                "childrenCount": .number(Double(children.count)), "pets": .number(0),
            ])]),
        ]
        if !intent.amenities.isEmpty { params["amenities"] = .array(intent.amenities.map(JSONValue.string)) }
        let result = try await catalog.call("search_lodging", params: params)
        let normalized = MCPNormalizers.lodging(result, destination: intent.destinations.joined(separator: ", "))
        guard !normalized.isEmpty else { throw MCPClientError.unusableResult("lodging") }
        return normalized
    }
}

struct DirectMCPFlightProvider: EmbeddedFlightProviding {
    let catalog: MCPCapabilityCatalog
    let deviceID: String
    let airportResolver: (any TravelerCoreProviding)?
    let available = true

    func readiness() async -> Bool { await catalog.supports("getFlightOffers") }

    init(
        catalog: MCPCapabilityCatalog,
        deviceID: String = DirectMCPProviderFactory.deviceID,
        airportResolver: (any TravelerCoreProviding)? = nil
    ) {
        self.catalog = catalog
        self.deviceID = deviceID
        self.airportResolver = airportResolver
    }

    func search(intent: EmbeddedIntent) async throws -> [EmbeddedFlight] {
        var resolvedIntent = intent
        resolvedIntent.originAirport = try await resolveAirport(intent.originAirport ?? "")
        resolvedIntent.destinations = [try await resolveAirport(intent.destinations.first ?? "")]
        let request = try Self.payload(intent: resolvedIntent, deviceID: deviceID)
        let data = try JSONEncoder().encode(request)
        let result = try await catalog.call("getFlightOffers", params: [
            "requestJson": .string(String(decoding: data, as: UTF8.self)),
        ])
        let normalized = MCPNormalizers.flights(result, intent: intent)
        guard !normalized.isEmpty else {
            #if DEBUG
            if let encoded = try? JSONEncoder().encode(result) {
                print("[FlightMCP] Unusable response: \(String(decoding: encoded, as: UTF8.self).prefix(4_000))")
            }
            #endif
            throw MCPClientError.unusableResult(
                "flight — \(MCPNormalizers.failureDetail(result))"
            )
        }
        return normalized
    }

    private func resolveAirport(_ value: String) async throws -> String {
        if let known = MCPNormalizers.knownAirport(value) { return known }
        if let airportResolver,
           let match = try? await airportResolver.airports(matching: value, first: 5).first,
           match.code.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil {
            return match.code
        }
        throw MCPClientError.unusableResult("No airport found for \(value)")
    }

    static func payload(intent: EmbeddedIntent, deviceID: String) throws -> JSONValue {
        guard let departure = intent.departureDate else { throw MCPClientError.missingRequiredArgument("departureDate") }
        let origin = MCPNormalizers.airport(intent.originAirport ?? "")
        let destination = MCPNormalizers.airport(intent.destinations.first ?? "")
        guard origin.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil,
              destination.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil else {
            throw MCPClientError.invalidConfiguration
        }
        func journey(_ date: String, _ from: String, _ to: String) throws -> JSONValue {
            let parts = date.split(separator: "-").compactMap { Double($0) }
            guard parts.count == 3 else { throw MCPClientError.invalidConfiguration }
            return .object([
                "departureDate": .object(["year": .number(parts[0]), "month": .number(parts[1]), "day": .number(parts[2])]),
                "originAirportCode": .string(from), "destinationAirportCode": .string(to),
            ])
        }
        var journeys = [try journey(departure, origin, destination)]
        if let returning = intent.returnDate { journeys.append(try journey(returning, destination, origin)) }
        let travelers = Array(repeating: JSONValue.object(["travelerType": .string("TRAVELER_TYPE_ADULT")]), count: max(1, intent.adults))
            + Array(repeating: JSONValue.object(["travelerType": .string("TRAVELER_TYPE_CHILD")]), count: intent.children.count)
        let normalizedCabin = intent.flightClass?.lowercased().replacingOccurrences(of: #"[\s_-]"#, with: "", options: .regularExpression) ?? ""
        let cabin = normalizedCabin.contains("first") ? "CABIN_CLASS_FIRST"
            : normalizedCabin.contains("business") ? "CABIN_CLASS_BUSINESS"
            : normalizedCabin.contains("premium") ? "CABIN_CLASS_PREMIUM_ECONOMY" : "CABIN_CLASS_COACH"
        return .object([
            "jsonrpc": .string("2.0"), "id": .number(1),
            "params": .object(["searchObject": .object([
                "searchType": .string("SEARCH_TYPE_REGULAR"),
                "regularSearch": .object(["flightSearchInfo": .object(["flightSearchInfo": .object([
                    "context": .object([
                        "pointOfSaleContext": .object([
                            "pointOfSale": .object(["companyCode": .number(10111), "managementUnitCode": .number(1010), "jurisdictionCode": .string("USA")]),
                            "legacyPointOfSale": .object(["tpid": .number(1)]),
                        ]),
                        "locale": .string("en_US"), "currency": .string("USD"),
                        "deviceContext": .object(["deviceUserAgentId": .string(deviceID), "userAgent": .string("UniversalSearchPrototype/1.0"), "deviceType": .string("DEVICE_TYPE_DESKTOP")]),
                    ]),
                    "searchCriteria": .object(["requestedJourney": .array(journeys), "traveler": .array(travelers), "shoppingPath": .string("SHOPPING_PATH_STANDALONE")]),
                    "preferences": .object(["cabinClass": .string(cabin)]),
                ])])]),
            ])]),
        ])
    }
}

struct DirectMCPDestinationProvider: EmbeddedDestinationProviding {
    let catalog: MCPCapabilityCatalog
    let available = true

    func readiness() async -> Bool { await catalog.supports("getRelatedPlaces_v3") }

    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        guard !intent.destinations.isEmpty else { throw MCPClientError.capabilityUnavailable("open destination exploration") }
        let result = try await catalog.call("getRelatedPlaces_v3", params: [
            "originPlaceIdentifier": .string(intent.destinations.joined(separator: ", ")),
            "originPlaceType": .string("DESTINATION"),
            "relatedPlaceType": .string("PLACE_TYPE_CITY"),
            "relationTypeFilter": .string("TOP"),
            "placeCount": .number(8),
            "imageLimit": .number(3),
            "affinityLimit": .number(5),
            "userQuery": .string(query),
        ])
        let normalized = MCPNormalizers.destinations(result)
        guard !normalized.isEmpty else { throw MCPClientError.unusableResult("destination") }
        return normalized
    }
}

struct DirectMCPActivityProvider: EmbeddedActivityProviding {
    let catalog: MCPCapabilityCatalog
    let available = true

    func readiness() async -> Bool { await catalog.supports("searchActivities_v1") }

    func search(intent: EmbeddedIntent) async throws -> [EmbeddedActivity] {
        guard let destination = intent.destinations.first, !destination.isEmpty else {
            throw MCPClientError.missingRequiredArgument("destination")
        }
        var params: [String: JSONValue] = [
            "location": .object(["name": .string(destination)]),
            "activityLimit": .number(12),
        ]
        if let start = intent.departureDate { params["startDate"] = .string(start) }
        if let end = intent.returnDate { params["endDate"] = .string(end) }
        if !intent.travelStyle.isEmpty {
            params["interests"] = .array(intent.travelStyle.map(JSONValue.string))
        }
        let result = try await catalog.call("searchActivities_v1", params: params)
        let normalized = MCPNormalizers.activities(result)
        guard !normalized.isEmpty else { throw MCPClientError.unusableResult("activities") }
        return normalized
    }
}

struct FallbackLodgingProvider: EmbeddedLodgingProviding {
    let primary: any EmbeddedLodgingProviding
    let fallback: any EmbeddedLodgingProviding
    var available: Bool { primary.available || fallback.available }
    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        do { return try await primary.search(intent: intent, summary: summary) }
        catch is CancellationError { throw CancellationError() }
        catch { return try await fallback.search(intent: intent, summary: summary) }
    }
}

struct FallbackFlightProvider: EmbeddedFlightProviding {
    let primary: any EmbeddedFlightProviding
    let fallback: any EmbeddedFlightProviding
    var available: Bool { primary.available || fallback.available }
    func search(intent: EmbeddedIntent) async throws -> [EmbeddedFlight] {
        do { return try await primary.search(intent: intent) }
        catch is CancellationError { throw CancellationError() }
        catch { return try await fallback.search(intent: intent) }
    }
}

struct FallbackDestinationProvider: EmbeddedDestinationProviding {
    let primary: any EmbeddedDestinationProviding
    let fallback: any EmbeddedDestinationProviding
    var available: Bool { primary.available || fallback.available }
    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        do { return try await primary.search(intent: intent, query: query) }
        catch is CancellationError { throw CancellationError() }
        catch { return try await fallback.search(intent: intent, query: query) }
    }
}

struct FallbackActivityProvider: EmbeddedActivityProviding {
    let primary: any EmbeddedActivityProviding
    let fallback: any EmbeddedActivityProviding
    var available: Bool { primary.available || fallback.available }
    func readiness() async -> Bool {
        await primary.readiness() || fallback.available
    }
    func search(intent: EmbeddedIntent) async throws -> [EmbeddedActivity] {
        do { return try await primary.search(intent: intent) }
        catch is CancellationError { throw CancellationError() }
        catch { return try await fallback.search(intent: intent) }
    }
}

enum DirectMCPProviderFactory {
    static var deviceID: String {
        let source = ProcessInfo.processInfo.hostName
        let hex = SHA256.hash(data: Data("UniversalSearchPrototype:\(source)".utf8))
            .prefix(16).map { String(format: "%02x", $0) }.joined()
        let boundaries = [8, 12, 16, 20]
        var result = ""
        for (index, character) in hex.enumerated() {
            if boundaries.contains(index) { result.append("-") }
            result.append(character)
        }
        return result
    }

    static func providers(
        configuration: MCPConfiguration = .environment(),
        session: URLSession? = nil,
        travelerCoreConfiguration: TravelerCoreConfiguration = .init(),
        travelerCoreSession: URLSession? = nil
    ) -> (
        any EmbeddedLodgingProviding,
        any EmbeddedFlightProviding,
        any EmbeddedDestinationProviding,
        any EmbeddedActivityProviding
    ) {
        let catalog = MCPCapabilityCatalog(client: StreamableHTTPMCPClient(configuration: configuration, session: session))
        let travelerCore = TravelerCoreClient(
            configuration: travelerCoreConfiguration,
            session: travelerCoreSession ?? .shared
        )
        let lodging = DirectMCPLodgingProvider(catalog: catalog)
        let destination = DirectMCPDestinationProvider(catalog: catalog)
        let activity = FallbackActivityProvider(
            primary: DirectMCPActivityProvider(catalog: catalog),
            fallback: TravelerCoreActivityProvider(client: travelerCore)
        )
        return (
            TravelerCoreLodgingEnrichmentProvider(primary: lodging, client: travelerCore),
            DirectMCPFlightProvider(catalog: catalog, airportResolver: travelerCore),
            ActivityDestinationEnrichmentProvider(primary: destination, activityProvider: activity),
            activity
        )
    }
}
