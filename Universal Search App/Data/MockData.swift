//
//  MockData.swift
//  Universal Search App
//
//  Deterministic mock travel-assistant + thread builders, ported from data.js.
//  Used directly, and as the fallback whenever the live AI call fails / no key.
//

import Foundation

enum Mock {

    // MARK: - regex helper

    private static func rx(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - intent / action detection

    /// Keyword → result kind. Decides which mock thread to spin up.
    static func detectIntent(_ text: String) -> Kind? {
        if rx(text, #"\b(car|cars|rental|vehicle|drive|driving)\b"#) { return .cars }
        if rx(text, #"\b(hotel|hotels|lodging|stay|accommodation|airbnb|room|resort)\b"#) { return .lodging }
        if rx(text, #"\b(flight|flights|fly|airfare|plane|airline)\b"#) { return .flights }
        if rx(text, #"\b(activit\w+|things? to do|tour|tours|excursion|sightsee\w*|attraction|snorkel\w*|event|events)\b"#) { return .activities }
        return nil
    }

    /// Classify a same-thread follow-up: refine / compare / map.
    static func detectAction(_ text: String) -> ActivityType? {
        if rx(text, #"\b(compare|comparison|versus|vs|which (is|one|has|are)|best|better|differ\w*|rank)\b"#) {
            return .compare
        }
        if rx(text, #"\b(where|location|located|map|nearby|near|distance|how far|far from|closest|close to|neighbou?rhood|area|directions|walk\w*)\b"#) {
            return .map
        }
        return nil   // nil == "refine"
    }

    // MARK: - title parsing

    /// Pull a location out of a thread title for the query chips.
    static func locationFromTitle(_ title: String?) -> String? {
        guard let title, !title.isEmpty else { return nil }
        var s = title.replacingOccurrences(
            of: #"\b(hotels?|stays?|stay|lodging|accommodations?|rooms?|resorts?|budget|cheap(?:er)?|affordable|luxury|boutique|in|near|the|a|an|for|my|our)\b"#,
            with: " ", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: #"[^\w\s-]"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        return s.isEmpty ? nil : s
    }

    // MARK: - result-set / thread builders

    /// Nights assumed for the stay total shown on lodging cards.
    private static let stayNights = 3

    /// One result card from an option, with an image picked from the library.
    /// An explicit `image` (bundled asset or remote URL) wins over the library.
    static func buildCard(threadId: String, setId: String, index: Int, kind: Kind,
                          title: String, detail: String, price: String? = nil,
                          image explicitImage: String? = nil, option: Option? = nil,
                          cityHint: String? = nil) -> Card {
        let text = "\(title) \(detail)".trimmingCharacters(in: .whitespaces)
        let image = explicitImage ?? ImageLibrary.pickImage(text, kind: kind)
        let resolvedPrice = price ?? (detail.hasPrefix("$") ? detail : nil)
        let d = (resolvedPrice != nil && detail == resolvedPrice) ? "" : detail
        let cardId = "\(threadId)-\(setId)-r\(index)"
        var card = Card(id: cardId, title: title, price: resolvedPrice,
                        sublabel: d.isEmpty ? title : "\(title) · \(d)",
                        icon: image == nil ? kind.icon : nil, imageURL: image,
                        layoutId: cardId)
        if let o = option {
            card.logoURLs = o.logoURLs
            card.departTime = o.departTime
            card.arriveTime = o.arriveTime
            card.stops = o.stops
            card.duration = o.duration
            card.cabin = o.cabin
            card.tripType = o.tripType
            card.airlines = o.airlines
            card.highlights = o.highlights
            card.rating = o.rating
            card.reviewCount = o.reviewCount
            card.city = o.city
            card.totalPrice = o.totalPrice
            card.dateRange = o.dateRange
            card.crossedOutPrice = o.crossedOutPrice
            card.discountText = o.discountText
            card.nights = o.nights
            card.travelers = o.travelers
            card.aircraft = o.aircraft
            card.flightNumber = o.flightNumber
        }
        // Lodging: guarantee the redesigned card's fields. Use real values from
        // the baked dataset when present, else synthesize deterministically so
        // agent-driven / mock hotels look identical to the baked ones.
        if kind == .lodging {
            if card.rating == nil {
                let synth = synthReview(title)
                card.rating = synth.score
                card.reviewCount = synth.count
            }
            card.city = card.city ?? cityHint
            if card.totalPrice == nil,
               let nightly = nightlyValue(price: resolvedPrice, option: option) {
                card.totalPrice = currency(nightly * stayNights)
            }
        }
        // Flights: guarantee the redesigned card's fields. Prefer baked values,
        // else synthesize deterministically so mock/agent flights look identical
        // to the authored ones (aircraft, flight number, and a discount badge).
        if kind == .flights {
            let synth = synthFlightMeta(title + (card.airlines.first ?? ""))
            if card.aircraft == nil { card.aircraft = synth.aircraft }
            if card.flightNumber == nil {
                let code = airlineCode(card.airlines.first)
                card.flightNumber = "\(code) \(synth.flightNumber)"
            }
            if card.discountText == nil, card.crossedOutPrice == nil,
               let value = option?.priceValue ?? intFromPrice(resolvedPrice) {
                let original = Int(Double(value) / (1.0 - Double(synth.discountPct) / 100.0))
                card.crossedOutPrice = currency(original)
                card.discountText = "\(synth.discountPct)% Off"
            }
        }
        return card
    }

    /// Deterministic aircraft / flight-number / discount from a stable hash —
    /// keeps synthesized flight merchandising consistent across rebuilds.
    private static func synthFlightMeta(_ seed: String) -> (aircraft: String, flightNumber: Int, discountPct: Int) {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let aircraft = ["Boeing 777", "Airbus A321neo", "Boeing 737 MAX", "Airbus A320", "Boeing 787"]
        return (aircraft[Int(h % UInt64(aircraft.count))],
                100 + Int((h >> 8) % 899),
                [10, 12, 15, 18, 20][Int((h >> 16) % 5)])
    }

    /// Two-letter IATA-ish code for the flight-number prefix.
    private static func airlineCode(_ airline: String?) -> String {
        switch airline {
        case "JetBlue":   return "B6"
        case "Delta":     return "DL"
        case "American":  return "AA"
        case "United":    return "UA"
        case "Spirit":    return "NK"
        case "Alaska":    return "AS"
        case "Southwest": return "WN"
        default:          return String((airline ?? "XX").prefix(2)).uppercased()
        }
    }

    /// Parse the leading integer out of a "$514" style price string.
    private static func intFromPrice(_ price: String?) -> Int? {
        guard let price else { return nil }
        let digits = price.filter(\.isNumber)
        return Int(digits)
    }

    /// Deterministic guest score (8.0–9.7) + review count from a stable hash of
    /// the property name — keeps synthesized ratings consistent across rebuilds.
    private static func synthReview(_ seed: String) -> (score: Double, count: Int) {
        var h: UInt64 = 1469598103934665603
        for b in seed.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        let score = (80 + Int(h % 18)) // 80…97 → 8.0…9.7
        let count = 80 + Int((h >> 8) % 1400)
        return (Double(score) / 10.0, count)
    }

    /// Nightly price as an integer, from the numeric option value or the "$…" string.
    private static func nightlyValue(price: String?, option: Option?) -> Int? {
        if let v = option?.priceValue { return v }
        guard let p = price else { return nil }
        let digits = p.prefix { $0 != "/" }.filter(\.isNumber)
        return Int(digits)
    }

    /// "$1,575" — grouped USD, no decimals.
    private static func currency(_ v: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return "$" + (f.string(from: NSNumber(value: v)) ?? "\(v)")
    }

    /// Build one stack of cards + UI blocks for a thread (data.js buildResultSet).
    static func buildResultSet(threadId: String, kind: Kind, title: String, summary: String,
                               options: [Option], label: String,
                               blockSpecs: [BlockSpec] = []) -> ResultSet {
        let setId = IDGen.uid("set")
        let fallbackOptions = options.isEmpty && blockSpecs.isEmpty ? [Option(title: title)] : options
        let opts = Array(fallbackOptions.prefix(4))
        let cityHint = locationFromTitle(title)

        let cards = opts.enumerated().map { (i, opt) in
            buildCard(threadId: threadId, setId: setId, index: i, kind: kind,
                      title: opt.title, detail: opt.detail, price: opt.price,
                      image: opt.imageURL, option: opt, cityHint: cityHint)
        }

        // Blocks: hydrate the LLM's layout if present, else synthesize a default.
        let blocks = blockSpecs.isEmpty
            ? defaultBlocks(threadId: threadId, setId: setId, kind: kind, summary: summary,
                            cards: cards, cityHint: cityHint)
            : hydrate(blockSpecs, threadId: threadId, setId: setId, kind: kind, cityHint: cityHint)

        return ResultSet(id: setId, title: title.isEmpty ? "Results" : title,
                         summary: summary, label: label, options: opts, cards: cards, blocks: blocks)
    }

    // MARK: - block hydration

    /// Hydrate LLM block specs into rendered blocks (items → cards with images).
    private static func hydrate(_ specs: [BlockSpec], threadId: String, setId: String,
                                kind: Kind, cityHint: String? = nil) -> [ResultBlock] {
        specs.enumerated().map { (i, spec) in
            let bid = "\(setId)-b\(i)"
            switch spec.style {
            case .text, .heading:
                return ResultBlock(
                    id: bid,
                    style: spec.style,
                    text: spec.text,
                    cardPresentation: spec.cardPresentation,
                    semanticType: spec.semanticType,
                    semanticProps: spec.semanticProps
                )
            case .highlight, .cards, .carousel:
                let blockKind = spec.kind ?? kind
                let presentation = spec.cardPresentation == .automatic
                    ? defaultCardPresentation(for: blockKind)
                    : spec.cardPresentation
                let cards = spec.items.enumerated().map { (j, o) in
                    buildCard(threadId: threadId, setId: bid, index: j, kind: blockKind,
                              title: o.title, detail: o.detail, price: o.price,
                              image: o.imageURL, option: o, cityHint: cityHint)
                }
                return ResultBlock(
                    id: bid,
                    style: spec.style,
                    text: spec.text,
                    cards: cards,
                    cardPresentation: presentation,
                    semanticType: spec.semanticType,
                    semanticProps: spec.semanticProps
                )
            }
        }
    }

    private static func defaultCardPresentation(for kind: Kind) -> ResultCardPresentation {
        switch kind {
        case .lodging: return .lodging
        case .flights: return .flight
        case .cars, .activities, .other: return .generic
        }
    }

    /// Default layout when no LLM blocks: intro text · hero cards · "more" carousel.
    static func defaultBlocks(threadId: String, setId: String, kind: Kind,
                              summary: String, cards: [Card], cityHint: String? = nil) -> [ResultBlock] {
        guard !cards.isEmpty else { return [] }
        var blocks: [ResultBlock] = [
            ResultBlock(id: "\(setId)-b0", style: .text,
                        text: summary.isEmpty ? introText(kind) : summary),
            ResultBlock(
                id: "\(setId)-b1",
                style: .cards,
                cards: Array(cards.prefix(3)),
                cardPresentation: defaultCardPresentation(for: kind)
            ),
        ]
        let alts = altItems[kind] ?? []
        if !alts.isEmpty {
            let altCards = alts.enumerated().map { (i, o) in
                buildCard(threadId: threadId, setId: "\(setId)-alt", index: i, kind: kind,
                          title: o.title, detail: o.detail, price: o.price, option: o,
                          cityHint: cityHint)
            }
            blocks.append(ResultBlock(id: "\(setId)-b2", style: .heading, text: "You might also like"))
            blocks.append(ResultBlock(
                id: "\(setId)-b3",
                style: .carousel,
                cards: altCards,
                cardPresentation: defaultCardPresentation(for: kind)
            ))
        }
        return blocks
    }

    private static func introText(_ kind: Kind) -> String {
        switch kind {
        case .lodging: return "Here are a few places to stay that fit your trip — I've pulled together some standout options and a handful of alternatives."
        case .flights: return "I found a few flights for your dates. Here are the strongest options, plus some other airlines worth a look."
        case .cars: return "Here are some rental cars near you — a couple of top picks and a few other classes to consider."
        case .activities: return "Here are some things to do — a few highlights and more ideas to explore."
        case .other: return "Here's what I found for you."
        }
    }

    /// Extra items used to populate the "more" carousel in the default layout.
    private static let altItems: [Kind: [Option]] = [
        .lodging: [Option(title: "Beachfront Inn", detail: "$310 · Ocean view"),
                   Option(title: "Downtown Boutique", detail: "$189 · City center"),
                   Option(title: "Bayside Suites", detail: "$268 · Bay view"),
                   Option(title: "Palm Garden Hotel", detail: "$145 · Pool"),
                   Option(title: "Harbor Lofts", detail: "$205 · Marina")],
        .flights: [Option(title: "Delta", detail: "$420 · Nonstop"),
                   Option(title: "American", detail: "$365 · 1 stop"),
                   Option(title: "JetBlue", detail: "$399 · Nonstop"),
                   Option(title: "United", detail: "$340 · 1 stop"),
                   Option(title: "Alaska", detail: "$455 · Nonstop")],
        .cars: [Option(title: "Economy", detail: "$28 / day"),
                Option(title: "Midsize", detail: "$41 / day"),
                Option(title: "SUV", detail: "$54 / day"),
                Option(title: "Convertible", detail: "$72 / day"),
                Option(title: "Electric", detail: "$60 / day")],
        .activities: [Option(title: "City walking tour", detail: "$35"),
                      Option(title: "Snorkel trip", detail: "$89"),
                      Option(title: "Food tour", detail: "$65"),
                      Option(title: "Museum pass", detail: "$28"),
                      Option(title: "Sunset cruise", detail: "$75")],
        .other: [Option(title: "Popular right now", detail: "Trending"),
                 Option(title: "Coastal escapes", detail: "Beach & surf"),
                 Option(title: "Hidden gems", detail: "Off the beaten path"),
                 Option(title: "Weekend getaways", detail: "Short trips"),
                 Option(title: "Local favorites", detail: "Highly rated")],
    ]

    /// Build a fully-formed thread node from a structured payload (data.js buildThreadNode).
    static func buildThreadNode(_ p: ThreadPayload) -> ThreadNode {
        let id = IDGen.uid(p.kind.rawValue)
        let first = buildResultSet(threadId: id, kind: p.kind, title: p.title,
                                   summary: p.summary, options: p.options, label: p.label,
                                   blockSpecs: p.blocks)
        let hero = first.cards.first?.imageURL
        let preview = Preview(
            icon: hero == nil ? p.kind.icon : nil,
            imageURL: hero,
            sublabel: p.title.isEmpty ? "Results" : p.title,
            message: p.summary,
            layoutId: "\(id)-card"
        )
        return ThreadNode(id: id, kind: p.kind, title: p.title.isEmpty ? "Results" : p.title,
                          source: p.source, composition: p.composition,
                          scenarioID: p.scenarioID, scenarioStep: p.scenarioStep,
                          presentation: p.presentation, continuation: p.continuation,
                          decision: p.decision, preview: preview, resultSets: [first])
    }

    /// Fallback card for free-text input with no detected intent, so every input
    /// still produces a card in the trip overview.
    static func genericThread(_ text: String) -> ThreadNode {
        let kind = detectIntent(text) ?? .other
        let title = text.prefix(1).uppercased() + text.dropFirst()
        return buildThreadNode(ThreadPayload(
            kind: kind, title: String(title), summary: "",
            label: "Results", chip: "", options: []))
    }

    /// Refinement: REPLACE the latest result set in place + fold the chip into
    /// the query filters (data.js applyRefinement).
    static func applyRefinement(_ node: ThreadNode, _ p: ThreadPayload) -> ThreadNode {
        let set = buildResultSet(threadId: node.id, kind: node.kind, title: p.title,
                                 summary: p.summary, options: p.options, label: p.label,
                                 blockSpecs: p.blocks)
        let hero = set.cards.first?.imageURL
        var n = node
        let chip = p.chip.trimmingCharacters(in: .whitespaces)
        var filters = p.presentation.filters
        if filters.isEmpty { filters = n.presentation.filters }
        if !chip.isEmpty, !filters.contains(where: { $0.lowercased() == chip.lowercased() }) {
            filters.append(chip)
        }
        n.presentation = ResultsPresentation(
            showsMap: p.presentation.showsMap,
            showsFilters: p.presentation.showsFilters,
            overlaySheet: p.presentation.overlaySheet,
            mapLayout: p.presentation.mapLayout,
            canvasLayout: p.presentation.canvasLayout,
            filters: filters,
            refinements: p.presentation.refinements,
            map: p.presentation.map
        )
        n.continuation = p.continuation ?? n.continuation
        n.decision = p.decision ?? n.decision
        if let scenarioID = p.scenarioID { n.scenarioID = scenarioID }
        if let scenarioStep = p.scenarioStep { n.scenarioStep = scenarioStep }
        n.source = p.source
        n.composition = p.composition
        if n.resultSets.isEmpty { n.resultSets = [set] } else { n.resultSets[n.resultSets.count - 1] = set }
        if !p.title.isEmpty { n.title = p.title }
        n.resultsLabel = p.label.isEmpty ? (n.resultsLabel ?? "Updated results") : p.label
        n.preview.imageURL = hero ?? n.preview.imageURL
        n.preview.icon = hero == nil ? n.preview.icon : nil
        if !p.title.isEmpty { n.preview.sublabel = p.title }
        if !p.summary.isEmpty { n.preview.message = p.summary }
        return n
    }

    /// Append a compare/map sub-action (data.js appendActivity).
    static func appendActivity(_ node: ThreadNode, type: ActivityType, subtitle: String,
                               comparison: Comparison? = nil) -> ThreadNode {
        var n = node
        n.activities.append(Activity(id: IDGen.uid("act"), type: type, subtitle: subtitle,
                                     comparison: comparison))
        return n
    }

    /// Build a two-option comparison from a thread's current cards (mock highlights).
    static func buildComparison(from node: ThreadNode) -> Comparison {
        let cards = node.activeCards
        let a = cards.first
        let b = cards.count > 1 ? cards[1] : nil
        let titleA = a?.displayTitle ?? "Option A"
        var titleB = b?.displayTitle ?? "Option B"
        if titleB == titleA { titleB = "Oceanview Resort" }   // keep A vs B distinct in the demo
        return Comparison(
            titleA: titleA,
            titleB: titleB,
            imageA: a?.imageURL,
            imageB: b?.imageURL ?? a?.imageURL,
            priceA: a?.displayPrice ?? "$235",
            priceB: b?.displayPrice ?? "$289",
            categories: [
                CompareCategory(name: "Price", rows: [
                    CompareHighlight(label: "Price / night", a: a?.displayPrice ?? "$235", b: b?.displayPrice ?? "$289"),
                    CompareHighlight(label: "Total · 3 nights", a: "$705", b: "$867"),
                    CompareHighlight(label: "Free cancellation", a: "Yes", b: "Yes"),
                ]),
                CompareCategory(name: "Location", rows: [
                    CompareHighlight(label: "To the beach", a: "5 min walk", b: "Beachfront"),
                    CompareHighlight(label: "Neighborhood", a: "South Beach", b: "Mid-Beach"),
                ]),
                CompareCategory(name: "Amenities", rows: [
                    CompareHighlight(label: "Pool", a: "Rooftop", b: "3 pools"),
                    CompareHighlight(label: "Wi-Fi", a: "Free", b: "Free"),
                    CompareHighlight(label: "Breakfast", a: "Included", b: "$18 / day"),
                    CompareHighlight(label: "Parking", a: "$25 / day", b: "Valet $40"),
                ]),
                CompareCategory(name: "Rooms", rows: [
                    CompareHighlight(label: "Room type", a: "King suite", b: "Ocean double"),
                    CompareHighlight(label: "Guest rating", a: "8.9 · Fabulous", b: "9.2 · Superb"),
                    CompareHighlight(label: "Sleeps", a: "2 guests", b: "4 guests"),
                ]),
            ]
        )
    }

    // MARK: - factories (root category asks)

    private static func card(_ threadId: String, _ i: Int, sublabel: String,
                             title: String? = nil, price: String? = nil,
                             icon: String? = nil, image: String? = nil) -> Card {
        let cid = "\(threadId)-r\(i)"
        return Card(id: cid, title: title, price: price, sublabel: sublabel,
                    icon: icon, imageURL: image, layoutId: cid)
    }

    /// A seed lodging card carrying the redesigned card's rating/total fields.
    private static func hotelSeedCard(_ threadId: String, _ i: Int, title: String,
                                      price: String, image: String,
                                      rating: Double, reviews: Int, city: String) -> Card {
        let cid = "\(threadId)-r\(i)"
        var c = Card(id: cid, title: title, price: price, sublabel: title,
                     icon: nil, imageURL: image, layoutId: cid)
        c.rating = rating
        c.reviewCount = reviews
        c.city = city
        if let nightly = Int(price.filter(\.isNumber)) {
            c.totalPrice = currency(nightly * stayNights)
        }
        return c
    }

    private static func carsThread() -> ThreadNode {
        let id = IDGen.uid("cars")
        let cards = [
            card(id, 0, sublabel: "Compact · $32/day",
                 image: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600&q=80"),
            card(id, 1, sublabel: "SUV · $54/day",
                 image: "https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=600&q=80"),
        ]
        let setId = IDGen.uid("set")
        let set = ResultSet(id: setId, title: "Miami car rental prices",
                            summary: "I found a few rental cars near the airport.",
                            label: "Initial results", options: [], cards: cards,
                            blocks: defaultBlocks(threadId: id, setId: setId, kind: .cars,
                                                  summary: "I found a few rental cars near the airport.",
                                                  cards: cards))
        let preview = Preview(icon: nil,
                              imageURL: "https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=600&q=80",
                              sublabel: "Rental cars",
                              message: "I found a few rental cars near the airport.",
                              layoutId: "\(id)-card")
        return ThreadNode(id: id, kind: .cars, title: "Miami car rental prices",
                          preview: preview, resultSets: [set])
    }

    private static func lodgingThread() -> ThreadNode {
        let id = IDGen.uid("lodging")
        let cards = [
            hotelSeedCard(id, 0, title: "Hotel villa del mar", price: "$235",
                          image: "/v1/hotel-1.jpg", rating: 9.1, reviews: 486, city: "Miami"),
            hotelSeedCard(id, 1, title: "Hotel villa del mar", price: "$235",
                          image: "/v1/hotel-2.jpg", rating: 8.7, reviews: 322, city: "Miami"),
        ]
        let setId = IDGen.uid("set")
        let set = ResultSet(id: setId, title: "Hotels in Miami",
                            summary: "Here are some places to stay for your trip.",
                            label: "Initial results", options: [], cards: cards,
                            blocks: defaultBlocks(threadId: id, setId: setId, kind: .lodging,
                                                  summary: "Here are some places to stay for your trip.",
                                                  cards: cards))
        let preview = Preview(icon: nil, imageURL: "/v1/hotel-1.jpg", sublabel: "Hotels in Miami",
                              message: "Here are some places to stay for your trip.",
                              layoutId: "\(id)-card")
        return ThreadNode(id: id, kind: .lodging, title: "Hotels in Miami",
                          preview: preview, resultSets: [set])
    }

    private static func flightsThread() -> ThreadNode {
        let id = IDGen.uid("flights")
        let cards = [
            card(id, 0, sublabel: "Nonstop · 7h 45m", icon: "flight"),
            card(id, 1, sublabel: "1 stop · 11h 20m", icon: "flight"),
        ]
        let setId = IDGen.uid("set")
        let set = ResultSet(id: setId, title: "Flights",
                            summary: "I found a few flights for your dates.",
                            label: "Initial results", options: [], cards: cards,
                            blocks: defaultBlocks(threadId: id, setId: setId, kind: .flights,
                                                  summary: "I found a few flights for your dates.",
                                                  cards: cards))
        let preview = Preview(icon: "flight", imageURL: nil, sublabel: "Flight results",
                              message: "I found a few flights for your dates.",
                              layoutId: "\(id)-card")
        return ThreadNode(id: id, kind: .flights, title: "Flights",
                          source: .mock, composition: .flightList,
                          preview: preview, resultSets: [set])
    }

    private static func factory(for kind: Kind) -> ThreadNode? {
        switch kind {
        case .cars: return carsThread()
        case .lodging: return lodgingThread()
        case .flights: return flightsThread()
        default: return nil
        }
    }

    // MARK: - generateResponse

    private static let kindLabel: [Kind: String] = [
        .flights: "flights", .lodging: "lodging", .cars: "rental cars",
    ]

    /// Decide what the assistant says (and whether a new thread is spun up).
    /// `node == nil` means the trip root. Returns the same shape as the AI path.
    static func generateResponse(node: ThreadNode?, text: String) -> AssistantResponse {
        let intent = detectIntent(text)

        // ---- trip root ----
        guard let node else {
            if let intent, let item = factory(for: intent) {
                return AssistantResponse(reply: item.preview.message, prebuiltThread: item)
            }
            return AssistantResponse(reply: "I can help plan flights, lodging, and rental cars — just ask, e.g. \"find me a rental car\".")
        }

        // ---- inside a lodging thread: keyword refinements ----
        if node.kind == .lodging {
            if rx(text, #"\b(cheap|cheaper|budget|afford\w*|less|lower)\b"#) {
                let title = rx(node.title, #"^budget"#) ? node.title : "Budget \(node.title)"
                return AssistantResponse(reply: "Showing more budget-friendly stays.",
                    thread: ThreadPayload(kind: .lodging, title: title,
                        summary: "Showing budget-friendly hotel options.",
                        label: "Budget friendly options", chip: "budget",
                        options: [Option(title: "Z Hotel Shoreditch", price: "$129"),
                                  Option(title: "Premier Inn City", price: "$98")]))
            }
            if rx(text, #"\bpool\b"#) {
                return AssistantResponse(reply: "Comparing hotels with the best pools.",
                    thread: ThreadPayload(kind: .lodging, title: node.title,
                        summary: "Which has the best pool", label: "Best pool", chip: "",
                        options: [Option(title: "Hotel villa del mar", price: "$235"),
                                  Option(title: "Oceanview Resort", price: "$289")]))
            }
            if rx(text, #"\b(beach|closest)\b"#) {
                return AssistantResponse(reply: "Showing options closest to the beach.",
                    thread: ThreadPayload(kind: .lodging, title: node.title,
                        summary: "Closest to the beach", label: "Closest to beach", chip: "beachfront",
                        options: [Option(title: "Hotel villa del mar", price: "$235"),
                                  Option(title: "Beachfront Inn", price: "$310")]))
            }
        }

        let label = kindLabel[node.kind] ?? "options"
        return AssistantResponse(reply: "Tell me what matters most and I'll refine these \(label) for you.")
    }
}

// MARK: - Card display normalization (data.js normalizeResultCard)

extension Card {
    /// Title for display: explicit title, else the head of the sublabel.
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let head = sublabel.components(separatedBy: " · ").first, !head.isEmpty { return head }
        return "Result"
    }

    /// Price for display: explicit price, else a "$…" tail/whole of the sublabel.
    var displayPrice: String? {
        if let p = price, !p.isEmpty { return p }
        if sublabel.contains("·"),
           let tail = sublabel.components(separatedBy: " · ").last, tail.hasPrefix("$") {
            return tail
        }
        if sublabel.hasPrefix("$") { return sublabel }
        return nil
    }
}
