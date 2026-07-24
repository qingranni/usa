import Foundation

/// Optional Figma scenario policy over `MexicoFixtureCatalog`.
///
/// This is deliberately not a catch-all data source. A handled query receives
/// an authored snapshot or deterministic branch; everything else returns nil so
/// the normal Mock → Gen-UI → GPT source route can continue.
enum NarrativeData {
    static let scenarioID = "rosa-mexico-spring-break"

    struct Resolution {
        var response: AssistantResponse
    }

    /// Whether `resolve` would produce an authored golden-path result for this
    /// query. Lets the composer give authored paths priority over the LLM route
    /// classifier in narrative+mock mode.
    static func handles(current: ThreadNode?, text: String) -> Bool {
        resolve(current: current, text: text) != nil
    }

    static func resolve(current: ThreadNode?, text: String) -> Resolution? {
        let query = normalized(text)
        guard !query.isEmpty, !query.contains("mexico city") else { return nil }

        if current?.scenarioID == scenarioID {
            if Mock.detectAction(query) != nil {
                return Resolution(
                    response: AssistantResponse(reply: Copy["narrative.replies.useCurrentOptions"])
                )
            }
            if isPackageRefinement(query) {
                return Resolution(
                    response: AssistantResponse(
                        reply: Copy["narrative.replies.packageRefinement"],
                        thread: refinedPackages()
                    )
                )
            }
            if containsActivityIntent(query) {
                return branch(activitiesPayload())
            }
            if containsFlightIntent(query) {
                return branch(flightsPayload())
            }
            if current?.scenarioStep == "orientation"
                && (query.contains("cancun") || query.contains("tell me more")) {
                return branch(packagesPayload())
            }
            if query.contains("hyatt") || query.contains("family room")
                || query.contains("families with teens") {
                return branch(hyattDetailPayload())
            }
            if query.contains("package") || query.contains("hotel") || query.contains("stay")
                || query.contains("cancun") {
                return branch(packagesPayload())
            }
            return nil
        }

        guard containsCoveredGeography(query) else { return nil }

        if containsActivityIntent(query) {
            return branch(activitiesPayload())
        }
        if containsFlightIntent(query) {
            return branch(flightsPayload())
        }
        if isPackageRefinement(query) {
            return branch(refinedPackages())
        }
        if query.contains("hyatt") || query.contains("family room") {
            return branch(hyattDetailPayload())
        }
        if query.contains("package") || query.contains("hotel") || query.contains("stay")
            || query.contains("cancun") {
            return branch(packagesPayload())
        }
        if isGoldenSignature(query) || query.contains("mexico") {
            return branch(orientationPayload())
        }
        return nil
    }

    // MARK: - Scenario snapshots

    private static func orientationPayload() -> ThreadPayload {
        let options = MexicoFixtureCatalog.destinations.map { destination in
            let presentation = orientationPresentation(for: destination.id)
            return Option(
                title: destination.name,
                detail: presentation.detail,
                price: currency(destination.packageFrom),
                imageURL: presentation.imageName,
                priceValue: destination.packageFrom,
                highlights: "Flights + stay"
            )
        }
        let moreMexicoOptions = [
            Option(
                title: Copy["narrative.orientation.moreOptions.sanPancho.title"],
                detail: Copy["narrative.orientation.moreOptions.sanPancho.detail"],
                price: "$4,720",
                imageURL: "mexico-carousel-san-pancho",
                priceValue: 4_720,
                nights: 5,
                travelers: 3
            ),
            Option(
                title: Copy["narrative.orientation.moreOptions.islaHolbox.title"],
                detail: Copy["narrative.orientation.moreOptions.islaHolbox.detail"],
                price: "$4,720",
                imageURL: "mexico-carousel-isla-holbox",
                priceValue: 4_720,
                nights: 6,
                travelers: 3
            ),
        ]
        let alternateBeachOptions = [
            Option(
                title: Copy["narrative.orientation.alternateOptions.montegoBay.title"],
                detail: Copy["narrative.orientation.alternateOptions.montegoBay.detail"],
                price: "$4,720",
                imageURL: "mexico-carousel-montego-bay",
                priceValue: 4_720,
                nights: 5,
                travelers: 3
            ),
            Option(
                title: Copy["narrative.orientation.alternateOptions.destin.title"],
                detail: Copy["narrative.orientation.alternateOptions.destin.detail"],
                price: "$4,720",
                imageURL: "mexico-carousel-isla-holbox",
                priceValue: 4_720,
                nights: 6,
                travelers: 3
            ),
        ]
        return ThreadPayload(
            kind: .other,
            title: Copy["narrative.orientation.title"],
            summary: Copy["narrative.orientation.summary"],
            label: Copy["narrative.orientation.heading"],
            chip: "",
            options: options,
            source: .narrative,
            composition: .blocks,
            scenarioID: scenarioID,
            scenarioStep: "orientation",
            presentation: ResultsPresentation(
                showsMap: true,
                canvasLayout: .mexicoOrientation,
                filters: Copy.list("narrative.orientation.filters")
            ),
            blocks: [
                BlockSpec(
                    style: .heading,
                    text: Copy["narrative.orientation.heading"]
                ),
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.orientation.summary"]
                ),
                BlockSpec(
                    style: .cards,
                    items: options,
                    cardPresentation: .destinationHero,
                    kind: .other
                ),
                BlockSpec(
                    style: .heading,
                    text: Copy["narrative.orientation.moreHeading"]
                ),
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.orientation.moreText"]
                ),
                BlockSpec(
                    style: .carousel,
                    items: moreMexicoOptions,
                    cardPresentation: .destinationCarousel,
                    kind: .other
                ),
                BlockSpec(
                    style: .heading,
                    text: Copy["narrative.orientation.alternateHeading"]
                ),
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.orientation.alternateText"]
                ),
                BlockSpec(
                    style: .carousel,
                    items: alternateBeachOptions,
                    cardPresentation: .destinationCarousel,
                    kind: .other
                ),
            ]
        )
    }

    private static func orientationPresentation(
        for destinationID: String
    ) -> (detail: String, imageName: String) {
        switch destinationID {
        case "destination-cancun":
            return (
                Copy["narrative.orientation.destinationBlurbs.cancun"],
                "mexico-orientation-cancun"
            )
        case "destination-puerto-vallarta":
            return (
                Copy["narrative.orientation.destinationBlurbs.puertoVallarta"],
                "mexico-orientation-puerto-vallarta"
            )
        case "destination-playa-del-carmen":
            return (
                Copy["narrative.orientation.destinationBlurbs.playaDelCarmen"],
                "mexico-orientation-playa-del-carmen"
            )
        default:
            return (
                MexicoFixtureCatalog.destination(id: destinationID)?.narrativeSummary ?? "",
                MexicoFixtureCatalog.destination(id: destinationID)?.imageURL ?? ""
            )
        }
    }

    private static func packagesPayload() -> ThreadPayload {
        packagePayload(
            title: Copy["narrative.packages.title"],
            heading: Copy["narrative.packages.heading"],
            summary: Copy["narrative.packages.summary"],
            filters: Copy.list("narrative.packages.filters"),
            packages: Array(MexicoFixtureCatalog.packages.prefix(3)),
            step: "packages",
            includesSupportingSections: true
        )
    }

    private static func refinedPackages() -> ThreadPayload {
        let preferredIDs = [
            "package-hyatt-ziva",
            "package-dreams-sands",
            "package-ocean-dream",
        ]
        let preferred = preferredIDs.compactMap { id in
            MexicoFixtureCatalog.packages.first { $0.id == id }
        }
        // Match the authored Figma frame (node 2153-23828) exactly for the hero
        // Hyatt Ziva card: shortened name, beach-refined description, and the
        // frame's struck-through price. Scoped to this step so the earlier
        // packages page keeps its own copy.
        var options = preferred.map(packageOption)
        if !options.isEmpty {
            options[0].title = Copy["narrative.refinedPackages.heroTitle"]
            options[0].highlights = Copy["narrative.refinedPackages.heroDescription"]
            options[0].crossedOutPrice = Copy["narrative.refinedPackages.heroCrossedPrice"]
        }
        return packagePayload(
            title: Copy["narrative.refinedPackages.title"],
            heading: Copy["narrative.refinedPackages.heading"],
            summary: Copy["narrative.refinedPackages.summary"],
            filters: Copy.list("narrative.refinedPackages.filters"),
            packages: preferred,
            step: "refined-packages",
            optionOverrides: options
        )
    }

    private static func packagePayload(
        title: String,
        heading: String,
        summary: String,
        filters: [String],
        packages: [MexicoFixtureCatalog.Package],
        step: String,
        includesSupportingSections: Bool = false,
        optionOverrides: [Option]? = nil
    ) -> ThreadPayload {
        let options = optionOverrides ?? packages.map(packageOption)
        var blocks = [
            BlockSpec(style: .heading, text: heading),
            BlockSpec(style: .text, text: summary),
            BlockSpec(style: .cards, items: options, kind: .other),
        ]
        if includesSupportingSections {
            let resortIDs = ["hotel-hard-rock", "hotel-waldorf-riviera-maya"]
            let resorts = resortIDs.compactMap { id in
                MexicoFixtureCatalog.hotel(id: id).map(resortOption)
            }
            let flights = MexicoFixtureCatalog.flights.map(flightOption)
            blocks.append(contentsOf: [
                BlockSpec(style: .heading, text: Copy["narrative.packages.resortsHeading"]),
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.packages.resortsText"]
                ),
                BlockSpec(
                    style: .carousel,
                    items: resorts,
                    cardPresentation: .lodging,
                    kind: .lodging
                ),
                BlockSpec(style: .heading, text: Copy["narrative.packages.flightsHeading"]),
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.packages.flightsText"]
                ),
                BlockSpec(
                    style: .carousel,
                    items: flights,
                    cardPresentation: .flight,
                    kind: .flights
                ),
            ])
        }
        return ThreadPayload(
            kind: .other,
            title: title,
            summary: summary,
            label: heading,
            chip: "",
            options: options,
            source: .narrative,
            composition: .packageShelves,
            scenarioID: scenarioID,
            scenarioStep: step,
            presentation: ResultsPresentation(showsMap: true, filters: filters),
            blocks: blocks
        )
    }

    private static func hyattDetailPayload() -> ThreadPayload {
        guard let hotel = MexicoFixtureCatalog.hotel(id: "hotel-hyatt-ziva") else {
            return packagesPayload()
        }
        let hotelOption = Option(
            title: hotel.name,
            detail: hotel.area,
            price: "$\(hotel.nightlyPrice)",
            imageURL: hotel.imageURL,
            priceValue: hotel.nightlyPrice,
            highlights: hotel.highlights.joined(separator: " · "),
            rating: hotel.rating,
            reviewCount: hotel.reviewCount,
            city: "Cancún",
            totalPrice: "$930"
        )
        let activityOptions = MexicoFixtureCatalog.activities.map(activityOption)
        let insights = MexicoFixtureCatalog.reviewInsights
            .map { "**\($0.title)**\n\($0.detail)" }
            .joined(separator: "\n\n")
        return ThreadPayload(
            kind: .lodging,
            title: Copy["narrative.hyattDetail.title"],
            summary: Copy["narrative.hyattDetail.summary"],
            label: Copy["narrative.hyattDetail.title"],
            chip: "",
            options: [hotelOption],
            source: .narrative,
            composition: .blocks,
            scenarioID: scenarioID,
            scenarioStep: "hyatt-detail",
            presentation: ResultsPresentation(
                showsMap: true,
                filters: Copy.list("narrative.hyattDetail.filters")
            ),
            blocks: [
                BlockSpec(
                    style: .text,
                    text: Copy["narrative.hyattDetail.summary"]
                ),
                BlockSpec(style: .cards, items: [hotelOption], kind: .lodging),
                BlockSpec(style: .heading, text: Copy["narrative.hyattDetail.reviewsHeading"]),
                BlockSpec(
                    style: .text,
                    text: "\(Copy["narrative.hyattDetail.reviewsLead"])\n\n\(insights)"
                ),
                BlockSpec(style: .heading, text: Copy["narrative.hyattDetail.activitiesHeading"]),
                BlockSpec(style: .carousel, items: activityOptions, kind: .activities),
            ]
        )
    }

    private static func flightsPayload() -> ThreadPayload {
        let options = MexicoFixtureCatalog.flights.map(flightOption)
        return ThreadPayload(
            kind: .flights,
            title: "Houston to Cancun flights",
            summary: "Sorted for good prices and convenient times — like your past family visits.",
            label: "Flights for your package",
            chip: "",
            options: options,
            source: .narrative,
            composition: .flightList,
            scenarioID: scenarioID,
            scenarioStep: "flights",
            presentation: ResultsPresentation(
                showsMap: true,
                filters: ["3 travelers", "Nonstop", "HOU → CUN", "Economy"]
            ),
            blocks: [
                BlockSpec(style: .text, text: "Sorted for good prices and convenient times — like your past family visits."),
                BlockSpec(style: .cards, items: options, kind: .flights),
            ]
        )
    }

    private static func activitiesPayload() -> ThreadPayload {
        let options = MexicoFixtureCatalog.activities.map(activityOption)
        return ThreadPayload(
            kind: .activities,
            title: "Activities near Hyatt Ziva Cancun",
            summary: "Fun nearby activities for Rosa and the teens.",
            label: "Activities nearby",
            chip: "",
            options: options,
            source: .narrative,
            composition: .blocks,
            scenarioID: scenarioID,
            scenarioStep: "activities",
            presentation: ResultsPresentation(
                showsMap: true,
                filters: ["Cancun", "Teen friendly", "Near the beach"]
            ),
            blocks: [
                BlockSpec(style: .text, text: "Fun nearby activities for Rosa and the teens."),
                BlockSpec(style: .cards, items: options, kind: .activities),
            ]
        )
    }

    // MARK: - Adapters

    private static func packageOption(_ package: MexicoFixtureCatalog.Package) -> Option {
        let hotel = MexicoFixtureCatalog.hotel(id: package.hotelID)
        let flight = MexicoFixtureCatalog.flight(id: package.flightID)
        let detail = [
            hotel?.name,
            flight.map { "\($0.stops) flights" },
            package.summary,
        ].compactMap { $0 }.joined(separator: " · ")
        return Option(
            title: hotel?.name ?? package.title,
            detail: detail,
            price: currency(package.totalPrice),
            imageURL: package.imageURL,
            priceValue: package.totalPrice,
            departTime: flight?.departTime,
            arriveTime: flight?.arriveTime,
            stops: flight?.stops,
            duration: flight?.duration,
            cabin: "Economy",
            tripType: "Flights + stay",
            airlines: flight.map { [$0.airline] } ?? [],
            logoURLs: flight == nil ? [] : ["airline-ua"],
            highlights: package.summary,
            rating: hotel?.rating,
            reviewCount: hotel?.reviewCount,
            city: "Cancún",
            totalPrice: currency(package.totalPrice),
            dateRange: package.dateRange,
            crossedOutPrice: package.crossedOutPrice.map(currency),
            discountText: package.discount.map { "\(currency($0)) off" },
            nights: package.id == "package-dreams-sands" ? 6 : 5,
            travelers: 3
        )
    }

    private static func resortOption(_ hotel: MexicoFixtureCatalog.Hotel) -> Option {
        Option(
            title: hotel.name,
            detail: hotel.highlights.joined(separator: " · "),
            price: currency(hotel.nightlyPrice * 5),
            imageURL: hotel.imageURL,
            priceValue: hotel.nightlyPrice,
            highlights: "Beachfront all-inclusive with family-friendly amenities.",
            rating: hotel.rating,
            reviewCount: hotel.reviewCount,
            city: "Cancún",
            totalPrice: currency(hotel.nightlyPrice * 5),
            dateRange: hotel.id == "hotel-waldorf-riviera-maya" ? "Mar 14–21" : "Mar 14–20",
            nights: hotel.id == "hotel-waldorf-riviera-maya" ? 6 : 5,
            travelers: 3
        )
    }

    private static func flightOption(_ flight: MexicoFixtureCatalog.Flight) -> Option {
        Option(
            title: "\(flight.origin) → \(flight.destination)",
            detail: "\(flight.airline) · \(flight.seatsTogether ? "Seats together" : "") · \(flight.bagsIncluded) bags included",
            price: "$\(flight.price)",
            priceValue: flight.price,
            departTime: flight.departTime,
            arriveTime: flight.arriveTime,
            stops: flight.stops,
            duration: flight.duration,
            cabin: "Economy",
            tripType: "Round trip",
            airlines: [flight.airline],
            logoURLs: [flight.airline == "Spirit" ? "airline-nk" : "airline-ua"],
            highlights: "Seats together · \(flight.bagsIncluded) bags included"
        )
    }

    private static func activityOption(_ activity: MexicoFixtureCatalog.Activity) -> Option {
        Option(
            title: activity.name,
            detail: "Starting at $\(activity.priceFrom) · \(activity.duration)",
            price: "$\(activity.priceFrom)",
            imageURL: activity.imageURL,
            priceValue: activity.priceFrom
        )
    }

    private static func branch(_ payload: ThreadPayload) -> Resolution {
        Resolution(
            response: AssistantResponse(reply: payload.summary, thread: payload)
        )
    }

    // MARK: - Matching

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsCoveredGeography(_ text: String) -> Bool {
        ["mexico", "cancun", "puerto vallarta", "playa del carmen"]
            .contains { text.contains($0) }
    }

    private static func containsActivityIntent(_ text: String) -> Bool {
        ["activity", "activities", "things to do", "snorkel", "water park", "excursion"]
            .contains { text.contains($0) }
    }

    private static func containsFlightIntent(_ text: String) -> Bool {
        ["flight", "fly", "airfare", "hou to cun", "houston to cancun"]
            .contains { text.contains($0) }
    }

    private static func isPackageRefinement(_ text: String) -> Bool {
        let terms = [
            "beachfront", "right on the beach", "on the beach", "closer to the beach",
            "2-bed", "2 bed", "two bed",
            "suite", "seats together", "teen space", "own areas", "connected room",
        ]
        return terms.contains { text.contains($0) }
    }

    private static func isGoldenSignature(_ text: String) -> Bool {
        let signals = [
            text.contains("spring break"),
            text.contains("beach"),
            text.contains("teen") || text.contains("kids"),
            text.contains("5000") || text.contains("5,000") || text.contains("under 5"),
            text.contains("1 adult") || text.contains("3 traveler"),
            text.contains("houston") || text.contains("hou"),
        ]
        return signals.filter { $0 }.count >= 3
    }

    private static func currency(_ value: Int) -> String {
        "$" + value.formatted(.number.grouping(.automatic))
    }
}
