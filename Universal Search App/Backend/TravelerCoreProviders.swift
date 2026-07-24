import Foundation

struct TravelerCoreConfiguration: Sendable {
    nonisolated static let defaultURL = URL(string: "https://traveler-core.expedia.biz/graphql")!

    var url = Self.defaultURL
    var timeout: TimeInterval = 12
    var site = "1"
    var locale = "en-US"
    var currency = "USD"
    var maximumRetries = 2
    var retryDelayNanoseconds: UInt64 = 150_000_000

    nonisolated init(
        url: URL = Self.defaultURL,
        timeout: TimeInterval = 12,
        site: String = "1",
        locale: String = "en-US",
        currency: String = "USD",
        maximumRetries: Int = 2,
        retryDelayNanoseconds: UInt64 = 150_000_000
    ) {
        self.url = url
        self.timeout = timeout
        self.site = site
        self.locale = locale
        self.currency = currency
        self.maximumRetries = maximumRetries
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }
}

private struct TravelerCoreGraphQLError: Decodable { var message: String }
private struct TravelerCoreEnvelope<Payload: Decodable>: Decodable {
    var data: Payload?
    var errors: [TravelerCoreGraphQLError]?
}

enum TravelerCoreError: Error, Equatable, LocalizedError {
    case invalidConfiguration
    case transport
    case httpStatus(Int)
    case malformedResponse
    case graphQL([String])

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Traveler Core configuration is invalid."
        case .transport: return "Traveler Core could not be reached."
        case .httpStatus(let status): return "Traveler Core returned HTTP \(status)."
        case .malformedResponse: return "Traveler Core returned a malformed response."
        case .graphQL(let messages): return "Traveler Core: \(messages.joined(separator: "; "))"
        }
    }
}

struct TravelerCoreRegion: Decodable, Sendable, Equatable {
    struct Coordinates: Decodable, Sendable, Equatable {
        var latitude: Double
        var longitude: Double
    }
    struct Parent: Decodable, Sendable, Equatable { var name: String }

    var id: String
    var name: String
    var fullName: String?
    var type: String?
    var coordinates: Coordinates?
    var parent: Parent?
}

struct TravelerCoreImage: Decodable, Sendable, Equatable {
    var url: String?
    var description: String?
}

struct TravelerCoreActivity: Decodable, Sendable, Equatable {
    struct DisplayPrice: Decodable, Sendable, Equatable {
        var amount: Double?
        var currencyCode: String?
        var formatted: String?

        private enum CodingKeys: String, CodingKey { case amount, currencyCode, formatted }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            amount = try? values.decodeIfPresent(Double.self, forKey: .amount)
            if amount == nil,
               let text = try? values.decodeIfPresent(String.self, forKey: .amount) {
                amount = Double(text)
            }
            currencyCode = try values.decodeIfPresent(String.self, forKey: .currencyCode)
            formatted = try values.decodeIfPresent(String.self, forKey: .formatted)
        }
    }
    struct LeadPrice: Decodable, Sendable, Equatable { var display: DisplayPrice? }
    struct ReviewSummary: Decodable, Sendable, Equatable {
        var score: Double?
        var totalCount: Int?
    }
    struct Reviews: Decodable, Sendable, Equatable { var summary: ReviewSummary? }

    var id: String
    var name: String
    var description: String?
    var highlights: [String]?
    var images: [TravelerCoreImage]?
    var leadPrice: LeadPrice?
    var reviews: Reviews?
    var region: TravelerCoreRegion?
}

struct TravelerCoreProperty: Decodable, Sendable, Equatable {
    var id: String
    var name: String
    var images: [TravelerCoreImage]?
}

struct TravelerCoreAirport: Decodable, Sendable, Equatable {
    var code: String
    var name: String?
    var city: String?
}

protocol TravelerCoreProviding: Sendable {
    func regions(matching query: String, first: Int) async throws -> [TravelerCoreRegion]
    func airports(matching query: String, first: Int) async throws -> [TravelerCoreAirport]
    func activities(intent: EmbeddedIntent, region: TravelerCoreRegion, first: Int) async throws -> [TravelerCoreActivity]
    func properties(intent: EmbeddedIntent, region: TravelerCoreRegion, first: Int) async throws -> [TravelerCoreProperty]
}

actor TravelerCoreClient: TravelerCoreProviding {
    static let regionOperation = """
    query RegionSearch($query: String!, $first: Int) {
      regionSearch(query: $query, first: $first) {
        id name fullName type
        coordinates { latitude longitude }
        parent { name }
      }
    }
    """

    static let airportOperation = """
    query AirportSearch($query: String!, $first: Int) {
      airportSearch(query: $query, first: $first) {
        code name city
      }
    }
    """

    static let activityOperation = """
    query ActivitySearch($criteria: ActivitySearchCriteriaInput!, $first: Int) {
      activitySearch(criteria: $criteria, first: $first) {
        edges {
          id name description highlights
          images { url description }
          leadPrice { display { amount currencyCode formatted } }
          reviews { summary { score totalCount } }
          region { id name fullName type coordinates { latitude longitude } parent { name } }
        }
      }
    }
    """

    static let propertyOperation = """
    query PropertySearch($criteria: PropertySearchCriteriaInput!, $first: Int) {
      propertySearch(criteria: $criteria, first: $first) {
        edges { property { id name images { url description } } }
      }
    }
    """

    private let configuration: TravelerCoreConfiguration
    private let session: URLSession

    init(configuration: TravelerCoreConfiguration = .init(), session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func regions(matching query: String, first: Int = 5) async throws -> [TravelerCoreRegion] {
        struct DataPayload: Decodable { var regionSearch: [TravelerCoreRegion] }
        let payload: DataPayload = try await execute(
            query: Self.regionOperation,
            variables: ["query": query, "first": max(1, first)]
        )
        return payload.regionSearch
    }

    func airports(matching query: String, first: Int = 5) async throws -> [TravelerCoreAirport] {
        struct DataPayload: Decodable { var airportSearch: [TravelerCoreAirport] }
        let payload: DataPayload = try await execute(
            query: Self.airportOperation,
            variables: ["query": query, "first": max(1, first)]
        )
        return payload.airportSearch
    }

    func activities(
        intent: EmbeddedIntent,
        region: TravelerCoreRegion,
        first: Int = 12
    ) async throws -> [TravelerCoreActivity] {
        struct Connection: Decodable { var edges: [TravelerCoreActivity] }
        struct DataPayload: Decodable { var activitySearch: Connection }
        guard let start = intent.departureDate else { throw TravelerCoreError.invalidConfiguration }
        let end = intent.returnDate ?? start
        let criteria: [String: Any] = [
            "destination": ["regionId": region.id],
            "dates": ["start": start, "end": end],
            "travelers": ["adults": max(1, intent.adults), "childAges": intent.children],
        ]
        let payload: DataPayload = try await execute(
            query: Self.activityOperation,
            variables: ["criteria": criteria, "first": max(1, first)]
        )
        return payload.activitySearch.edges
    }

    func properties(
        intent: EmbeddedIntent,
        region: TravelerCoreRegion,
        first: Int = 25
    ) async throws -> [TravelerCoreProperty] {
        struct Edge: Decodable { var property: TravelerCoreProperty }
        struct Connection: Decodable { var edges: [Edge] }
        struct DataPayload: Decodable { var propertySearch: Connection }
        guard let start = intent.departureDate, let end = intent.returnDate else {
            throw TravelerCoreError.invalidConfiguration
        }
        let criteria: [String: Any] = [
            "destination": ["regionId": region.id],
            "stay": [
                "dateRange": ["start": start, "end": end],
                "rooms": [["adults": max(1, intent.adults), "childAges": intent.children]],
            ],
        ]
        let payload: DataPayload = try await execute(
            query: Self.propertyOperation,
            variables: ["criteria": criteria, "first": max(1, first)]
        )
        return payload.propertySearch.edges.map(\.property)
    }

    private func execute<Value: Decodable>(
        query: String,
        variables: [String: Any]
    ) async throws -> Value {
        guard configuration.url.scheme == "https" || configuration.url.host == "localhost",
              JSONSerialization.isValidJSONObject(["query": query, "variables": variables])
        else { throw TravelerCoreError.invalidConfiguration }

        let body = try JSONSerialization.data(withJSONObject: ["query": query, "variables": variables])
        var attempt = 0
        while true {
            var request = URLRequest(url: configuration.url)
            request.httpMethod = "POST"
            request.timeoutInterval = configuration.timeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(configuration.site, forHTTPHeaderField: "ctx-site")
            request.setValue(configuration.locale, forHTTPHeaderField: "ctx-site-locale")
            request.setValue(configuration.currency, forHTTPHeaderField: "ctx-site-currency")
            request.httpBody = body

            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse else {
                    throw TravelerCoreError.malformedResponse
                }
                guard (200..<300).contains(http.statusCode) else {
                    if Self.retryable(http.statusCode), attempt < configuration.maximumRetries {
                        attempt += 1
                        try await retryDelay(attempt)
                        continue
                    }
                    throw TravelerCoreError.httpStatus(http.statusCode)
                }
                return try Self.decode(data)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as TravelerCoreError {
                throw error
            } catch {
                throw TravelerCoreError.transport
            }
        }
    }

    private func retryDelay(_ attempt: Int) async throws {
        let multiplier = UInt64(1 << min(attempt - 1, 4))
        try await Task.sleep(nanoseconds: configuration.retryDelayNanoseconds * multiplier)
    }

    private static func retryable(_ status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    private static func decode<Value: Decodable>(_ data: Data) throws -> Value {
        guard let envelope = try? JSONDecoder().decode(TravelerCoreEnvelope<Value>.self, from: data) else {
            throw TravelerCoreError.malformedResponse
        }
        if let errors = envelope.errors, !errors.isEmpty {
            throw TravelerCoreError.graphQL(errors.map(\.message))
        }
        guard let value = envelope.data else { throw TravelerCoreError.malformedResponse }
        return value
    }
}

enum TravelerCoreNormalizers {
    static func webURL(_ rawValue: String?) -> String? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        if value.hasPrefix("//") { value = "https:\(value)" }
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host != nil,
              url.user == nil,
              url.password == nil else { return nil }
        return url.absoluteString
    }

    static func firstImage(in images: [TravelerCoreImage]?) -> String? {
        images?.compactMap { webURL($0.url) }.first
    }

    static func normalizedName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }
}

struct TravelerCoreActivityProvider: EmbeddedActivityProviding {
    let client: any TravelerCoreProviding
    let available = true

    func search(intent: EmbeddedIntent) async throws -> [EmbeddedActivity] {
        guard let destination = intent.destinations.first,
              let region = try await client.regions(matching: destination, first: 1).first
        else { return [] }
        return try await client.activities(intent: intent, region: region, first: 12).map { activity in
            let display = activity.leadPrice?.display
            return EmbeddedActivity(
                id: activity.id,
                name: activity.name,
                description: activity.description ?? "",
                highlights: activity.highlights ?? [],
                price: display?.amount,
                formattedPrice: display?.formatted,
                currency: display?.currencyCode ?? "USD",
                rating: activity.reviews?.summary?.score,
                reviews: activity.reviews?.summary?.totalCount,
                imageURL: TravelerCoreNormalizers.firstImage(in: activity.images),
                dataSource: "traveler-core"
            )
        }
    }
}

struct TravelerCoreLodgingEnrichmentProvider: EmbeddedLodgingProviding {
    let primary: any EmbeddedLodgingProviding
    let client: any TravelerCoreProviding
    var available: Bool { primary.available }
    func readiness() async -> Bool { await primary.readiness() }

    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        let base = try await primary.search(intent: intent, summary: summary)
        do {
            guard let destination = intent.destinations.first,
                  let region = try await client.regions(matching: destination, first: 1).first
            else { return base }
            let graph = try await client.properties(intent: intent, region: region, first: max(25, base.count))
            return base.map { item in
                guard let match = graph.first(where: {
                    $0.id == item.id || TravelerCoreNormalizers.normalizedName($0.name)
                        == TravelerCoreNormalizers.normalizedName(item.name)
                }), let image = TravelerCoreNormalizers.firstImage(in: match.images)
                else { return item }
                var enriched = item
                enriched.imageURL = image
                return enriched
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return base
        }
    }
}

struct TravelerCoreDestinationEnrichmentProvider: EmbeddedDestinationProviding {
    let primary: any EmbeddedDestinationProviding
    let client: any TravelerCoreProviding
    var available: Bool { primary.available }
    func readiness() async -> Bool { await primary.readiness() }

    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        let base = try await primary.search(intent: intent, query: query)
        return await withTaskGroup(of: (Int, EmbeddedDestination).self) { group in
            for (index, item) in base.enumerated() {
                group.addTask {
                    do {
                        guard let region = try await client.regions(matching: item.name, first: 1).first else {
                            return (index, item)
                        }
                        var activityIntent = intent
                        activityIntent.destinations = [region.name]
                        let activities = try await client.activities(
                            intent: activityIntent,
                            region: region,
                            first: 3
                        )
                        guard let activity = activities.first else { return (index, item) }
                        var enriched = item
                        if let image = TravelerCoreNormalizers.firstImage(in: activity.images) {
                            enriched.imageURL = image
                            enriched.dataSource = "\(item.dataSource)+traveler-core"
                        }
                        return (index, enriched)
                    } catch {
                        return (index, item)
                    }
                }
            }
            var values: [(Int, EmbeddedDestination)] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}

struct ActivityDestinationEnrichmentProvider: EmbeddedDestinationProviding {
    let primary: any EmbeddedDestinationProviding
    let activityProvider: any EmbeddedActivityProviding
    var available: Bool { primary.available }
    func readiness() async -> Bool { await primary.readiness() }

    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] {
        let base = try await primary.search(intent: intent, query: query)
        return await withTaskGroup(of: (Int, EmbeddedDestination).self) { group in
            for (index, item) in base.enumerated() {
                group.addTask {
                    guard item.imageURL == nil else { return (index, item) }
                    var activityIntent = intent
                    activityIntent.destinations = [
                        [item.name, item.country].filter { !$0.isEmpty }.joined(separator: ", "),
                    ]
                    do {
                        guard let image = try await activityProvider.search(intent: activityIntent)
                            .compactMap(\.imageURL).first else { return (index, item) }
                        var enriched = item
                        enriched.imageURL = image
                        enriched.dataSource = "\(item.dataSource)+activity-content"
                        return (index, enriched)
                    } catch {
                        return (index, item)
                    }
                }
            }
            var values: [(Int, EmbeddedDestination)] = []
            for await value in group { values.append(value) }
            return values.sorted { $0.0 < $1.0 }.map(\.1)
        }
    }
}
