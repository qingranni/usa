//
//  Universal_Search_AppTests.swift
//  Universal Search AppTests
//
//  Created by Benas Skripka on 25/06/2026.
//

import Foundation
import MapKit
import Testing
@testable import Universal_Search_App

struct Universal_Search_AppTests {

    @Test @MainActor
    func dataSourceDefaultsToEmbeddedGenUIMode() {
        let store = AppStore()

        #expect(store.canvasNavigationStructure == .topBar)
        #expect(store.assistantSourceMode == .genUI)
    }

    @Test
    func productionProvidersContainNoFixtureFallbacks() {
        let providers = DirectMCPProviderFactory.providers()
        #expect(!String(reflecting: type(of: providers.0)).contains("Fallback"))
        #expect(!String(reflecting: type(of: providers.1)).contains("Fallback"))
        #expect(!String(reflecting: type(of: providers.2)).contains("Fallback"))
    }

    @Test
    func projectHasNoRemoteBackendOrPackageDependency() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let project = try String(
            contentsOf: repository.appending(path: "Universal Search App.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        #expect(!project.contains("XCLocalSwiftPackageReference"))
        #expect(!project.contains("XCSwiftPackageProductDependency"))
        #expect(!FileManager.default.fileExists(atPath: repository.appending(path: "backend/package.json").path))
    }

    @Test
    func embeddedDecisionPipelinePreservesFiveFixedStages() {
        var intent = EmbeddedIntent()
        intent.destinations = ["Cancun"]
        intent.departureDate = "2026-08-10"
        intent.returnDate = "2026-08-14"

        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )

        #expect(trace.disambiguation.level == .none)
        #expect(trace.sourcing.tasks.first { $0.source == "lodging" }?.readiness == .ready)
        #expect(trace.template.template == "results")
        #expect(trace.composition.recipe == "lodging")
        #expect(trace.guidance.intensity == "minimal")
    }

    @Test
    func embeddedDecisionPipelineAllowsPartialDestinationContent() {
        var intent = EmbeddedIntent()
        intent.destinations = ["London"]
        intent.products = [.lodging, .flight]
        intent.relationship = "package"

        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )

        #expect(trace.disambiguation.level == .partial)
        #expect(trace.sourcing.tasks.first { $0.source == "destination" }?.readiness == .ready)
        #expect(trace.sourcing.tasks.first { $0.source == "lodging" }?.readiness == .blocked)
        #expect(trace.template.template == "mixed-results")
        #expect(trace.composition.recipe == "partial")
    }

    @Test @MainActor
    func embeddedDataSourceAppliesPrototypeRetrievalDefaultsWithoutClarification() async throws {
        let source = EmbeddedGenUIDataSource(agent: fixtureAgent())
        let response = try await source.response(
            for: "hotels in London",
            continuation: nil,
            intentEvents: []
        )
        let payload = try #require(response.thread)

        #expect(payload.source == .genUI)
        #expect(payload.options.count == 3)
        #expect(!payload.blocks.contains { $0.semanticType == "clarification" })
        #expect(payload.continuation?.sessionId != nil)
        #expect(payload.decision?.disambiguationLevel == "none")
    }

    @Test @MainActor
    func regionalVacationProducesGroundedPricedDestinations() async throws {
        let result = try await fixtureAgent().run(
            query: "Mexico vacation ideas for two adults under $5000",
            continuation: nil,
            newEvents: []
        )
        let components = try #require(result.state.surfaces["search-results"]?.components)
        let cards = components.filter { $0.type == "destination-card" }

        #expect(cards.count > 1)
        #expect(cards.allSatisfy { $0.props["description"]?.stringValue?.isEmpty == false })
        #expect(cards.allSatisfy { $0.props["packageFrom"]?.doubleValue != nil })
        #expect(result.provenance.contains("authoritative") || result.provenance.contains("fixture"))
    }

    @Test @MainActor
    func regionalPackageProducesMultipleStayFlightBundles() async throws {
        let result = try await fixtureAgent().run(
            query: "Mexico package from Seattle for two adults under $5000",
            continuation: nil,
            newEvents: []
        )
        let components = try #require(result.state.surfaces["search-results"]?.components)
        let packages = components.filter { $0.type == "package-summary" }

        #expect(packages.count > 1)
        #expect(packages.allSatisfy { $0.props["departureDate"]?.stringValue != nil })
        #expect(packages.allSatisfy { $0.props["packageFrom"]?.doubleValue ?? 0 > 0 })
        #expect(packages.allSatisfy { $0.props["dataSource"]?.stringValue != nil })
    }

    @Test
    func nextMonthUsesFixedCalendarStayAndReadableConstraint() throws {
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-07-20T12:00:00Z")
        )
        let intent = EmbeddedRetrievalPolicy.enriched(
            EmbeddedIntent(),
            query: "London hotels next month",
            now: now
        )
        let header = try #require(
            EmbeddedSurfaceBuilder.header(intent: intent, refinements: []).first
        )
        let primary = try #require(header.props["primary"]?.arrayValue)

        #expect(intent.departureDate == "2026-08-01")
        #expect(intent.returnDate == "2026-08-05")
        #expect(primary.first?.objectValue?["label"]?.stringValue == "Aug 1 – Aug 5")
        #expect(primary.last?.objectValue?["label"]?.stringValue == "1 adult")
    }

    @Test
    func deterministicIntentUnderstandsPluralDestinationFirstProducts() async throws {
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-07-20T12:00:00Z")
        )
        let cases: [(String, [EmbeddedProduct], String)] = [
            ("Mexico packages", [.flight, .lodging], "package"),
            ("Mexico hotels", [.lodging], "single"),
            ("Mexico flights", [.flight], "single"),
            ("Planning a trip to Mexico need flights and hotels", [.flight, .lodging], "package"),
        ]

        for (query, products, relationship) in cases {
            let parsed = try await FixtureIntentProvider().parse(
                query: query,
                previousEvents: [],
                previousQuerySummary: nil
            )
            let compiled = EmbeddedIntentCompiler.compile(events: parsed.events, query: query)
            let intent = EmbeddedRetrievalPolicy.enriched(compiled, query: query, now: now)
            let trace = EmbeddedDecisionPipeline.decide(
                intent: intent,
                lodgingAvailable: true,
                flightAvailable: true,
                destinationAvailable: true,
                now: now
            )

            #expect(intent.destinations == ["Mexico"])
            #expect(intent.products == products)
            #expect(intent.relationship == relationship)
            #expect(trace.disambiguation.level == .none)
        }
    }

    @Test @MainActor
    func londonToMexicoNaturalLanguageFlightQueryPrioritizesResults() async throws {
        let query = "Flights to Mexico from London 2 people 20 July to 27 July"
        let now = try #require(
            ISO8601DateFormatter().date(from: "2026-07-20T12:00:00Z")
        )
        let compiled = EmbeddedIntentCompiler.compile(events: [], query: query)
        let intent = EmbeddedRetrievalPolicy.enriched(compiled, query: query, now: now)
        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true,
            now: now
        )

        #expect(intent.products == [.flight])
        #expect(intent.originAirport == "London")
        #expect(intent.destinations == ["Mexico"])
        #expect(intent.adults == 2)
        #expect(intent.departureDate == "2026-07-20")
        #expect(intent.returnDate == "2026-07-27")
        #expect(trace.sourcing.tasks.first { $0.source == "flight" }?.readiness == .ready)
        #expect(trace.template.map == "none")

        let result = try await fixtureAgent().run(query: query, continuation: nil, newEvents: [])
        let payload = try #require(try AgentStateMapper.map(state: result.state, query: query).thread)
        #expect(payload.options.count == 3)
        #expect(payload.kind == .flights)
        #expect(!payload.blocks.contains { $0.semanticType == "clarification" })
        #expect(!payload.presentation.showsMap)
        #expect(!payload.presentation.refinements.contains { $0.label == "Add dates" })
        #expect(payload.presentation.filters.contains("2 adults"))
    }

    @Test @MainActor
    func embeddedDataSourceReturnsFixtureInventoryAfterClarification() async throws {
        let source = EmbeddedGenUIDataSource(agent: fixtureAgent())
        let events = [
            ContinuationEvent(id: "destination", type: "ui-selection", timestamp: 1, field: "destinations", newValue: ["Cancun"], strength: "hard", source: "user"),
            ContinuationEvent(id: "depart", type: "ui-selection", timestamp: 2, field: "departureDate", newValue: "2026-08-10", strength: "hard", source: "user"),
            ContinuationEvent(id: "return", type: "ui-selection", timestamp: 3, field: "returnDate", newValue: "2026-08-14", strength: "hard", source: "user"),
        ]
        let response = try await source.response(
            for: "Cancun hotels with a pool",
            continuation: nil,
            intentEvents: events
        )
        let payload = try #require(response.thread)

        #expect(payload.options.count == 3)
        #expect(payload.options.first?.title == "Harbor House")
        #expect(payload.presentation.map?.pins.count == 3)
        #expect(!payload.blocks.contains { $0.semanticType == "result-state-summary" })
        #expect(payload.decision?.compositionRecipe == "lodging")
    }

    @Test
    func narrativeGoldenQueryUsesExactOrientationSnapshot() throws {
        let query = "mexico vacation"
        let resolution = try #require(NarrativeData.resolve(current: nil, text: query))
        let payload = try #require(resolution.response.thread)

        #expect(payload.scenarioID == NarrativeData.scenarioID)
        #expect(payload.scenarioStep == "orientation")
        #expect(payload.options.map(\.title) == ["Cancun", "Puerto Vallarta", "Playa del Carmen"])
        #expect(payload.options.map(\.price) == ["$4,850", "$4,780", "$4,720"])
        #expect(payload.options.map(\.imageURL) == [
            "mexico-orientation-cancun",
            "mexico-orientation-puerto-vallarta",
            "mexico-orientation-playa-del-carmen",
        ])
        #expect(payload.presentation.filters == [
            "Mexico", "Week of Mar 14", "3 travelers", "up to $5,000", "beach",
        ])
        #expect(payload.presentation.mapLayout == .standard)
        #expect(payload.presentation.canvasLayout == .mexicoOrientation)
        #expect(payload.source == .narrative)
        #expect(payload.composition == .blocks)
        #expect(payload.blocks.map(\.style) == [
            .heading, .text, .cards,
            .heading, .text, .carousel,
            .heading, .text, .carousel,
        ])
        #expect(payload.blocks[2].cardPresentation == .destinationHero)
        #expect(payload.blocks[5].cardPresentation == .destinationCarousel)
        #expect(payload.blocks[5].items.map(\.title) == ["San Pancho", "Isla Holbox"])
        #expect(payload.blocks[5].items.map(\.imageURL) == [
            "mexico-carousel-san-pancho",
            "mexico-carousel-isla-holbox",
        ])
        #expect(payload.blocks[8].cardPresentation == .destinationCarousel)
        #expect(payload.blocks[8].items.map(\.title) == ["Montego Bay", "Destin"])
    }

    @Test @MainActor
    func narrativeCancunPackagesMatchAuthoredSectionRecipe() throws {
        let resolution = try #require(
            NarrativeData.resolve(current: nil, text: "Cancun family packages under $5000")
        )
        let payload = try #require(resolution.response.thread)

        #expect(payload.scenarioStep == "packages")
        #expect(payload.composition == .packageShelves)
        #expect(payload.presentation.filters.count == 5)
        #expect(payload.options.count == 3)
        #expect(payload.options.first?.dateRange == "Mar 14–20")
        #expect(payload.options.first?.crossedOutPrice == "$5,058")
        #expect(payload.options.first?.discountText == "$274 off")
        #expect(payload.options.first?.rating == 8.8)
        #expect(payload.blocks.map(\.style) == [
            .heading, .text, .cards,
            .heading, .text, .carousel,
            .heading, .text, .carousel,
        ])
        #expect(payload.blocks[5].cardPresentation == .lodging)
        #expect(payload.blocks[5].items.map(\.title) == [
            "Hard Rock Hotel Cancun - All Inclusive",
            "Waldorf Astoria Riviera Maya",
        ])
        #expect(payload.blocks[8].cardPresentation == .flight)
        #expect(payload.blocks[8].items.map(\.title) == ["HOU → CUN", "IAH → CUN"])

        let thread = Mock.buildThreadNode(payload)
        let featured = try #require(thread.activeBlocks.first { $0.style == .cards })
        #expect(featured.cards.first?.dateRange == "Mar 14–20")
        #expect(featured.cards.first?.travelers == 3)
        #expect(featured.cards.first?.totalPrice == "$4,720")
        #expect(thread.activeBlocks.filter { $0.style == .carousel }.count == 2)

        let map = try #require(MapSpec.forThread(thread))
        #expect(map.points.count == 3)
        #expect(map.points.allSatisfy { !$0.showsLabel })
        #expect(map.region.center.latitude == 21.135)
        #expect(map.region.center.longitude == -86.77)
    }

    @Test @MainActor
    func narrativeGoldenQueryBuildsNativeMexicoMapSpec() throws {
        let query = "mexico vacation"
        let payload = try #require(NarrativeData.resolve(current: nil, text: query)?.response.thread)
        let thread = Mock.buildThreadNode(payload)
        let map = try #require(MapSpec.forThread(thread))

        #expect(map.points.map(\.label) == [
            "Houston", "Puerto Vallarta", "Cancun", "Playa del Carmen",
        ])
        #expect(map.connect == false)
        #expect(map.region.center.latitude == 23)
        #expect(map.region.center.longitude == -97)
        #expect(map.region.span.latitudeDelta == 18)
        #expect(map.region.span.longitudeDelta == 27)
    }

    @Test
    func narrativeCanEnterBranchesWithoutFollowingGoldenOrder() throws {
        let activities = try #require(
            NarrativeData.resolve(
                current: nil,
                text: "Teen-friendly snorkeling activities in Cancun"
            )
        )
        let flights = try #require(
            NarrativeData.resolve(
                current: nil,
                text: "Nonstop flights from Houston to Cancun with seats together"
            )
        )

        #expect(activities.response.thread?.scenarioStep == "activities")
        #expect(activities.response.thread?.kind == .activities)
        #expect(activities.response.thread?.composition == .blocks)
        #expect(activities.response.thread?.presentation.mapLayout == .standard)
        #expect(flights.response.thread?.scenarioStep == "flights")
        #expect(flights.response.thread?.kind == .flights)
        #expect(flights.response.thread?.composition == .flightList)
        #expect(flights.response.thread?.presentation.mapLayout == .standard)
    }

    @Test
    func narrativeReferentialQueryCreatesRefinedBranch() throws {
        let startResolution = try #require(
            NarrativeData.resolve(
                current: nil,
                text: "Mexico spring break beach trip with teens under $5000"
            )
        )
        let start = try #require(startResolution.response.thread)
        let thread = Mock.buildThreadNode(start)
        let resolution = try #require(
            NarrativeData.resolve(
                current: thread,
                text: "Make it right on the beach with a two bedroom suite and seats together"
            )
        )

        #expect(resolution.response.thread?.scenarioStep == "refined-packages")
        #expect(resolution.response.thread?.options.first?.title == "Hyatt Ziva Cancun")
        #expect(resolution.response.thread?.composition == .packageShelves)
    }

    @Test @MainActor
    func narrativeComposerFollowUpCreatesTripEntry() async throws {
        let startPayload = try #require(
            NarrativeData.resolve(
                current: nil,
                text: "Mexico spring break beach trip with teens under $5000"
            )?.response.thread
        )
        let original = Mock.buildThreadNode(startPayload)
        let store = AppStore()
        store.assistantSourceMode = .narrativeMock
        store.threads = [original]
        store.open(original.id)

        await store.send("Make it beachfront with a two bedroom suite and seats together")

        #expect(store.threads.count == 2)
        #expect(store.threads.first?.id == original.id)
        #expect(store.threads.first?.scenarioStep == "orientation")
        #expect(store.threads.last?.scenarioStep == "refined-packages")
    }

    @Test
    func narrativeDoesNotCaptureUnsupportedMexicoQueries() {
        #expect(
            NarrativeData.resolve(
                current: nil,
                text: "Business hotels in Mexico City near the office"
            ) == nil
        )
        #expect(
            NarrativeData.resolve(
                current: nil,
                text: "Restaurants in Oaxaca"
            ) == nil
        )
    }

    @Test
    func mockAndNarrativeShareCanonicalMexicoEntities() throws {
        let firstCatalogHotel = try #require(MexicoFixtureCatalog.hotels.first)
        let mockThread = try #require(
            DestinationData.response(text: "hotels in Cancun")?.prebuiltThread
        )

        #expect(mockThread.activeCards.first?.title == firstCatalogHotel.name)
        #expect(mockThread.activeCards.first?.imageURL == firstCatalogHotel.imageURL)

        let hotelIDs = Set(MexicoFixtureCatalog.hotels.map(\.id))
        let flightIDs = Set(MexicoFixtureCatalog.flights.map(\.id))
        let roomIDs = Set(MexicoFixtureCatalog.rooms.map(\.id))
        let activityIDs = Set(MexicoFixtureCatalog.activities.map(\.id))
        for package in MexicoFixtureCatalog.packages {
            #expect(hotelIDs.contains(package.hotelID))
            #expect(flightIDs.contains(package.flightID))
            #expect(package.roomIDs.allSatisfy(roomIDs.contains))
            #expect(package.activityIDs.allSatisfy(activityIDs.contains))
        }
    }

    @Test
    func mockDestinationTemplatePreservesListAndCarouselMix() throws {
        let thread = try #require(
            DestinationData.response(text: "plan a trip to Tampa")?.prebuiltThread
        )

        #expect(thread.source == .mock)
        #expect(thread.composition == .blocks)
        #expect(thread.activeBlocks.contains { $0.style == .cards })
        #expect(thread.activeBlocks.contains { $0.style == .carousel })
    }

    @Test @MainActor
    func dataSourceModesAreFlattenedToTwoOptions() {
        let store = AppStore()

        #expect(AssistantSourceMode.allCases == [.narrativeMock, .genUI])
        store.assistantSourceMode = .genUI
        #expect(store.assistantSourceMode == .genUI)
        store.assistantSourceMode = .narrativeMock
        #expect(store.assistantSourceMode == .narrativeMock)
    }

    @Test @MainActor
    func narrativeMockFallsBackToGenericMockResults() async {
        let store = AppStore()
        store.assistantSourceMode = .narrativeMock

        await store.send("hotels in London")

        #expect(store.threads.count == 1)
        #expect(store.threads.first?.source == .mock)
        #expect(store.dataSourceErrorMessage == nil)
        #expect(store.isLoading == false)
    }

    @Test @MainActor
    func narrativeMockRejectsQueriesWithoutNarrativeOrMockResults() async {
        let store = AppStore()
        store.assistantSourceMode = .narrativeMock

        await store.send("Restaurants in Oaxaca")

        #expect(store.threads.isEmpty)
        #expect(store.dataSourceErrorMessage != nil)
        #expect(store.isLoading == false)
    }

    @Test @MainActor
    func selectedGenUIRunsWithoutMockFallback() async {
        let response = AssistantResponse(
            reply: "Live results",
            thread: ThreadPayload(
                kind: .lodging,
                title: "London stays",
                summary: "Live results",
                label: "1 result",
                chip: "",
                options: [Option(title: "The Gen Hotel")]
            )
        )
        let source = StubGenUIDataSource(response: response)
        let store = AppStore(genUIDataSource: source)
        store.assistantSourceMode = .genUI

        await store.send("hotels in London")

        #expect(source.calls == 1)
        #expect(store.threads.first?.title == "London stays")
        #expect(store.dataSourceErrorMessage == nil)
    }

    @Test @MainActor
    func genUIMapsStreamedSurfaceIntoThreadPayload() throws {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "layout",
                        type: "flex",
                        children: [
                            A2UIComponent(
                                id: "heading",
                                type: "section-heading",
                                props: ["text": "Top picks", "level": 2]
                            ),
                            A2UIComponent(
                                id: "intro",
                                type: "text-block",
                                props: ["content": "Three central stays."]
                            ),
                            A2UIComponent(
                                id: "hotel",
                                type: "lodging-card",
                                props: [
                                    "id": "hotel-1",
                                    "name": "The Gen Hotel",
                                    "location": "London",
                                    "imageUrl": "https://example.com/hotel.jpg",
                                    "priceNightly": "$245",
                                    "priceTotal": "$735",
                                    "reviewScore": 9.1,
                                    "reviewCount": 420,
                                    "highlight": "Walkable location",
                                ]
                            ),
                        ]
                    ),
                ])
            ],
            template: .lodgingSearch,
            querySummary: "London hotels"
        )

        let response = try GenUIDataSource.map(state: state, query: "hotels in London")
        let payload = try #require(response.thread)
        let option = try #require(payload.options.first)

        #expect(payload.kind == .lodging)
        #expect(payload.title == "London hotels")
        #expect(payload.summary == "Three central stays.")
        #expect(payload.blocks.map(\.style) == [.heading, .text, .cards])
        #expect(payload.source == .genUI)
        #expect(payload.composition == .blocks)
        #expect(payload.blocks.last?.cardPresentation == .lodging)
        #expect(option.title == "The Gen Hotel")
        #expect(option.priceValue == 245)
        #expect(option.rating == 9.1)
        #expect(option.reviewCount == 420)
        #expect(option.imageURL == "https://example.com/hotel.jpg")
    }

    @Test @MainActor
    func genUIMapsPresentationAndOnlyAppliedOutputFilters() throws {
        let state = AgentState(
            surfaces: [
                "header-bar": SurfaceState(components: [
                    A2UIComponent(
                        id: "constraints",
                        type: "constraint-bar",
                        props: [
                            "primary": [
                                [
                                    "field": "departureDate",
                                    "label": "Jul 23 – Jul 24",
                                    "type": "set",
                                    "tier": "primary",
                                ],
                                [
                                    "field": "totalBudget",
                                    "label": "Budget",
                                    "type": "missing",
                                    "tier": "primary",
                                ],
                            ],
                            "secondary": [
                                [
                                    "field": "amenities",
                                    "label": "Pool",
                                    "type": "set",
                                    "tier": "secondary",
                                ],
                            ],
                            "refinements": [],
                        ]
                    ),
                ]),
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "hotel",
                        type: "lodging-card",
                        props: [
                            "id": "hotel-1",
                            "name": "The Gen Hotel",
                            "location": "London",
                        ]
                    ),
                    A2UIComponent(
                        id: "map",
                        type: "map-view",
                        props: ["pins": []]
                    ),
                ]),
            ],
            template: .lodgingSearch,
            querySummary: "London hotels"
        )

        let payload = try #require(
            GenUIDataSource.map(state: state, query: "hotels in London").thread
        )

        #expect(payload.title == "London hotels")
        #expect(payload.presentation.showsMap)
        #expect(payload.presentation.filters == ["Jul 23 – Jul 24", "Pool"])
    }

    @Test @MainActor
    func threadBuilderPreservesSystemPresentationWithoutInventingFilters() {
        let defaultNode = Mock.buildThreadNode(ThreadPayload(
            kind: .lodging,
            title: "London hotels",
            summary: "",
            label: "Results",
            chip: "",
            options: [Option(title: "Hotel")]
        ))
        let noMapNode = Mock.buildThreadNode(ThreadPayload(
            kind: .other,
            title: "Compare London stays",
            summary: "",
            label: "Comparison",
            chip: "",
            options: [Option(title: "A"), Option(title: "B")],
            presentation: ResultsPresentation(
                showsMap: false,
                filters: ["Refundable"]
            )
        ))

        #expect(defaultNode.presentation.showsMap)
        #expect(defaultNode.presentation.filters.isEmpty)
        #expect(!noMapNode.presentation.showsMap)
        #expect(noMapNode.presentation.filters == ["Refundable"])
    }

    @Test @MainActor
    func genUIRejectsSurfacesWithoutSupportedResults() {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(id: "map", type: "map-view"),
                ])
            ]
        )

        #expect(throws: GenUIDataSourceError.self) {
            try GenUIDataSource.map(state: state, query: "London")
        }
    }

    @Test @MainActor
    func genUIMapsFlightComponentsIntoLocalSwiftModels() throws {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "state",
                        type: "result-state-summary",
                        props: [
                            "headline": "4 prototype flight options",
                            "status": "provisional",
                            "detail": "Fixture fares are not bookable.",
                        ]
                    ),
                    A2UIComponent(
                        id: "flight",
                        type: "flight-card",
                        props: [
                            "id": "fixture-JFK-LAX-DL-0",
                            "airline": "Delta",
                            "flightNumber": "DL120",
                            "origin": "JFK",
                            "destination": "LAX",
                            "departureTime": "07:10",
                            "arrivalTime": "10:40",
                            "durationMinutes": 330,
                            "price": 238,
                            "totalPrice": 476,
                            "currency": "USD",
                            "stops": 0,
                            "class": "economy",
                            "dataSource": "fixture",
                            "provisional": true,
                        ]
                    ),
                ])
            ],
            template: .flightList,
            querySummary: "JFK to LAX"
        )

        let response = try GenUIDataSource.map(state: state, query: "flights")
        let payload = try #require(response.thread)
        let option = try #require(payload.options.first)

        #expect(payload.kind == .flights)
        #expect(payload.composition == .flightList)
        #expect(option.title == "JFK → LAX")
        #expect(option.departTime == "07:10")
        #expect(option.priceValue == 476)
        #expect(payload.blocks.first?.semanticType == "result-state-summary")
    }

    @Test @MainActor
    func genUIMapsPackageSummariesIntoLocalPackageCards() throws {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "package-cun",
                        type: "package-summary",
                        props: [
                            "id": "package-cun",
                            "area": "Cancún and Riviera Maya",
                            "destination": "Cancun, Mexico",
                            "airportCodes": ["CUN"],
                            "currency": "USD",
                            "flightTotal": 1038,
                            "lodgingBudgetRemaining": 3962,
                            "packageFrom": 3538,
                            "fitCount": 7,
                            "priceBasis": "Fixture airfare plus current lodging total.",
                            "dataSource": "mixed",
                        ]
                    ),
                ])
            ],
            template: .packageOverview,
            querySummary: "Mexico beach package"
        )

        let payload = try #require(
            GenUIDataSource.map(state: state, query: "Mexico package").thread
        )
        let option = try #require(payload.options.first)

        #expect(payload.kind == .other)
        #expect(payload.composition == .packageShelves)
        #expect(option.title == "Cancún and Riviera Maya")
        #expect(option.priceValue == 3538)
        #expect(option.totalPrice?.contains("lodging budget") == true)
    }

    @Test @MainActor
    func genUIPreservesSemanticOnlyClarificationWithoutSyntheticCards() throws {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "clarification-dates",
                        type: "clarification",
                        props: [
                            "field": "departureDate",
                            "question": "Are these travel dates right?",
                            "reason": "Dates are required for current inventory.",
                            "required": true,
                            "suggestion": [
                                "departureDate": "2026-07-23",
                                "returnDate": "2026-07-24",
                            ],
                        ]
                    ),
                ])
            ],
            template: .clarification,
            querySummary: "Hotels in London"
        )

        let payload = try #require(
            GenUIDataSource.map(state: state, query: "Hotels in London").thread
        )
        let thread = Mock.buildThreadNode(payload)

        #expect(payload.options.isEmpty)
        #expect(payload.blocks.first?.semanticType == "clarification")
        #expect(!payload.presentation.showsMap)
        #expect(payload.presentation.filters.isEmpty)
        #expect(thread.activeCards.isEmpty)
        #expect(thread.activeBlocks.first?.semanticType == "clarification")
    }

    @Test @MainActor
    func genUIPreservesContinuationClarificationRefinementsAndMapPins() throws {
        let event = IntentEvent(
            id: "event-1",
            type: .refinement,
            timestamp: 123,
            field: "amenities",
            newValue: ["pool"],
            source: .user,
            rawInput: "Pool",
            provenance: "test"
        )
        let state = AgentState(
            surfaces: [
                "header-bar": SurfaceState(components: [
                    A2UIComponent(
                        id: "constraints",
                        type: "constraint-bar",
                        props: ["primary": [], "secondary": [], "refinements": ["Beachfront"]]
                    ),
                ]),
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "clarification",
                        type: "clarification",
                        props: [
                            "field": "departureDate",
                            "question": "Are these dates right?",
                            "reason": "Dates are required.",
                            "required": true,
                            "suggestion": [
                                "departureDate": "2026-08-10",
                                "returnDate": "2026-08-14",
                            ],
                            "suggestionLabel": "Use Aug 10–14",
                        ]
                    ),
                    A2UIComponent(
                        id: "map",
                        type: "map-view",
                        props: [
                            "center": ["lat": 21.16, "lng": -86.85],
                            "zoom": 11,
                            "pins": [
                                ["id": "hotel-1", "lat": 21.15, "lng": -86.84, "label": "Hotel One"],
                            ],
                        ]
                    ),
                ]),
            ],
            intentEvents: [event],
            sessionId: "session-1",
            template: .mixedResults,
            querySummary: "Cancún stays"
        )

        let payload = try #require(
            GenUIDataSource.map(state: state, query: "Cancún").thread
        )
        let mapped = try #require(
            payload.blocks.first?.semanticProps["mappedActions"]?.arrayValue?.first?.objectValue
        )

        #expect(payload.continuation?.sessionId == "session-1")
        #expect(payload.continuation?.querySummary == "Cancún stays")
        #expect(payload.continuation?.intentEvents.first?.rawInput == "Pool")
        #expect(mapped["label"]?.stringValue == "Use Aug 10–14")
        #expect(mapped["field"]?.stringValue == "departureDate")
        #expect(payload.presentation.refinements.map(\.label) == ["Beachfront"])
        #expect(payload.presentation.map?.pins.first?.label == "Hotel One")
        #expect(payload.presentation.map?.centerLatitude == 21.16)
    }

    @Test @MainActor
    func genUIMapsNestedRawDecisionTraceWithoutOwningPolicy() throws {
        let state = AgentState(
            surfaces: [
                "search-results": SurfaceState(components: [
                    A2UIComponent(
                        id: "outer",
                        type: "egds-flex",
                        children: [
                            A2UIComponent(
                                id: "guidance-usher",
                                type: "section-heading",
                                props: [
                                    "text": "A few details will improve these options",
                                    "tone": "exploratory",
                                    "intensity": "active",
                                    "decisionTrace": [
                                        "disambiguation": ["level": "partial"],
                                        "template": [
                                            "template": "mixed-results",
                                            "map": "results",
                                        ],
                                        "composition": [
                                            "recipe": "partial",
                                            "tone": "exploratory",
                                        ],
                                        "guidance": [
                                            "intensity": "active",
                                            "suggestionDensity": 0.75,
                                            "foregroundAttributes": ["departureDate", "totalBudget"],
                                            "promptPlacement": "inline",
                                        ],
                                    ],
                                ]
                            ),
                            A2UIComponent(
                                id: "body",
                                type: "text-block",
                                props: ["content": "Partial destination results."]
                            ),
                        ]
                    ),
                ]),
            ],
            querySummary: "Flexible beach trip"
        )

        let decision = try #require(
            GenUIDataSource.map(state: state, query: "Beach trip").thread?.decision
        )

        #expect(decision.disambiguationLevel == "partial")
        #expect(decision.templateKind == "mixed-results")
        #expect(decision.mapPolicy == "results")
        #expect(decision.compositionRecipe == "partial")
        #expect(decision.compositionTone == "exploratory")
        #expect(decision.guidanceIntensity == "active")
        #expect(decision.suggestionDensity == 0.75)
        #expect(decision.foregroundAttributes == ["departureDate", "totalBudget"])
        #expect(decision.promptPlacement == "inline")
    }

    @Test @MainActor
    func genUIRefinementMutatesThreadAndSendsRetainedContext() async throws {
        let firstContinuation = SearchContinuation(
            sessionId: "session-1",
            intentEvents: [
                ContinuationEvent(
                    id: "old",
                    type: "refinement",
                    timestamp: 1,
                    field: "amenities",
                    newValue: ["pool"],
                    source: "user"
                ),
            ],
            querySummary: "Cancún stays"
        )
        let response = AssistantResponse(
            reply: "Refined",
            thread: ThreadPayload(
                kind: .lodging,
                title: "Beachfront Cancún stays",
                summary: "Updated",
                label: "1 result",
                chip: "",
                options: [Option(title: "Hotel Two")],
                source: .genUI,
                continuation: firstContinuation
            )
        )
        let source = StubGenUIDataSource(response: response)
        let store = AppStore(genUIDataSource: source)
        store.assistantSourceMode = .genUI
        var initial = Mock.buildThreadNode(response.thread!)
        initial.title = "Cancún stays"
        store.threads = [initial]
        store.open(initial.id)

        await store.submit(RefinementAction(
            id: "beachfront",
            label: "Beachfront",
            field: "amenities",
            value: ["beachfront"],
            query: "Beachfront",
            kind: .selection
        ))

        #expect(store.threads.count == 1)
        #expect(store.threads.first?.id == initial.id)
        #expect(store.threads.first?.title == "Beachfront Cancún stays")
        #expect(source.lastContinuation?.sessionId == "session-1")
        #expect(source.lastIntentEvents.first?.field == "amenities")
        #expect(source.lastIntentEvents.first?.newValue == ["beachfront"])
    }

    @Test @MainActor
    func genUIQueryRefinementUsesContinuationWithoutSyntheticEvents() async {
        let continuation = SearchContinuation(
            sessionId: "session-1",
            intentEvents: [
                ContinuationEvent(
                    id: "retained",
                    type: "query",
                    timestamp: 1,
                    source: "user",
                    rawInput: "Cancún stays"
                ),
            ],
            querySummary: "Cancún stays"
        )
        let response = AssistantResponse(
            reply: "Refined",
            thread: ThreadPayload(
                kind: .lodging,
                title: "Beachfront Cancún stays",
                summary: "Updated",
                label: "Results",
                chip: "",
                options: [Option(title: "Hotel")],
                source: .genUI,
                continuation: continuation
            )
        )
        let source = StubGenUIDataSource(response: response)
        let store = AppStore(genUIDataSource: source)
        store.assistantSourceMode = .genUI
        let initial = Mock.buildThreadNode(response.thread!)
        store.threads = [initial]
        store.open(initial.id)

        await store.submit(RefinementAction(
            id: "beachfront",
            label: "Beachfront",
            query: "Beachfront",
            kind: .query
        ))

        #expect(source.lastContinuation?.intentEvents.map(\.id) == ["retained"])
        #expect(source.lastIntentEvents.isEmpty)
        #expect(store.threads.count == 1)
    }

    @Test
    func specializedLayoutsRetainSemanticBlocks() {
        let semantic = ResultBlock(
            id: "status",
            style: .text,
            text: "Partial results",
            semanticType: "result-state-summary"
        )
        let payload = ThreadPayload(
            kind: .flights,
            title: "Flights",
            summary: "",
            label: "Results",
            chip: "",
            options: [],
            composition: .flightList,
            blocks: [
                BlockSpec(
                    style: .text,
                    text: semantic.text,
                    semanticType: semantic.semanticType
                ),
            ]
        )
        let thread = Mock.buildThreadNode(payload)

        #expect(thread.specializedSemanticBlocks.map(\.semanticType) == ["result-state-summary"])
    }

    @Test @MainActor
    func serverMapPinsOverrideBakedMapFallback() throws {
        let payload = ThreadPayload(
            kind: .lodging,
            title: "Cancún stays",
            summary: "",
            label: "Results",
            chip: "",
            options: [],
            presentation: ResultsPresentation(
                showsMap: true,
                map: ServerMapPresentation(
                    pins: [
                        ServerMapPin(id: "custom", latitude: 1.5, longitude: 2.5, label: "Custom"),
                    ],
                    centerLatitude: 1.6,
                    centerLongitude: 2.6,
                    zoom: 10
                )
            )
        )
        let spec = try #require(MapSpec.forThread(Mock.buildThreadNode(payload)))

        #expect(spec.points.map(\.label) == ["Custom"])
        #expect(spec.region.center.latitude == 1.6)
        #expect(spec.region.center.longitude == 2.6)
    }

    @Test
    func imageCatalogKeysAreUniqueAndKindValidated() {
        #expect(Set(ImageLibrary.keys).count == ImageLibrary.keys.count)
        #expect(
            ImageLibrary.imageURL(forKey: "lodging_beach_resort", kind: .lodging)
                == "https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80"
        )
        #expect(ImageLibrary.imageURL(forKey: "lodging_beach_resort", kind: .activities) == nil)
        #expect(ImageLibrary.imageURL(forKey: "not_a_catalog_key", kind: .lodging) == nil)
    }

    @Test
    func selectedCatalogImageWinsDuringCardHydration() {
        let selected = ImageLibrary.imageURL(forKey: "lodging_private_villa", kind: .lodging)
        let card = Mock.buildCard(
            threadId: "thread",
            setId: "set",
            index: 0,
            kind: .lodging,
            title: "Generic stay",
            detail: "No matching image words",
            image: selected
        )

        #expect(selected != nil)
        #expect(card.imageURL == selected)
    }

    @Test
    func imageScoringFallbackIsDeterministicAndKindScoped() {
        let text = "A result without catalog tags"
        let first = ImageLibrary.pickImage(text, kind: .cars)
        let second = ImageLibrary.pickImage(text, kind: .cars)
        let carURLs = Set(
            ImageLibrary.entries
                .filter { $0.kind == .cars }
                .map(\.url)
        )

        #expect(first == second)
        #expect(first != nil)
        #expect(first.map { carURLs.contains($0) } == true)
    }

    @Test(.serialized)
    func gptIntentProviderSendsSchemaAndParsesEvents() async throws {
        let content = """
        {"events":[{"field":"goal","valueJSON":"\\"explore\\"","strength":"hard","source":"user","confidence":0.95}],"querySummary":"Flexible beach trip","suggestions":[],"refinements":["Add dates","Set budget","Choose region","Add style","Set duration"]}
        """
        var capturedSchemaName: String?
        var capturedAuthorization: String?
        GPTURLProtocol.handler = { request in
            let json = try requestJSONObject(request)
            let format = json["response_format"] as? [String: Any]
            let schema = format?["json_schema"] as? [String: Any]
            capturedSchemaName = schema?["name"] as? String
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            return try GPTURLProtocol.response(for: request, content: content)
        }
        let provider = GPTIntentProvider(configuration: .init(
            apiKey: "test-key",
            model: "test-model",
            baseURL: URL(string: "https://unit.test/v1")!
        ), session: GPTURLProtocol.session())

        let result = try await provider.parse(
            query: "somewhere warm",
            previousEvents: [],
            previousQuerySummary: nil
        )

        #expect(result.querySummary == "Flexible beach trip")
        #expect(result.events.first?.field == "goal")
        #expect(result.events.first?.newValue?.stringValue == "explore")
        #expect(result.events.first?.provenance == "gpt-schema")
        #expect(result.refinements.count == 5)
        #expect(capturedSchemaName == "travel_intent_events")
        #expect(capturedAuthorization == "Bearer test-key")
    }

    @Test
    func gptPrototypeSessionScopesTrustToConfiguredHost() throws {
        let configuration = EmbeddedGPTConfiguration(
            apiKey: "test-key",
            model: "test-model",
            baseURL: URL(string: "https://unit.test/v1")!
        )
        let session = EmbeddedGPTSessionFactory.session(
            for: configuration,
            enablePrototypeTrust: true
        )
        let delegate = try #require(session.delegate as? GPTPrototypeTLSDelegate)

        #if DEBUG
        #expect(delegate.prototypeTrustEnabled)
        #else
        #expect(!delegate.prototypeTrustEnabled)
        #endif
        #expect(delegate.trustedHost == "unit.test")
        #expect(session.configuration !== URLSession.shared.configuration)
    }

    @Test
    func embeddedGPTDefaultsToConfiguredProxyAndNanoModel() {
        #expect(EmbeddedLiveProviderFactory.defaultModel == "gpt-5.4-nano-2026-03-17")
        #expect(
            EmbeddedLiveProviderFactory.defaultBaseURL.absoluteString
                == "https://generative-ai-proxy.rcp.us-east-1.data.test.exp-aws.net/v1/proxy/azure-openai/chat/completions"
        )
    }

    @Test
    func gptPrototypeSessionCanRetainNormalTrust() throws {
        let configuration = EmbeddedGPTConfiguration(
            apiKey: "test-key",
            model: "test-model",
            baseURL: URL(string: "https://unit.test/v1")!
        )
        let session = EmbeddedGPTSessionFactory.session(
            for: configuration,
            enablePrototypeTrust: false
        )
        let delegate = try #require(session.delegate as? GPTPrototypeTLSDelegate)

        #expect(!delegate.prototypeTrustEnabled)
    }

    @Test(.serialized)
    func gptIntentProviderIncludesPreviousContext() async throws {
        let prior = IntentEvent(
            id: "prior",
            type: .inference,
            timestamp: 1,
            field: "amenities",
            newValue: ["Pool"],
            source: .user,
            rawInput: "pool",
            provenance: "test"
        )
        var capturedPrompt: String?
        GPTURLProtocol.handler = { request in
            let json = try requestJSONObject(request)
            let messages = json["messages"] as? [[String: String]]
            capturedPrompt = messages?.last?["content"]
            return try GPTURLProtocol.response(
                for: request,
                content: #"{"events":[],"querySummary":"Cancun pool hotels","suggestions":[],"refinements":["A","B","C","D","E"]}"#
            )
        }
        let provider = GPTIntentProvider(
            configuration: .init(apiKey: "test-key", model: "test-model", baseURL: URL(string: "https://unit.test/v1")!),
            session: GPTURLProtocol.session()
        )

        let result = try await provider.parse(
            query: "with a pool",
            previousEvents: [prior],
            previousQuerySummary: "Cancun hotels"
        )

        #expect(result.querySummary == "Cancun pool hotels")
        #expect(capturedPrompt?.contains("Previous summary: Cancun hotels") == true)
        #expect(capturedPrompt?.contains("\"amenities\"") == true)
    }

    @Test(.serialized)
    func gptInspirationProviderParsesProvisionalCandidates() async throws {
        GPTURLProtocol.handler = { request in
            return try GPTURLProtocol.response(
                for: request,
                content: #"{"candidates":[{"name":"Lisbon","country":"Portugal","description":"Coast and culture","highlights":["Food","Walkable"]}]}"#
            )
        }
        let provider = GPTInspirationProvider(
            configuration: .init(apiKey: "test-key", model: "test-model", baseURL: URL(string: "https://unit.test/v1")!),
            session: GPTURLProtocol.session()
        )

        let candidates = try await provider.suggest(intent: EmbeddedIntent(), query: "somewhere interesting")

        #expect(candidates.first?.name == "Lisbon")
        #expect(candidates.first?.dataSource == "gpt-provisional")
    }

    @Test(.serialized)
    func intentProviderFallsBackAfterTransportFailure() async throws {
        GPTURLProtocol.handler = { _ in throw URLError(.cannotConnectToHost) }
        let live = GPTIntentProvider(
            configuration: .init(apiKey: "test-key", model: "test-model", baseURL: URL(string: "https://unit.test/v1")!),
            session: GPTURLProtocol.session()
        )
        let provider = FallbackIntentProvider(primary: live, fallback: FixtureIntentProvider())

        let result = try await provider.parse(
            query: "hotels in London",
            previousEvents: [],
            previousQuerySummary: nil
        )

        #expect(result.events.contains { $0.provenance == "embedded-fixture-intent" })
    }

    @Test
    func mcpSSEParserUsesFinalJSONRPCEvent() {
        let parsed = StreamableHTTPMCPClient.parseSSE(
            "event: message\ndata: {\"result\":{\"page\":1}}\n\n"
                + "event: message\ndata: {\"result\":{\"page\":2}}\n\n"
        )
        #expect(parsed?.objectValue?["result"]?.objectValue?["page"]?.doubleValue == 2)
    }

    @Test(.serialized)
    func mcpClientInitializesRetainsSessionAndFiltersArguments() async throws {
        var methods: [String] = []
        var retainedSession = true
        var calledArguments: [String: Any]?
        MCPURLProtocol.handler = { request in
            let json = try requestJSONObject(request)
            guard let method = json["method"] as? String else { throw URLProtocolTestError.invalidJSON }
            methods.append(method)
            if method != "initialize" {
                retainedSession = retainedSession
                    && request.value(forHTTPHeaderField: "mcp-session-id") == "session-test"
            }
            let result: Any
            switch method {
            case "initialize": result = [:]
            case "notifications/initialized": return try MCPURLProtocol.response(request, status: 202, body: nil)
            case "tools/list":
                result = ["tools": [[
                    "name": "namespace-search_lodging",
                    "inputSchema": [
                        "properties": ["query": [:], "checkIn": [:]],
                        "required": ["query"],
                    ],
                ]]]
            default:
                let params = json["params"] as? [String: Any]
                calledArguments = params?["arguments"] as? [String: Any]
                result = ["content": []]
            }
            return try MCPURLProtocol.response(
                request,
                body: ["jsonrpc": "2.0", "id": json["id"] as Any, "result": result]
            )
        }
        let client = StreamableHTTPMCPClient(
            configuration: .init(url: URL(string: "https://mcp.unit.test")!),
            session: MCPURLProtocol.session()
        )
        let catalog = MCPCapabilityCatalog(client: client)
        _ = try await catalog.call("search_lodging", params: [
            "query": "London", "checkIn": "2026-09-10", "ignored": true,
        ])

        #expect(methods == ["initialize", "notifications/initialized", "tools/list", "tools/call"])
        #expect(retainedSession)
        #expect(calledArguments?["query"] as? String == "London")
        #expect(calledArguments?["ignored"] == nil)
    }

    @Test
    func mcpNormalizersDecodeLiveContracts() throws {
        let lodging: JSONValue = [
            "properties": [[
                "propertyId": "p1", "propertyName": "Test Hotel",
                "priceNightly": "$103.50", "priceTotal": "$233.75",
                "imageURL": "https://images.example.com/top-level.jpg",
                "location": [
                    "coordinates": ["lat": 51.5074, "lng": -0.1278],
                ],
            ]],
        ]
        let normalizedLodging = try #require(
            MCPNormalizers.lodging(lodging, destination: "London").first
        )
        #expect(normalizedLodging.nightly == 103.5)
        #expect(normalizedLodging.latitude == 51.5074)
        #expect(normalizedLodging.longitude == -0.1278)
        #expect(normalizedLodging.imageURL == "https://images.example.com/top-level.jpg")

        let destination: JSONValue = [
            "entities": [[
                "id": "3517", "name": "Tampa", "desc": "A sunny Gulf Coast city.",
                "affinities": ["Beaches", "Food"],
            ]],
        ]
        #expect(MCPNormalizers.destinations(destination).first?.name == "Tampa")

        let activity: JSONValue = [
            "activities": [[
                "id": "activity-1",
                "title": "Reef tour",
                "description": "Guided snorkeling trip",
                "duration": ["text": "4h"],
                "features": ["freeCancellation", "instantConfirmation"],
                "images": [["url": "https://images.example.com/reef.jpg"]],
                "leadPrice": ["amount": "68.87", "currency": "USD"],
            ]],
        ]
        let normalizedActivity = try #require(MCPNormalizers.activities(activity).first)
        #expect(normalizedActivity.name == "Reef tour")
        #expect(normalizedActivity.price == 68.87)
        #expect(normalizedActivity.imageURL == "https://images.example.com/reef.jpg")
        #expect(normalizedActivity.highlights.contains("4h"))
        #expect(MCPNormalizers.knownAirport("New York") == "JFK")
        #expect(MCPNormalizers.knownAirport("sfo") == "SFO")

        var intent = EmbeddedIntent()
        intent.destinations = ["Tampa"]
        intent.originAirport = "LAX"
        intent.adults = 2
        let flightData = Data(#"""
        {"result":{"offer":[{"offerId":"live-1","flightOffer":{"priceSummary":{"total":{"currencyCode":"USD","amount":"127958","decimalPlaces":2}},"priceDetails":{"travelerCategoryPrice":[{"total":{"amount":"63979","decimalPlaces":2}}]},"airProducts":[{"cabinClass":"CABIN_CLASS_COACH","airOriginDestinations":[{"airSegment":[{"marketingCarrierCode":"DL","marketingFlightNumber":"123","accumulatedDuration":275,"airLegs":[{"departureAirportCode":"LAX","arrivalAirportCode":"TPA","departureDateTime":"2026-09-10T08:00:00","arrivalDateTime":"2026-09-10T15:35:00"}]}]}]}]}}]}}
        """#.utf8)
        let flight = try JSONDecoder().decode(JSONValue.self, from: flightData)
        let normalized = try #require(MCPNormalizers.flights(flight, intent: intent).first)
        #expect(normalized.total == 1279.58)
        #expect(normalized.price == 639.79)
        #expect(normalized.cabin == "CABIN_CLASS_COACH")

        let standardData = Data(#"""
        {"content":[{"type":"text","text":"```json\n{\"data\":[{\"id\":\"standard-1\",\"price\":{\"currency\":\"USD\",\"grandTotal\":\"842.20\"},\"itineraries\":[{\"duration\":\"PT5H30M\",\"segments\":[{\"departure\":{\"iataCode\":\"LAX\",\"at\":\"2026-09-10T08:00:00\"},\"arrival\":{\"iataCode\":\"TPA\",\"at\":\"2026-09-10T13:30:00\"},\"carrierCode\":\"DL\",\"number\":\"456\",\"duration\":\"PT5H30M\"}]}]}]}\n```"}]}
        """#.utf8)
        let standard = try JSONDecoder().decode(JSONValue.self, from: standardData)
        let normalizedStandard = try #require(MCPNormalizers.flights(standard, intent: intent).first)
        #expect(normalizedStandard.total == 842.20)
        #expect(normalizedStandard.price == 421.10)
        #expect(normalizedStandard.origin == "LAX")
        #expect(normalizedStandard.destination == "TPA")
    }

    @Test
    func lodgingNormalizerSupportsNestedImagesAndRejectsInvalidPins() throws {
        let result: JSONValue = [
            "properties": [
                [
                    "propertyId": "nested",
                    "propertyName": "Nested Image Hotel",
                    "media": [
                        "images": [[
                            "url": "https://images.example.com/nested.jpg",
                        ]],
                    ],
                    "geo": [
                        "coordinates": [-0.1419, 51.5014],
                    ],
                ],
                [
                    "propertyId": "zero",
                    "propertyName": "No Coordinate Hotel",
                    "imageUrl": "not-a-url",
                    "coordinates": ["latitude": 0, "longitude": 0],
                ],
                [
                    "propertyId": "range",
                    "propertyName": "Out of Range Hotel",
                    "coordinates": ["latitude": 95, "longitude": 181],
                ],
            ],
        ]
        let lodging = MCPNormalizers.lodging(result, destination: "London")

        #expect(lodging[0].imageURL == "https://images.example.com/nested.jpg")
        #expect(lodging[0].latitude == 51.5014)
        #expect(lodging[0].longitude == -0.1419)
        #expect(lodging[1].imageURL == nil)
        #expect(lodging[1].latitude == nil)
        #expect(lodging[1].longitude == nil)
        #expect(lodging[2].latitude == nil)
        #expect(lodging[2].longitude == nil)
    }

    @Test
    func flightOfferPayloadMatchesGatewayEnvelope() throws {
        var intent = EmbeddedIntent()
        intent.originAirport = "SEA"
        intent.destinations = ["CUN"]
        intent.departureDate = "2026-07-28"
        intent.returnDate = "2026-07-29"

        let payload = try DirectMCPFlightProvider.payload(
            intent: intent,
            deviceID: "test-device"
        )

        #expect(payload.objectValue?["jsonrpc"]?.stringValue == "2.0")
        #expect(payload.objectValue?["method"] == nil)
        let searchObject = payload.objectValue?["params"]?.objectValue?["searchObject"]?.objectValue
        let wrapper = searchObject?["regularSearch"]?.objectValue?["flightSearchInfo"]?.objectValue
        let flightInfo = wrapper?["flightSearchInfo"]?.objectValue
        #expect(flightInfo?["context"] != nil)
        #expect(flightInfo?["searchCriteria"] != nil)
    }

    @Test @MainActor
    func lodgingCardsMapImagesAndFallbackMapWhenPinsAreUnavailable() throws {
        let live: JSONValue = [
            "properties": [[
                "propertyId": "p1",
                "propertyName": "London House",
                "image": ["url": "https://images.example.com/london-house.jpg"],
            ]],
        ]
        let lodging = MCPNormalizers.lodging(live, destination: "London")
        var intent = EmbeddedIntent()
        intent.destinations = ["London"]
        intent.departureDate = "2026-08-01"
        intent.returnDate = "2026-08-05"
        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )
        let components = EmbeddedSurfaceBuilder.results(
            intent: intent,
            trace: trace,
            lodging: lodging,
            flights: [],
            destinations: []
        )
        let state = AgentState(
            surfaces: ["search-results": SurfaceState(components: components)],
            template: .lodgingList,
            querySummary: "London hotels next month"
        )
        let payload = try #require(
            try AgentStateMapper.map(state: state, query: "London hotels next month").thread
        )

        #expect(components.contains { $0.type == "lodging-card" && $0.props["imageUrl"]?.stringValue == "https://images.example.com/london-house.jpg" })
        #expect(!components.contains { $0.type == "map-view" })
        #expect(!components.contains { $0.type == "result-state-summary" })
        #expect(payload.options.first?.imageURL == "https://images.example.com/london-house.jpg")
        #expect(payload.presentation.showsMap)
        #expect(payload.presentation.map == nil)
        let map = try #require(MapSpec.forThread(Mock.buildThreadNode(payload)))
        #expect(map.points.first?.coordinate.latitude == 51.5074)
        #expect(map.points.first?.coordinate.longitude == -0.1278)
    }

    @Test
    func malformedLiveProviderFallsBackToLabeledFixture() async throws {
        let malformed = MalformedLodgingProvider()
        let provider = FallbackLodgingProvider(primary: malformed, fallback: FixtureTravelProvider())
        var intent = EmbeddedIntent()
        intent.destinations = ["London"]
        intent.departureDate = "2026-09-10"
        intent.returnDate = "2026-09-13"

        let results = try await provider.search(intent: intent, summary: "London hotels")
        #expect(results.first?.dataSource == "fixture")
        #expect(results.first?.id.hasPrefix("fixture-") == true)
    }

    @Test
    func embeddedDecisionMatrixCoversBlockingPartialExploreCompareAndPackage() {
        let unavailable = EmbeddedDecisionPipeline.decide(
            intent: EmbeddedIntent(),
            lodgingAvailable: false,
            flightAvailable: false,
            destinationAvailable: false
        )
        #expect(unavailable.disambiguation.level == .blocking)
        #expect(unavailable.disambiguation.actions.contains { $0.field == "destinations" && $0.type == "ask-blocking" })
        #expect(unavailable.sourcing.tasks.first?.readiness == .blocked)
        #expect(unavailable.template.template == "clarification")
        #expect(unavailable.template.map == "none")
        #expect(unavailable.composition.recipe == "clarification")
        #expect(unavailable.guidance.promptPlacement == "leading")

        var explore = EmbeddedIntent()
        explore.goal = .explore
        explore.products = [.lodging, .flight]
        explore.relationship = "package"
        let immersive = EmbeddedDecisionPipeline.decide(
            intent: explore,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )
        #expect(immersive.disambiguation.level == .immersive)
        #expect(immersive.sourcing.tasks.first { $0.source == "destination" }?.readiness == .ready)
        #expect(immersive.template.template == "destination-carousel")
        #expect(immersive.composition.recipe == "destination")
        #expect(immersive.guidance.intensity == "immersive")

        var comparison = EmbeddedIntent()
        comparison.goal = .compare
        comparison.destinations = ["London"]
        comparison.departureDate = "2026-09-10"
        comparison.returnDate = "2026-09-13"
        let compared = EmbeddedDecisionPipeline.decide(
            intent: comparison,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )
        #expect(compared.template.template == "comparison")
        #expect(compared.template.map == "results")
        #expect(compared.composition.recipe == "comparison")

        comparison.products = [.lodging, .flight]
        comparison.relationship = "package"
        comparison.goal = .find
        comparison.originAirport = "SEA"
        let package = EmbeddedDecisionPipeline.decide(
            intent: comparison,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )
        #expect(package.sourcing.tasks.first { $0.source == "package" }?.readiness == .ready)
        #expect(package.template.template == "itinerary-package")
        #expect(package.composition.recipe == "package")
    }

    @Test @MainActor
    func embeddedFixtureE2ECoversLodgingFlightPackageComparisonAndExploration() async throws {
        let source = EmbeddedGenUIDataSource(agent: fixtureAgent())
        let cases: [(String, TemplateType, String, ResultComposition, Bool, Bool)] = [
            ("hotels in London 2026-09-10 2026-09-13", .lodgingList, "lodging", .blocks, true, true),
            ("flights from SEA to London 2026-09-10", .flightList, "flight", .blocks, true, false),
            ("package from SEA to Cancun 2026-09-10 2026-09-13", .packageOverview, "package", .blocks, true, true),
            ("compare hotels in London 2026-09-10 2026-09-13", .comparisonTable, "comparison", .blocks, false, true),
            ("somewhere warm with ideas", .destinationCarousel, "destination", .blocks, true, false),
        ]

        for (query, template, recipe, composition, hasOptions, showsMap) in cases {
            let result = try await source.agent.run(query: query, continuation: nil, newEvents: [])
            #expect(result.state.template == template)
            #expect(result.trace.composition.recipe == recipe)
            let payload = try #require(try AgentStateMapper.map(state: result.state, query: query).thread)
            #expect(payload.composition == composition)
            #expect(payload.options.isEmpty != hasOptions)
            #expect(!payload.blocks.contains { $0.semanticType == "result-state-summary" })
            if showsMap {
                #expect(payload.presentation.map?.pins.isEmpty == false)
            } else {
                #expect(payload.presentation.showsMap == false)
            }
        }
    }

    @Test @MainActor
    func embeddedContinuationRetainsContextAndCompletesPartialClarification() async throws {
        let source = EmbeddedGenUIDataSource(agent: fixtureAgent())
        let partial = try await source.response(
            for: "hotels in London",
            continuation: nil,
            intentEvents: []
        )
        let first = try #require(partial.thread)
        #expect(first.options.count == 3)
        #expect(!first.blocks.contains { $0.semanticType == "clarification" })

        let events = [
            ContinuationEvent(id: "depart", type: "ui-selection", timestamp: 1, field: "departureDate", newValue: "2026-09-10", strength: "hard", source: "user"),
            ContinuationEvent(id: "return", type: "ui-selection", timestamp: 2, field: "returnDate", newValue: "2026-09-13", strength: "hard", source: "user"),
        ]
        let completed = try await source.response(
            for: "use these dates",
            continuation: first.continuation,
            intentEvents: events
        )
        let second = try #require(completed.thread)
        #expect(second.options.count == 3)
        #expect(second.continuation?.sessionId == first.continuation?.sessionId)
        #expect(second.continuation?.intentEvents.contains { $0.field == "destinations" } == true)
        #expect(second.continuation?.intentEvents.contains { $0.field == "departureDate" } == true)
        #expect(second.presentation.map?.pins.count == 3)
    }

    @Test
    func provisionalInspirationKeepsUnobtrusiveSourceMetadata() throws {
        let destinations = [
            EmbeddedDestination(
                id: "gpt-1", name: "Lisbon", country: "Portugal",
                description: "Coast and culture", highlights: ["Food"],
                dataSource: "gpt-provisional"
            ),
        ]
        var intent = EmbeddedIntent()
        intent.goal = .explore
        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true
        )
        let components = EmbeddedSurfaceBuilder.results(
            intent: intent, trace: trace, lodging: [], flights: [], destinations: destinations
        )
        let card = try #require(components.first { $0.type == "destination-card" })
        #expect(card.props["dataSource"]?.stringValue == "gpt-provisional")
        #expect(!components.contains { $0.type == "result-state-summary" })
    }

    @Test
    func fallbackProviderSurfacesFallbackFailureAndPreservesCancellation() async {
        let provider = FallbackLodgingProvider(
            primary: ThrowingLodgingProvider(error: MCPClientError.transport),
            fallback: ThrowingLodgingProvider(error: MCPClientError.unusableResult("fixture"))
        )
        await #expect(throws: MCPClientError.self) {
            try await provider.search(intent: EmbeddedIntent(), summary: "")
        }
    }

    @Test
    func directGatewayDefaultIsSecureAndNotLoopback() {
        #expect(MCPConfiguration.defaultGatewayURL.scheme == "https")
        #expect(MCPConfiguration.defaultGatewayURL.host != "localhost")
        #expect(MCPConfiguration.environment([:]).url == MCPConfiguration.defaultGatewayURL)
    }

    @Test
    func semanticRouteScoreUsesExistingIntentMeaningAndConfigurableThresholds() {
        var open = EmbeddedIntent()
        open.goal = .explore
        open.products = [.lodging, .flight]
        open.relationship = "package"

        var exact = EmbeddedIntent()
        exact.goal = .find
        exact.destinations = ["Cancun"]
        exact.departureDate = "2026-09-10"
        exact.returnDate = "2026-09-15"
        exact.originAirport = "SEA"

        let scorer = SemanticRouteScorer()
        #expect(scorer.score(intent: open).lean == .itinerary)
        #expect(scorer.score(intent: exact).lean == .results)

        let custom = SemanticRouteScorer(
            thresholds: SemanticRouteThresholds(itineraryMaximum: 0.8, resultsMinimum: 0.9)
        )
        #expect(custom.score(intent: exact).lean == .itinerary)
    }

    @Test
    func dataRequirementsKeepOptionalFieldsNonBlocking() {
        var intent = EmbeddedIntent()
        intent.goal = .explore
        intent.products = [.lodging, .flight]
        intent.relationship = "package"
        let route = SemanticRouteScorer().score(intent: intent)
        let requirements = EmbeddedDataRequirementsResolver.resolve(
            intent: intent,
            route: route
        )

        #expect(requirements.first { $0.field == "departureDate" }?.level == .optional)
        #expect(requirements.first { $0.field == "departureDate" }?.isPresent == false)
        #expect(requirements.first { $0.field == "departureDate" }?.capturePrompt != nil)
        #expect(requirements.first { $0.field == "originAirport" }?.level == .optional)
    }

    @Test
    func defaultNarrativeSelectorProducesFiveOrderedRoles() {
        let items = (0..<7).map { index in
            A2UIComponent(
                id: "item-\(index)",
                type: "destination-card",
                props: [
                    "name": .string("Place \(index)"),
                    "highlights": .array([]),
                ]
            )
        }
        let sections = DefaultNarrativeSelector().select(from: items)

        #expect(sections.map(\.role) == [
            .topMatch, .closeAlternative, .furtherAlternative, .wildCard, .rest,
        ])
        #expect(sections.last?.items.count == 3)
    }

    @Test
    func generatedPageSpecRoundTripsThroughCodable() throws {
        let spec = GeneratedPageSpec(
            route: SearchRouteSpec(score: 0.4, lean: .itinerary),
            requirements: [
                DataRequirementSpec(
                    field: "departureDate",
                    level: .optional,
                    isPresent: false,
                    capturePrompt: "Add dates"
                ),
            ],
            construct: PageConstructSpec(
                kind: .mapOverlaySheet,
                loadMap: true,
                showFilters: true,
                overlaySheet: true
            ),
            sections: [
                GeneratedPageSection(
                    id: "top",
                    role: .topMatch,
                    component: .highlight,
                    copy: PageSectionCopy(heading: "Top", subheading: "Grounded"),
                    items: [A2UIComponent(id: "item", type: "destination-card")]
                ),
            ]
        )

        let decoded = try JSONDecoder().decode(
            GeneratedPageSpec.self,
            from: JSONEncoder().encode(spec)
        )
        #expect(decoded.sections.first?.role == .topMatch)
        #expect(decoded.construct.loadMap)
        #expect(decoded.requirements.first?.capturePrompt == "Add dates")
    }

    @Test @MainActor
    func mexicoPackagesProducesNarrativePageSections() async throws {
        let query = "Mexico packages"
        let result = try await fixtureAgent().run(
            query: query,
            continuation: nil,
            newEvents: []
        )
        let page = try #require(result.state.pageSpec)
        let payload = try #require(
            try AgentStateMapper.map(state: result.state, query: query).thread
        )

        #expect(page.sections.count > 1)
        #expect(page.sections.first?.role == .topMatch)
        #expect(page.sections.first?.component == .highlight)
        #expect(Set(page.sections.map(\.copy.heading)).count == page.sections.count)
        #expect(page.sections.allSatisfy { !$0.copy.subheading.isEmpty })
        #expect(payload.composition == .blocks)
        #expect(payload.blocks.contains { $0.style == .highlight })
        #expect(payload.options.count > 1)
    }

    @Test(.serialized)
    func travelerCoreRequestsUseAnonymousGraphQLContract() async throws {
        var requestCount = 0
        var contractValid = true
        let host = "traveler-core-contract.unit.test"
        TravelerCoreURLProtocol.setHandler(for: host) { request in
            requestCount += 1
            let body = try requestJSONObject(request)
            let query = try #require(body["query"] as? String)
            let variables = try #require(body["variables"] as? [String: Any])
            contractValid = contractValid
                && request.httpMethod == "POST"
                && request.value(forHTTPHeaderField: "Content-Type") == "application/json"
                && request.value(forHTTPHeaderField: "ctx-site") == "1"
                && request.value(forHTTPHeaderField: "ctx-site-locale") == "en-US"
                && request.value(forHTTPHeaderField: "ctx-site-currency") == "USD"
                && request.value(forHTTPHeaderField: "ctx-locale") == nil
                && request.value(forHTTPHeaderField: "ctx-currency") == nil
                && request.value(forHTTPHeaderField: "Authorization") == nil

            if query.contains("RegionSearch") {
                contractValid = contractValid && variables["query"] as? String == "Cancun"
                return try TravelerCoreURLProtocol.response(request, body: [
                    "data": ["regionSearch": [[
                        "id": "179995", "name": "Cancun", "fullName": "Cancun, Quintana Roo",
                        "type": "CITY", "coordinates": ["latitude": 21.16, "longitude": -86.85],
                        "parent": ["name": "Quintana Roo"],
                    ]]],
                ])
            }
            if query.contains("AirportSearch") {
                contractValid = contractValid && variables["query"] as? String == "New York"
                return try TravelerCoreURLProtocol.response(request, body: [
                    "data": ["airportSearch": [[
                        "code": "JFK", "name": "John F. Kennedy International Airport", "city": "New York",
                    ]]],
                ])
            }
            let criteria = try #require(variables["criteria"] as? [String: Any])
            let destination = try #require(criteria["destination"] as? [String: Any])
            contractValid = contractValid && destination["regionId"] as? String == "179995"
            if query.contains("ActivitySearch") {
                contractValid = contractValid
                    && destination["query"] == nil
                    && variables["after"] == nil
                    && !query.contains("$after")
                    && (criteria["dates"] as? [String: Any])?["start"] as? String == "2026-08-10"
                    && (criteria["dates"] as? [String: Any])?["end"] as? String == "2026-08-13"
                    && (criteria["travelers"] as? [String: Any])?["adults"] as? Int == 2
                    && (criteria["travelers"] as? [String: Any])?["childAges"] as? [Int] == [8]
                return try TravelerCoreURLProtocol.response(request, body: [
                    "data": ["activitySearch": ["edges": [[
                        "id": "a1", "name": "Reef tour", "description": "Guided reef trip",
                        "highlights": ["Boat"], "images": [["url": "https://images.test/activity.jpg"]],
                        "leadPrice": ["display": ["amount": 79.0, "currencyCode": "USD", "formatted": "$79"]],
                        "reviews": ["summary": ["score": 4.8, "totalCount": 120]],
                        "region": ["id": "179995", "name": "Cancun"],
                    ]]]],
                ])
            }
            let stay = try #require(criteria["stay"] as? [String: Any])
            let dateRange = try #require(stay["dateRange"] as? [String: Any])
            let room = try #require((stay["rooms"] as? [[String: Any]])?.first)
            contractValid = contractValid
                && dateRange["start"] as? String == "2026-08-10"
                && dateRange["end"] as? String == "2026-08-13"
                && dateRange["checkInDate"] == nil
                && dateRange["checkOutDate"] == nil
                && room["adults"] as? Int == 2
                && room["childAges"] as? [Int] == [8]
                && room["children"] == nil
            return try TravelerCoreURLProtocol.response(request, body: [
                "data": ["propertySearch": ["edges": [[
                    "property": [
                        "id": "p1", "name": "Beach Hotel",
                        "images": [["url": "https://images.test/hotel.jpg"]],
                    ],
                ]]]],
            ])
        }
        let client = TravelerCoreClient(
            configuration: .init(url: URL(string: "https://\(host)/graphql")!, maximumRetries: 0),
            session: TravelerCoreURLProtocol.session()
        )
        var intent = EmbeddedIntent()
        intent.destinations = ["Cancun"]
        intent.departureDate = "2026-08-10"
        intent.returnDate = "2026-08-13"
        intent.adults = 2
        intent.children = [8]

        let region = try #require(try await client.regions(matching: "Cancun", first: 1).first)
        let airport = try #require(try await client.airports(matching: "New York", first: 1).first)
        let activities = try await client.activities(intent: intent, region: region, first: 5)
        let properties = try await client.properties(intent: intent, region: region, first: 5)

        #expect(requestCount == 4)
        #expect(contractValid)
        #expect(airport.code == "JFK")
        #expect(activities.first?.id == "a1")
        #expect(properties.first?.id == "p1")
    }

    @Test
    func travelerCoreURLNormalizersRejectUnsafeValues() {
        #expect(TravelerCoreNormalizers.webURL(" //images.test/photo.jpg ") == "https://images.test/photo.jpg")
        #expect(TravelerCoreNormalizers.webURL("https://images.test/photo.jpg") == "https://images.test/photo.jpg")
        #expect(TravelerCoreNormalizers.webURL("javascript:alert(1)") == nil)
        #expect(TravelerCoreNormalizers.webURL("https://user:secret@images.test/photo.jpg") == nil)
        #expect(TravelerCoreNormalizers.firstImage(in: [.init(url: "file:///private/photo.jpg")]) == nil)
        #expect(TravelerCoreNormalizers.normalizedName("Cancún Palace!") == "cancunpalace")
    }

    @Test(.serialized)
    func travelerCoreGraphQLErrorsThrowAndRetryServerFailures() async throws {
        var calls = 0
        let host = "traveler-core-errors.unit.test"
        TravelerCoreURLProtocol.setHandler(for: host) { request in
            calls += 1
            if calls == 1 {
                return try TravelerCoreURLProtocol.response(request, status: 503, body: ["error": "temporary"])
            }
            return try TravelerCoreURLProtocol.response(request, body: [
                "errors": [["message": "INTERNAL_SERVER_ERROR"]],
                "data": NSNull(),
            ])
        }
        let client = TravelerCoreClient(
            configuration: .init(
                url: URL(string: "https://\(host)/graphql")!,
                maximumRetries: 1,
                retryDelayNanoseconds: 0
            ),
            session: TravelerCoreURLProtocol.session()
        )

        do {
            _ = try await client.regions(matching: "Cancun", first: 1)
            Issue.record("Expected a GraphQL error")
        } catch let error as TravelerCoreError {
            #expect(error == .graphQL(["INTERNAL_SERVER_ERROR"]))
        }
        #expect(calls == 2)

        calls = 0
        TravelerCoreURLProtocol.setHandler(for: host) { _ in
            calls += 1
            throw URLError(.notConnectedToInternet)
        }
        do {
            _ = try await client.regions(matching: "Cancun", first: 1)
            Issue.record("Expected an off-network transport error")
        } catch let error as TravelerCoreError {
            #expect(error == .transport)
        }
        #expect(calls == 1)
    }

    @Test
    func travelerCoreEnrichmentIsFailSoftAndPreservesShoppingFacts() async throws {
        var intent = EmbeddedIntent()
        intent.destinations = ["Cancun"]
        intent.departureDate = "2026-08-10"
        intent.returnDate = "2026-08-13"
        let lodging = StubLodgingProvider(items: [
            .init(
                id: "mcp-1", name: "Beach Hôtel", location: "Cancun", amenities: ["Pool"],
                nightly: 210, total: 630, rating: 9.1, reviews: 400, refundable: true,
                imageURL: "https://mcp.test/original.jpg", dataSource: "authoritative"
            ),
        ])
        let destination = StubDestinationProvider(items: [
            .init(
                id: "d1", name: "Cancun", country: "Mexico", description: "MCP description",
                highlights: ["MCP"], imageURL: "https://mcp.test/hero.jpg", dataSource: "authoritative"
            ),
        ])
        let graph = StubTravelerCore(
            regionsValue: [.init(id: "179995", name: "Cancun")],
            activitiesValue: [.init(
                id: "a1", name: "Reef tour", description: "Graph description",
                highlights: ["Reef", "Boat"], images: [.init(url: "https://graph.test/activity.jpg")]
            )],
            propertiesValue: [.init(
                id: "different-id", name: "Beach Hotel",
                images: [.init(url: "https://graph.test/hotel.jpg")]
            )]
        )

        let stays = try await TravelerCoreLodgingEnrichmentProvider(primary: lodging, client: graph)
            .search(intent: intent, summary: "Cancun")
        let destinations = try await TravelerCoreDestinationEnrichmentProvider(primary: destination, client: graph)
            .search(intent: intent, query: "Cancun")

        #expect(stays.first?.imageURL == "https://graph.test/hotel.jpg")
        #expect(stays.first?.nightly == 210)
        #expect(stays.first?.total == 630)
        #expect(stays.first?.refundable == true)
        #expect(destinations.first?.description == "MCP description")
        #expect(destinations.first?.highlights == ["MCP"])
        #expect(destinations.first?.imageURL == "https://graph.test/activity.jpg")

        let failing = StubTravelerCore(error: .graphQL(["failure"]))
        let fallbackStays = try await TravelerCoreLodgingEnrichmentProvider(primary: lodging, client: failing)
            .search(intent: intent, summary: "Cancun")
        let fallbackDestinations = try await TravelerCoreDestinationEnrichmentProvider(primary: destination, client: failing)
            .search(intent: intent, query: "Cancun")
        #expect(fallbackStays.first?.imageURL == "https://mcp.test/original.jpg")
        #expect(fallbackDestinations.first?.description == "MCP description")
        #expect(fallbackDestinations.first?.imageURL == "https://mcp.test/hero.jpg")
    }

    @Test @MainActor
    func travelerCoreImagesPropagateThroughGenUIOptions() async throws {
        var intent = EmbeddedIntent()
        intent.destinations = ["Cancun"]
        intent.departureDate = "2026-08-10"
        intent.returnDate = "2026-08-13"
        intent.products = [.lodging, .activities]
        let graph = StubTravelerCore(
            regionsValue: [.init(id: "179995", name: "Cancun")],
            activitiesValue: [
                .init(
                    id: "activity-1", name: "Reef tour", description: "Guided trip",
                    highlights: ["Reef"], images: [.init(url: "https://graph.test/activity.jpg")]
                ),
                .init(
                    id: "activity-2", name: "Museum walk", description: "Indoor option",
                    highlights: [], images: [.init(url: "file:///private/museum.jpg")]
                ),
            ],
            propertiesValue: [.init(
                id: "hotel-1", name: "Beach Hotel",
                images: [.init(url: "https://graph.test/hotel.jpg")]
            )]
        )
        let stays = try await TravelerCoreLodgingEnrichmentProvider(
            primary: StubLodgingProvider(items: [.init(
                id: "hotel-1", name: "Beach Hotel", location: "Cancun", amenities: [],
                nightly: 100, total: 300, rating: 9, reviews: 10, refundable: true
            )]),
            client: graph
        ).search(intent: intent, summary: "Cancun")
        let destinations = try await TravelerCoreDestinationEnrichmentProvider(
            primary: StubDestinationProvider(items: [.init(
                id: "destination-1", name: "Cancun", country: "Mexico",
                description: "Base", highlights: []
            )]),
            client: graph
        ).search(intent: intent, query: "Cancun")
        let activities = try await TravelerCoreActivityProvider(client: graph).search(intent: intent)
        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true,
            activityAvailable: true
        )
        let components = EmbeddedSurfaceBuilder.results(
            intent: intent,
            trace: trace,
            lodging: stays,
            flights: [],
            destinations: destinations,
            activities: activities
        )
        let response = try AgentStateMapper.map(
            state: AgentState(
                surfaces: ["search-results": .init(components: components)],
                template: .mixed,
                querySummary: "Cancun options"
            ),
            query: "Cancun options"
        )
        let options = try #require(response.thread).options
        let images = Dictionary(uniqueKeysWithValues: options.map { ($0.title, $0.imageURL) })

        #expect(images["Beach Hotel"] == "https://graph.test/hotel.jpg")
        #expect(images["Cancun"] == "https://graph.test/activity.jpg")
        #expect(images["Reef tour"] == "https://graph.test/activity.jpg")
        #expect(try #require(options.first { $0.title == "Museum walk" }).imageURL == nil)
        #expect(try #require(response.thread).kind == .lodging)
    }

    @Test
    func explicitActivitiesIntentDoesNotAddLodging() async throws {
        let parsed = try await FixtureIntentProvider().parse(
            query: "things to do in Cancun",
            previousEvents: [],
            previousQuerySummary: nil
        )
        let intent = EmbeddedRetrievalPolicy.enriched(
            EmbeddedIntentCompiler.compile(events: parsed.events, query: "things to do in Cancun"),
            query: "things to do in Cancun"
        )
        let trace = EmbeddedDecisionPipeline.decide(
            intent: intent,
            lodgingAvailable: true,
            flightAvailable: true,
            destinationAvailable: true,
            activityAvailable: true
        )

        #expect(intent.products == [.activities])
        #expect(trace.sourcing.tasks.contains { $0.source == "activity" && $0.readiness == .ready })
        #expect(!trace.sourcing.tasks.contains { $0.source == "lodging" })
        #expect(trace.composition.recipe == "activity")
    }

    @Test(.serialized)
    func gptComposerRouterUsesStructuredRouteAndAnswer() async throws {
        var schemaName: String?
        GPTURLProtocol.handler = { request in
            let body = try requestJSONObject(request)
            schemaName = ((body["response_format"] as? [String: Any])?["json_schema"] as? [String: Any])?["name"] as? String
            return try GPTURLProtocol.response(
                for: request,
                content: #"{"route":"question","title":"Weather in Jamaica","answer":"March is **warm and dry**."}"#
            )
        }
        let router = GPTComposerRouter(
            configuration: .init(
                apiKey: "test-key",
                model: "test-model",
                baseURL: URL(string: "https://unit.test/v1")!
            ),
            session: GPTURLProtocol.session()
        )

        let result = try await router.route(
            query: "What is Jamaica like in March?",
            context: ComposerContext(surface: .home)
        )

        #expect(result.route == .question)
        #expect(result.title == "Weather in Jamaica")
        #expect(result.answer.contains("**warm and dry**"))
        #expect(schemaName == "composer_route")
    }

    @Test
    func deterministicComposerRouterSeparatesCoreActions() async throws {
        let router = DeterministicComposerRouter()
        let results = ComposerContext(surface: .results)

        #expect(try await router.route(query: "What is the weather like?", context: results).route == .question)
        // Quick reply requires an actual question mark; interrogative phrasing
        // without one is not treated as a chat question.
        #expect(try await router.route(query: "What is the weather like", context: results).route != .question)
        #expect(try await router.route(query: "Tell me about Tokyo", context: results).route == .newSearch)
        #expect(try await router.route(query: "Make it cheaper", context: results).route == .refine)
        #expect(try await router.route(query: "Compare the first two", context: results).route == .compare)
        #expect(try await router.route(query: "How far is it from downtown?", context: results).route == .map)
        #expect(try await router.route(query: "Hotels in Tokyo instead", context: results).route == .newSearch)
        #expect(
            try await router.route(
                query: "That sounds nice",
                context: ComposerContext(surface: .inlineAnswer)
            ).route == .continueConversation
        )
    }

    @Test @MainActor
    func homeQuestionCreatesPersistentConversationObject() async throws {
        let router = SequenceComposerRouter([
            .init(route: .question, title: "Weather in Jamaica", answer: "March is warm and dry.")
        ])
        let store = AppStore(composerRouter: router)
        store.showHome = true
        store.composerText = "What is Jamaica like in March?"

        await store.submitComposer()

        let thread = try #require(store.threads.first)
        #expect(thread.conversationOnly)
        #expect(thread.activities.count == 1)
        #expect(thread.activities.first?.type == .conversation)
        #expect(store.openConversation?.title == "Weather in Jamaica")
        #expect(store.openConversation?.messages.count == 2)
        #expect(store.tripSections.first?.entries.first?.type == .conversation)
    }

    @Test @MainActor
    func contextualAnswerPromotesOnReplyAndKeepsOneChatObject() async throws {
        let router = SequenceComposerRouter([
            .init(route: .question, title: "Weather in Jamaica", answer: "March is warm, dry, and windy."),
            .init(route: .continueConversation, title: "Weather in Jamaica", answer: "The north coast is often breezier."),
            .init(route: .continueConversation, title: "Weather in Jamaica", answer: "Try a sheltered south-coast beach."),
        ])
        let store = AppStore(composerRouter: router)
        let original = try #require(
            Mock.generateResponse(node: nil, text: "hotels in Jamaica").prebuiltThread
        )
        store.threads = [original]
        store.open(original.id)
        store.composerText = "What is the weather like in March?"

        await store.submitComposer()

        #expect(store.inlineAnswerDraft?.conversation.messages.count == 2)
        #expect(store.threads.first?.activities.isEmpty == true)

        store.composerText = "I don't like wind"
        await store.submitComposer()

        #expect(store.inlineAnswerDraft == nil)
        #expect(store.threads.first?.activities.count == 1)
        #expect(store.openConversation?.messages.count == 4)
        let activityID = try #require(store.openActivityID)

        store.composerText = "Where should I stay then?"
        await store.submitComposer()

        #expect(store.threads.first?.activities.count == 1)
        #expect(store.openActivityID == activityID)
        #expect(store.openConversation?.messages.count == 6)
        #expect(store.tripSections.first?.entries.contains { $0.id == activityID && $0.type == .conversation } == true)
    }

    @Test @MainActor
    func contextualRefineMutatesOpenThread() async throws {
        let router = SequenceComposerRouter([
            .init(route: .refine, title: "", answer: "")
        ])
        let store = AppStore(composerRouter: router)
        store.assistantSourceMode = .narrativeMock
        let original = try #require(
            Mock.generateResponse(node: nil, text: "hotels in London").prebuiltThread
        )
        store.threads = [original]
        store.open(original.id)
        let originalID = original.id
        let originalTitle = original.title

        store.composerText = "Make it cheaper"
        await store.submitComposer()

        #expect(store.threads.count == 1)
        #expect(store.threads.first?.id == originalID)
        #expect(store.openThreadID == originalID)
        #expect(
            store.threads.first?.title != originalTitle
                || store.threads.first?.presentation.filters.contains("budget") == true
        )
        #expect(store.threads.first?.activities.isEmpty == true)
    }

    @Test @MainActor
    func contextualCompareAndMapCreateActivitiesOnOpenThread() async throws {
        let router = SequenceComposerRouter([
            .init(route: .compare, title: "", answer: ""),
            .init(route: .map, title: "", answer: ""),
        ])
        let store = AppStore(composerRouter: router)
        store.assistantSourceMode = .narrativeMock
        let original = try #require(
            Mock.generateResponse(node: nil, text: "hotels in London").prebuiltThread
        )
        store.threads = [original]
        store.open(original.id)

        store.composerText = "Compare the first two"
        await store.submitComposer()

        #expect(store.threads.count == 1)
        #expect(store.threads.first?.activities.count == 1)
        #expect(store.threads.first?.activities.first?.type == .compare)
        #expect(store.openActivityID == store.threads.first?.activities.first?.id)

        store.composerText = "How far is it from downtown?"
        await store.submitComposer()

        #expect(store.threads.count == 1)
        #expect(store.threads.first?.activities.count == 2)
        #expect(store.threads.first?.activities.last?.type == .map)
    }

    @Test @MainActor
    func explicitNewSearchKeepsCardSwapLaunch() async throws {
        let router = SequenceComposerRouter([
            .init(route: .newSearch, title: "", answer: "")
        ])
        let store = AppStore(composerRouter: router)
        store.assistantSourceMode = .narrativeMock
        let original = try #require(
            Mock.generateResponse(node: nil, text: "hotels in London").prebuiltThread
        )
        store.threads = [original]
        store.open(original.id)
        store.revealingThreadID = original.id

        store.composerText = "Hotels in Tokyo instead"
        await store.submitComposer()

        #expect(store.launching)
        #expect(store.launchFromCurrent)
        #expect(store.threads.count == 2)
        #expect(store.threads.first?.id == original.id)
        #expect(store.threads.last?.kind == .lodging)
        #expect(store.swapOutThreadID == original.id)
    }

    @Test @MainActor
    func offlineComposerRoutingFallsBackSafely() async throws {
        let refineRouter = FallbackComposerRouter(
            primary: FailingComposerRouter(),
            fallback: DeterministicComposerRouter()
        )
        let refineStore = AppStore(composerRouter: refineRouter)
        refineStore.assistantSourceMode = .narrativeMock
        let original = try #require(
            Mock.generateResponse(node: nil, text: "hotels in London").prebuiltThread
        )
        refineStore.threads = [original]
        refineStore.open(original.id)
        refineStore.composerText = "Make it cheaper"
        await refineStore.submitComposer()

        #expect(refineStore.threads.count == 1)
        #expect(refineStore.threads.first?.id == original.id)
        #expect(refineStore.dataSourceErrorMessage == nil)

        let questionRouter = FallbackComposerRouter(
            primary: FailingComposerRouter(),
            fallback: DeterministicComposerRouter()
        )
        let questionStore = AppStore(composerRouter: questionRouter)
        questionStore.showHome = true
        questionStore.composerText = "What is Jamaica like in March?"
        await questionStore.submitComposer()

        #expect(questionStore.threads.isEmpty)
        #expect(questionStore.openConversation == nil)
        #expect(questionStore.dataSourceErrorMessage == "The question could not be answered right now.")
    }

}

private actor SequenceComposerRouter: ComposerRouting {
    nonisolated let configured = true
    private var results: [ComposerRoutingResult]

    init(_ results: [ComposerRoutingResult]) {
        self.results = results
    }

    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult {
        guard !results.isEmpty else { throw EmbeddedGPTProviderError.invalidResponse }
        return results.removeFirst()
    }
}

private struct FailingComposerRouter: ComposerRouting {
    let configured = true

    func route(query: String, context: ComposerContext) async throws -> ComposerRoutingResult {
        throw EmbeddedGPTProviderError.invalidResponse
    }
}

private func fixtureAgent() -> EmbeddedSearchAgent {
    let fixture = FixtureTravelProvider()
    return EmbeddedSearchAgent(
        intentProvider: FixtureIntentProvider(),
        inspirationProvider: FixtureInspirationProvider(),
        lodgingProvider: fixture,
        flightProvider: fixture,
        destinationProvider: fixture,
        activityProvider: fixture
    )
}

private struct StubTravelerCore: TravelerCoreProviding {
    var regionsValue: [TravelerCoreRegion] = []
    var airportsValue: [TravelerCoreAirport] = []
    var activitiesValue: [TravelerCoreActivity] = []
    var propertiesValue: [TravelerCoreProperty] = []
    var error: TravelerCoreError?

    func regions(matching query: String, first: Int) async throws -> [TravelerCoreRegion] {
        if let error { throw error }
        return regionsValue
    }

    func airports(matching query: String, first: Int) async throws -> [TravelerCoreAirport] {
        if let error { throw error }
        return airportsValue
    }

    func activities(
        intent: EmbeddedIntent,
        region: TravelerCoreRegion,
        first: Int
    ) async throws -> [TravelerCoreActivity] {
        if let error { throw error }
        return activitiesValue
    }

    func properties(
        intent: EmbeddedIntent,
        region: TravelerCoreRegion,
        first: Int
    ) async throws -> [TravelerCoreProperty] {
        if let error { throw error }
        return propertiesValue
    }
}

private struct StubLodgingProvider: EmbeddedLodgingProviding {
    let items: [EmbeddedLodging]
    let available = true
    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] { items }
}

private struct StubDestinationProvider: EmbeddedDestinationProviding {
    let items: [EmbeddedDestination]
    let available = true
    func search(intent: EmbeddedIntent, query: String) async throws -> [EmbeddedDestination] { items }
}

private struct ThrowingLodgingProvider: EmbeddedLodgingProviding {
    let available = true
    let error: MCPClientError
    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        throw error
    }
}

private struct MalformedLodgingProvider: EmbeddedLodgingProviding {
    let available = true
    func search(intent: EmbeddedIntent, summary: String) async throws -> [EmbeddedLodging] {
        throw MCPClientError.unusableResult("lodging")
    }
}

private enum URLProtocolTestError: Error {
    case missingBody
    case unreadableBody
    case invalidJSON
}

private func requestBody(_ request: URLRequest) throws -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { throw URLProtocolTestError.missingBody }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while true {
        let count = stream.read(&buffer, maxLength: buffer.count)
        guard count >= 0 else { throw URLProtocolTestError.unreadableBody }
        if count == 0 { break }
        data.append(buffer, count: count)
    }
    guard !data.isEmpty else { throw URLProtocolTestError.missingBody }
    return data
}

private func requestJSONObject(_ request: URLRequest) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any] else {
        throw URLProtocolTestError.invalidJSON
    }
    return object
}

private final class TravelerCoreURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let handlerLock = NSLock()
    private static var handlers: [String: Handler] = [:]

    static func setHandler(for host: String, _ handler: @escaping Handler) {
        handlerLock.lock()
        handlers[host] = handler
        handlerLock.unlock()
    }

    private static func handler(for host: String?) -> Handler? {
        handlerLock.lock()
        defer { handlerLock.unlock() }
        return host.flatMap { handlers[$0] }
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TravelerCoreURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func response(
        _ request: URLRequest,
        status: Int = 200,
        body: Any
    ) throws -> (HTTPURLResponse, Data) {
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, try JSONSerialization.data(withJSONObject: body))
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler(for: request.url?.host) else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

private final class MCPURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) = { _ in
        throw URLError(.badServerResponse)
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MCPURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func response(
        _ request: URLRequest,
        status: Int = 200,
        body: Any?
    ) throws -> (HTTPURLResponse, Data) {
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "mcp-session-id": "session-test",
            ]
        ))
        let data = try body.map { try JSONSerialization.data(withJSONObject: $0) } ?? Data()
        return (response, data)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

private final class GPTURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data) = { _ in
        throw URLError(.badServerResponse)
    }

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GPTURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    static func response(for request: URLRequest, content: String) throws -> (HTTPURLResponse, Data) {
        let envelope = ["choices": [["message": ["content": content]]]]
        let data = try JSONSerialization.data(withJSONObject: envelope)
        let url = try #require(request.url)
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, data)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
private final class StubGenUIDataSource: GenUIDataSourceProviding {
    private let stubbedResponse: AssistantResponse
    private(set) var calls = 0
    private(set) var lastContinuation: SearchContinuation?
    private(set) var lastIntentEvents: [ContinuationEvent] = []

    init(response: AssistantResponse) {
        stubbedResponse = response
    }

    func response(
        for query: String,
        continuation: SearchContinuation?,
        intentEvents: [ContinuationEvent]
    ) async throws -> AssistantResponse {
        calls += 1
        lastContinuation = continuation
        lastIntentEvents = intentEvents
        return stubbedResponse
    }
}
