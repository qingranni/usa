//
//  DestinationData.swift
//  Universal Search App
//
//  Dev-time-baked destination dataset for LA, Tampa, and 5 Mexican beach
//  cities. Hotels + hero images are REAL data captured from the lodging search
//  API (Expedia CDN imagery); flights, cars, and activities are authored. This
//  layer is the first fallback after narrative golden paths, so covered
//  destinations resolve deterministically and offline (see AppStore.assistant).
//

import Foundation

enum DestinationData {

    // MARK: - baked model

    struct Hotel {
        let name: String
        let price: Int        // nightly USD
        let stars: Double
        let area: String
        /// Bundled asset name (top picks) or a remote Expedia CDN URL.
        let image: String
    }

    struct City {
        let slug: String
        let name: String
        let airport: String
        let hotels: [Hotel]
        let flights: [Option]
        let cars: [Option]
        let activities: [Option]
    }

    // MARK: - public entry

    /// Returns a fully-built thread for a covered destination, or `nil` so the
    /// caller falls back to generic mock templates. Only fires for brand-new queries
    /// (the app always spins free-text into a new thread).
    static func response(text: String) -> AssistantResponse? {
        guard let cities = match(text), let primary = cities.first else { return nil }
        let bucket = cities.count > 1
        let name = bucket ? "Mexico" : primary.name

        let kind = Mock.detectIntent(text)
        let budgetNightly = parseBudgetNightly(text)
        let nonstopOnly = rx(text, #"non[-\s]?stop|direct"#)
        let cheap = rx(text, #"cheap\w*|budget|afford\w*|low(est)? price|less expensive"#)
        let origin = parseOrigin(text)

        // Pools (bucket = spread across the Mexican cities).
        let hotelPool = bucket ? interleave(cities.map(\.hotels)) : primary.hotels
        let flightPool = primary.flights
        let carPool = primary.cars
        let activityPool = bucket ? interleave(cities.map(\.activities)) : primary.activities

        var hotels = filterHotels(hotelPool, budgetNightly: budgetNightly, cheap: cheap)
        let hotelOpts = hotels.map(hotelOption)
        let flightOpts = filterFlights(flightPool, origin: origin, nonstop: nonstopOnly, cheap: cheap)
        let carOpts = carPool
        let activityOpts = activityPool

        switch kind {
        case .lodging:
            let payload = single(kind: .lodging, title: "Hotels in \(name)",
                                 summary: "Here are some places to stay in \(name) for your trip.",
                                 options: hotelOpts, more: "More places to stay")
            return reply("I found \(hotels.count) places to stay in \(name).", payload)
        case .flights:
            var chips = ["3 travelers"]
            if nonstopOnly { chips.append("Nonstop") }
            chips.append("Economy")
            let payload = single(kind: .flights, title: "Flights to \(name)",
                                 summary: "Sorted for good prices and convenient times — like your past family visits.",
                                 options: flightOpts, more: "More departing flights",
                                 composition: .flightList,
                                 filters: chips)
            return reply("Here are flights to \(name) from JFK and Houston.", payload)
        case .cars:
            let payload = single(kind: .cars, title: "Car rental in \(name)",
                                 summary: "Rental cars available near \(name).",
                                 options: carOpts, more: "More vehicles")
            return reply("Here are rental cars in \(name).", payload)
        case .activities:
            let payload = single(kind: .activities, title: "Things to do in \(name)",
                                 summary: "Top activities and experiences around \(name).",
                                 options: activityOpts, more: "More things to do")
            return reply("Here's what to do in \(name).", payload)
        case .other, .none:
            let payload = overview(name: name, hotels: hotelOpts, flights: flightOpts,
                                   cars: carOpts, activities: activityOpts)
            return reply("Here's a plan for \(name) — where to stay, how to get there, and what to do.", payload)
        }
    }

    // MARK: - thread builders

    private static func reply(_ text: String, _ p: ThreadPayload) -> AssistantResponse {
        AssistantResponse(reply: text, prebuiltThread: Mock.buildThreadNode(p))
    }

    /// A single-kind thread: intro · hero cards · "more" carousel.
    private static func single(kind: Kind, title: String, summary: String,
                               options: [Option], more: String,
                               composition: ResultComposition = .blocks,
                               filters: [String] = []) -> ThreadPayload {
        let top = Array(options.prefix(3))
        let rest = Array(options.dropFirst(3))
        var blocks: [BlockSpec] = [
            BlockSpec(style: .text, text: summary),
            BlockSpec(style: .cards, items: top, kind: kind),
        ]
        if !rest.isEmpty {
            blocks.append(BlockSpec(style: .heading, text: more))
            blocks.append(BlockSpec(style: .carousel, items: rest, kind: kind))
        }
        return ThreadPayload(kind: kind, title: title, summary: summary,
                             label: "Initial results", chip: "", options: top,
                             composition: composition,
                             presentation: ResultsPresentation(filters: filters),
                             blocks: blocks)
    }

    /// An open-ended trip overview spanning all four categories.
    private static func overview(name: String, hotels: [Option], flights: [Option],
                                 cars: [Option], activities: [Option]) -> ThreadPayload {
        var blocks: [BlockSpec] = [
            BlockSpec(style: .text,
                      text: "Here's everything you need for \(name) — standout places to stay, flights from JFK and Houston, rental cars, and things to do."),
        ]
        if !hotels.isEmpty {
            blocks.append(BlockSpec(style: .heading, text: "Where to stay"))
            blocks.append(BlockSpec(style: .cards, items: Array(hotels.prefix(3)), kind: .lodging))
        }
        if !flights.isEmpty {
            blocks.append(BlockSpec(style: .heading, text: "Flights from JFK & Houston"))
            blocks.append(BlockSpec(style: .carousel, items: Array(flights.prefix(6)), kind: .flights))
        }
        if !cars.isEmpty {
            blocks.append(BlockSpec(style: .heading, text: "Getting around"))
            blocks.append(BlockSpec(style: .carousel, items: Array(cars.prefix(6)), kind: .cars))
        }
        if !activities.isEmpty {
            blocks.append(BlockSpec(style: .heading, text: "Things to do"))
            blocks.append(BlockSpec(style: .carousel, items: Array(activities.prefix(6)), kind: .activities))
        }
        return ThreadPayload(kind: .other, title: "Trip to \(name)",
                             summary: "A beach-ready plan for \(name).",
                             label: "Trip overview", chip: "",
                             options: Array(hotels.prefix(3)), blocks: blocks)
    }

    private static func hotelOption(_ h: Hotel) -> Option {
        let r = hotelReviews[h.name]
        return Option(title: h.name,
               detail: "$\(h.price)/night · \(starStr(h.stars)) · \(h.area)",
               price: "$\(h.price)", imageURL: h.image, priceValue: h.price,
               // One reserved highlights slot — stubbed for now (refundable/cancellation).
               // Swap later for property attributes or AI-generated copy.
               highlights: "Fully refundable · Free cancellation",
               rating: r?.score, reviewCount: r?.count, city: r?.city)
    }

    /// Real guest ratings (0–10 scale), review counts, and resolved property
    /// cities pulled from the lodging/content APIs, keyed by baked hotel name.
    /// A handful of long-tail properties with no returned reviews carry
    /// plausible authored values so every baked hotel renders a full rating line.
    private static let hotelReviews: [String: (score: Double, count: Int, city: String)] = [
        // Cancún
        "Ocean Dream Cancun by GuruHotel": (8.8, 1058, "Cancún"),
        "Hyatt Ziva Cancun": (9.2, 3560, "Cancún"),
        "Dreams Sands Cancun Resort & Spa": (9.0, 2184, "Cancún"),
        "Hard Rock Hotel Cancun - All Inclusive": (8.6, 1944, "Cancún"),
        "Riu Cancun All Inclusive": (8.8, 998, "Cancún"),
        "InterContinental Presidente Cancun Resort": (8.6, 997, "Cancún"),
        "Izla Hotel": (9.2, 996, "Isla Mujeres"),
        "Hotel Bonampak": (9.0, 999, "Cancún"),
        "Laguna Suites Golf & Spa All Inclusive": (10.0, 2, "Cancún"),
        "Hacienda Morelos Beachfront Hotel": (8.0, 526, "Puerto Morelos"),
        "Chichis & Charlies": (7.8, 211, "Isla Mujeres"),
        "Hotel Plaza Caribe": (8.4, 5, "Cancún"),
        "Grand Royal Lagoon": (5.0, 4, "Cancún"),
        "Posada Amor Hotel Boutique": (7.2, 177, "Puerto Morelos"),
        // Cabo San Lucas
        "Riu Palace Cabo San Lucas All Inclusive": (8.6, 999, "Cabo San Lucas"),
        "Casa Dorada Los Cabos Resort & Spa": (9.0, 997, "Cabo San Lucas"),
        "Villa del Arco Beach Resort & Spa": (7.4, 3, "Cabo San Lucas"),
        "The Towers at Pueblo Bonito Pacifica": (9.0, 62, "Cabo San Lucas"),
        "Grand Solmar at Rancho San Lucas Resort": (9.6, 4, "Cabo San Lucas"),
        "Montage Los Cabos": (10.0, 1, "Cabo San Lucas"),
        "El Encanto Inn & Suites": (8.6, 354, "San José del Cabo"),
        "City Express Plus Cabo San Lucas": (8.8, 577, "Cabo San Lucas"),
        "Medano Hotel and Suites": (8.4, 8, "Cabo San Lucas"),
        "Cabo Inn Hotel": (7.4, 8, "Cabo San Lucas"),
        // Puerto Vallarta
        "Garza Blanca Preserve Resort & Spa": (9.2, 1000, "Puerto Vallarta"),
        "The St. Regis Punta Mita Resort": (9.4, 280, "Punta de Mita"),
        "Sheraton Buganvilias Resort & Convention Center": (8.2, 998, "Puerto Vallarta"),
        "Krystal Puerto Vallarta": (6.8, 997, "Puerto Vallarta"),
        "Casa Kimberly": (9.8, 76, "Puerto Vallarta"),
        "Casa Cúpula Luxury Boutique Hotel": (9.2, 189, "Puerto Vallarta"),
        "Ocean Breeze Nuevo Vallarta": (8.0, 240, "Nuevo Vallarta"),
        "Blue Chairs Resort by the Sea": (5.8, 998, "Puerto Vallarta"),
        "Hotel Portonovo Plaza Malecón": (8.2, 989, "Puerto Vallarta"),
        "The Hacienda at Hilton Puerto Vallarta": (8.2, 10, "Puerto Vallarta"),
        // Tulum / Riviera Maya (shared names reused by Playa del Carmen)
        "Ambassador at Grand Velas All Inclusive": (9.0, 33, "Playa del Carmen"),
        "Aldea Thai by Moskito": (8.6, 8, "Playa del Carmen"),
        "The Meridian by Bric": (6.0, 3, "Playa del Carmen"),
        "Hilton Playa del Carmen All-Inclusive Adult Resort": (8.8, 995, "Playa del Carmen"),
        "Magia Beachside by Bric": (9.8, 13, "Playa del Carmen"),
        "Bright, Airy Beachside Apartment": (8.8, 60, "Puerto Morelos"),
        "Casa Riviera Lol Tun": (8.6, 45, "Tulum"),
        "Vainilla Bed & Breakfast": (9.6, 52, "Playa del Carmen"),
        "Poolside Balcony Apartment": (8.4, 38, "Puerto Morelos"),
        "The Royal Palms by Bric": (9.0, 26, "Playa del Carmen"),
        // Playa del Carmen extras
        "Posada Mariposa Boutique Hotel": (8.2, 647, "Playa del Carmen"),
        "HM Playa del Carmen": (8.8, 844, "Playa del Carmen"),
        "Skyline 24th by Playa Paradise": (8.4, 8, "Playa del Carmen"),
        // Los Angeles
        "Millennium Biltmore Los Angeles": (8.2, 997, "Los Angeles"),
        "Best Western Plus Sunset Plaza Hotel": (7.8, 640, "West Hollywood"),
        "H Hotel Los Angeles, Curio Collection by Hilton": (8.6, 999, "Los Angeles"),
        "Homewood Suites by Hilton LAX": (8.4, 993, "Los Angeles"),
        "Ramada by Wyndham LA/Koreatown West": (7.2, 997, "Los Angeles"),
        "DoubleTree by Hilton LA Rosemead": (8.2, 996, "Rosemead"),
        "SureStay Hotel Beverly Hills West LA": (6.8, 655, "Los Angeles"),
        "Hilton Garden Inn LAX El Segundo": (8.2, 997, "El Segundo"),
        "Foghorn Harbor Inn": (8.0, 995, "Marina del Rey"),
        "Quality Inn & Suites Hermosa Beach": (8.2, 997, "Hermosa Beach"),
        // Tampa
        "The Westin Tampa Waterside": (8.4, 999, "Tampa"),
        "Tampa Airport Marriott": (8.2, 520, "Tampa"),
        "Wyndham Grand Clearwater Beach": (9.2, 995, "Clearwater Beach"),
        "Home2 Suites by Hilton Brandon Tampa": (9.2, 628, "Tampa"),
        "Hampton Inn Tampa-Veterans Expwy": (8.4, 410, "Tampa"),
        "Embassy Suites Tampa Downtown": (8.2, 994, "Tampa"),
        "Courtyard by Marriott Tampa Downtown": (8.4, 987, "Tampa"),
        "The Barrymore Hotel Tampa Riverwalk": (7.4, 999, "Tampa"),
        "Four Points by Sheraton Suites Tampa Airport": (8.4, 996, "Tampa"),
        "Holiday Inn Express Rocky Point Island": (8.0, 999, "Tampa"),
    ]

    private static func starStr(_ s: Double) -> String {
        s == s.rounded() ? "\(Int(s))★" : String(format: "%.1f★", s)
    }

    // MARK: - detection

    private static func rx(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func match(_ text: String) -> [City]? {
        if rx(text, #"\bcanc[uú]n\b"#) { return [cancun] }
        if rx(text, #"\b(cabo|los cabos|san lucas)\b"#) { return [cabo] }
        if rx(text, #"\b(puerto vallarta|vallarta)\b"#) { return [puertoVallarta] }
        if rx(text, #"\btulum\b"#) { return [tulum] }
        if rx(text, #"\bplaya del carmen\b"#) { return [playaDelCarmen] }
        if rx(text, #"\btampa\b"#) { return [tampa] }
        if rx(text, #"\b(los angeles|l\.?a\.?|lax|hollywood)\b"#) { return [losAngeles] }
        if rx(text, #"\bm[eé]xico\b"#) { return mexico }
        return nil
    }

    private static func parseOrigin(_ text: String) -> String? {
        if rx(text, #"\b(jfk|new york|nyc|newark|ewr)\b"#) { return "JFK" }
        if rx(text, #"\b(hou|hobby)\b"#) { return "HOU" }
        if rx(text, #"\b(houston|iah)\b"#) { return "IAH" }
        return nil
    }

    private static func parseBudgetNightly(_ text: String) -> Int? {
        // Only treat a $-amount or an "under/below/up to N" phrase as a budget —
        // avoids swallowing "1 adult", "2 teenagers", dates, etc.
        let patterns = [#"\$\s?(\d[\d,]{2,6})"#,
                        #"(?:under|below|less than|up to|budget of|around)\s+\$?(\d[\d,]{2,6})"#]
        for p in patterns {
            if let m = text.range(of: p, options: [.regularExpression, .caseInsensitive]) {
                let digits = text[m].filter(\.isNumber)
                if let raw = Int(digits), raw > 0 {
                    // A large figure reads as a whole-trip budget (~3 nights); small as nightly.
                    return raw >= 1000 ? raw / 3 : raw
                }
            }
        }
        return nil
    }

    private static func filterHotels(_ hotels: [Hotel], budgetNightly: Int?, cheap: Bool) -> [Hotel] {
        var out = hotels
        if let ceiling = budgetNightly {
            let kept = out.filter { $0.price <= ceiling }
            if !kept.isEmpty { out = kept }
        }
        if cheap { out.sort { $0.price < $1.price } }
        return Array(out.prefix(14))
    }

    private static func filterFlights(_ flights: [Option], origin: String?, nonstop: Bool, cheap: Bool) -> [Option] {
        var out = flights
        if let origin {
            let kept = out.filter { $0.title.contains(origin) }
            if !kept.isEmpty { out = kept }
        }
        if nonstop {
            let kept = out.filter { $0.detail.range(of: "nonstop", options: .caseInsensitive) != nil }
            if !kept.isEmpty { out = kept }
        }
        if cheap { out.sort { ($0.priceValue ?? 0) < ($1.priceValue ?? 0) } }
        return out
    }

    /// Round-robin merge so a "Mexico" spread alternates across cities.
    private static func interleave<T>(_ lists: [[T]]) -> [T] {
        var out: [T] = []
        let maxLen = lists.map(\.count).max() ?? 0
        for i in 0..<maxLen {
            for list in lists where i < list.count { out.append(list[i]) }
        }
        return out
    }

    // MARK: - shared authored data

    /// Fully-specified flight option. `airlines` may hold one carrier (nonstop) or
    /// two (connecting legs) — the card shows a logo per airline.
    private static func flight(_ route: String, dep: String, arr: String, _ dur: String,
                               _ stops: String, cabin: String, _ airlines: [String],
                               _ price: Int, roundTrip: Bool = true) -> Option {
        Option(title: route,
               detail: "$\(price) · \(stops) · \(dur) · \(airlines.joined(separator: ", "))",
               price: "$\(price)", priceValue: price,
               departTime: dep, arriveTime: arr, stops: stops, duration: dur,
               cabin: cabin, tripType: roundTrip ? "Round trip" : "One-way",
               airlines: airlines, logoURLs: airlines.compactMap(airlineLogo))
    }

    /// Maps an authored airline name to its bundled logo asset (Kiwi.com IATA logos).
    private static func airlineLogo(_ airline: String) -> String? {
        switch airline {
        case "JetBlue":    return "airline-b6"
        case "Delta":      return "airline-dl"
        case "American":   return "airline-aa"
        case "United":     return "airline-ua"
        case "Spirit":     return "airline-nk"
        case "Alaska":     return "airline-as"
        case "Southwest":  return "airline-wn"
        case "Aeromexico": return "airline-am"
        default:           return nil
        }
    }

    private static func act(_ title: String, _ price: Int, _ dur: String) -> Option {
        Option(title: title, detail: "$\(price) · \(dur)", price: "$\(price)", priceValue: price)
    }

    /// Rental fleet is generic across destinations.
    private static let cars: [Option] = [
        Option(title: "Economy — Nissan Versa", detail: "$34/day · Alamo", price: "$34/day", priceValue: 34),
        Option(title: "Compact — Chevrolet Onix", detail: "$38/day · Hertz", price: "$38/day", priceValue: 38),
        Option(title: "Midsize — Volkswagen Jetta", detail: "$46/day · Avis", price: "$46/day", priceValue: 46),
        Option(title: "Full-size — Toyota Camry", detail: "$58/day · Enterprise", price: "$58/day", priceValue: 58),
        Option(title: "SUV — Jeep Compass", detail: "$63/day · Budget", price: "$63/day", priceValue: 63),
        Option(title: "Minivan — Chrysler Pacifica", detail: "$78/day · Dollar", price: "$78/day", priceValue: 78),
        Option(title: "Convertible — Ford Mustang", detail: "$89/day · Sixt", price: "$89/day", priceValue: 89),
        Option(title: "Electric — Tesla Model 3", detail: "$95/day · Hertz", price: "$95/day", priceValue: 95),
    ]

    // MARK: - Cancun

    static let cancun = City(
        slug: "cancun", name: "Cancun", airport: "CUN",
        hotels: MexicoFixtureCatalog.hotels.map {
            Hotel(
                name: $0.name,
                price: $0.nightlyPrice,
                stars: $0.stars,
                area: $0.area,
                image: $0.imageURL
            )
        } + [
            Hotel(name: "Hotel Bonampak", price: 152, stars: 2.5, area: "Downtown Cancun", image: "https://mediaim.expedia.com/lodging/16000000/15090000/15083300/15083296/2e90295c.jpg"),
            Hotel(name: "Laguna Suites Golf & Spa All Inclusive", price: 184, stars: 3.0, area: "Pok Ta Pok", image: "https://mediaim.expedia.com/lodging/2000000/1180000/1170700/1170643/f5d914fa.jpg"),
            Hotel(name: "Hacienda Morelos Beachfront Hotel", price: 171, stars: 3.0, area: "Puerto Morelos", image: "https://mediaim.expedia.com/lodging/18000000/17120000/17119000/17118967/f673ba04.jpg"),
            Hotel(name: "Chichis & Charlies", price: 138, stars: 3.0, area: "Isla Mujeres", image: "https://mediaim.expedia.com/lodging/16000000/15430000/15426600/15426505/bbba3a22.jpg"),
            Hotel(name: "Hotel Plaza Caribe", price: 145, stars: 3.5, area: "Downtown", image: "https://mediaim.expedia.com/lodging/1000000/20000/17900/17834/712d4818.jpg"),
            Hotel(name: "Grand Royal Lagoon", price: 128, stars: 3.0, area: "Laguna", image: "https://mediaim.expedia.com/lodging/1000000/190000/186000/185907/797b3e08.jpg"),
            Hotel(name: "Posada Amor Hotel Boutique", price: 149, stars: 3.0, area: "Puerto Morelos", image: "https://mediaim.expedia.com/lodging/12000000/11610000/11603300/11603281/7077705b.jpg"),
        ],
        flights: MexicoFixtureCatalog.flights.map {
            Option(
                title: "\($0.origin) → \($0.destination)",
                detail: "$\($0.price) · \($0.stops) · \($0.duration) · \($0.airline)",
                price: "$\($0.price)",
                priceValue: $0.price,
                departTime: $0.departTime,
                arriveTime: $0.arriveTime,
                stops: $0.stops,
                duration: $0.duration,
                cabin: "Economy",
                tripType: "Round trip",
                airlines: [$0.airline],
                logoURLs: ["airline-ua"],
                highlights: $0.seatsTogether ? "Seats together · \($0.bagsIncluded) bags included" : nil
            )
        } + [
            flight("JFK → CUN", dep: "8:10 am", arr: "12:30 pm", "4h 20m", "Nonstop", cabin: "Economy", ["JetBlue"], 318),
            flight("JFK → CUN", dep: "6:00 am", arr: "10:15 am", "4h 15m", "Nonstop", cabin: "Economy, Comfort+", ["Delta"], 352),
            flight("JFK → CUN", dep: "7:35 am", arr: "2:25 pm", "6h 50m", "1 stop", cabin: "Economy", ["American", "Alaska"], 289),
            flight("IAH → CUN", dep: "9:20 am", arr: "11:55 am", "2h 35m", "Nonstop", cabin: "Economy", ["United"], 266),
            flight("IAH → CUN", dep: "6:45 am", arr: "9:25 am", "2h 40m", "Nonstop", cabin: "Economy", ["Spirit"], 198),
            flight("IAH → CUN", dep: "11:10 am", arr: "4:30 pm", "5h 20m", "1 stop", cabin: "Economy", ["American", "JetBlue"], 243),
        ],
        cars: cars,
        activities: MexicoFixtureCatalog.activities.map {
            Option(
                title: $0.name,
                detail: "$\($0.priceFrom) · \($0.duration)",
                price: "$\($0.priceFrom)",
                imageURL: $0.imageURL,
                priceValue: $0.priceFrom
            )
        } + [
            act("Snorkeling at MUSA Underwater Museum", 65, "3 hrs"),
            act("Isla Mujeres catamaran cruise", 89, "Full day"),
            act("Chichen Itza day trip", 120, "Full day"),
            act("Xcaret eco-park", 145, "Full day"),
            act("Cenote snorkeling tour", 75, "Half day"),
            act("Downtown food & margarita tour", 55, "3 hrs"),
        ]
    )

    // MARK: - Cabo San Lucas

    static let cabo = City(
        slug: "cabo", name: "Cabo San Lucas", airport: "SJD",
        hotels: [
            Hotel(name: "Riu Palace Cabo San Lucas All Inclusive", price: 520, stars: 5.0, area: "Corridor beachfront", image: "cabo-1"),
            Hotel(name: "Casa Dorada Los Cabos Resort & Spa", price: 480, stars: 5.0, area: "El Medano Beach", image: "cabo-2"),
            Hotel(name: "Villa del Arco Beach Resort & Spa", price: 460, stars: 5.0, area: "El Medano Beach", image: "cabo-3"),
            Hotel(name: "The Towers at Pueblo Bonito Pacifica", price: 540, stars: 5.0, area: "Pacific side", image: "https://mediaim.expedia.com/lodging/16000000/15620000/15615000/15614980/e1318c9f.jpg"),
            Hotel(name: "Grand Solmar at Rancho San Lucas Resort", price: 560, stars: 5.0, area: "Rancho San Lucas", image: "https://mediaim.expedia.com/lodging/19000000/18110000/18108100/18108018/4a0045da.jpg"),
            Hotel(name: "Montage Los Cabos", price: 850, stars: 4.5, area: "Santa Maria Bay", image: "https://mediaim.expedia.com/lodging/22000000/21570000/21565900/21565893/4a33d499.jpg"),
            Hotel(name: "El Encanto Inn & Suites", price: 172, stars: 3.0, area: "San José del Cabo", image: "https://mediaim.expedia.com/lodging/1000000/870000/860900/860816/b345be53.jpg"),
            Hotel(name: "City Express Plus Cabo San Lucas", price: 150, stars: 3.0, area: "El Tezal", image: "https://mediaim.expedia.com/lodging/12000000/11060000/11056300/11056260/bd6e452f.jpg"),
            Hotel(name: "Medano Hotel and Suites", price: 165, stars: 3.0, area: "El Medano Beach", image: "https://mediaim.expedia.com/lodging/17000000/16100000/16096600/16096531/52e9f86d.jpg"),
            Hotel(name: "Cabo Inn Hotel", price: 120, stars: 3.0, area: "Downtown Cabo", image: "https://mediaim.expedia.com/lodging/2000000/1540000/1532200/1532164/779391f0.jpg"),
        ],
        flights: [
            flight("JFK → SJD", dep: "6:30 am", arr: "2:40 pm", "8h 10m", "1 stop", cabin: "Economy", ["JetBlue", "Alaska"], 388),
            flight("JFK → SJD", dep: "8:15 am", arr: "4:55 pm", "8h 40m", "1 stop", cabin: "Economy, Premium", ["American", "Alaska"], 421),
            flight("JFK → SJD", dep: "9:40 am", arr: "6:45 pm", "9h 05m", "1 stop", cabin: "Economy", ["Alaska", "American"], 402),
            flight("IAH → SJD", dep: "10:05 am", arr: "12:50 pm", "3h 45m", "Nonstop", cabin: "Economy", ["United"], 312),
            flight("IAH → SJD", dep: "6:20 am", arr: "11:40 am", "6h 20m", "1 stop", cabin: "Economy", ["Southwest", "Spirit"], 286),
            flight("IAH → SJD", dep: "12:15 pm", arr: "6:45 pm", "7h 30m", "1 stop", cabin: "Economy", ["Alaska", "United"], 340),
        ],
        cars: cars,
        activities: [
            act("Sunset sailing cruise", 85, "3 hrs"),
            act("Snorkeling at Lover's Beach", 70, "Half day"),
            act("Whale watching tour", 95, "3 hrs"),
            act("ATV desert & beach ride", 110, "Half day"),
            act("Cabo Pulmo dive trip", 135, "Full day"),
            act("Marina & taco food tour", 60, "3 hrs"),
        ]
    )

    // MARK: - Puerto Vallarta

    static let puertoVallarta = City(
        slug: "pv", name: "Puerto Vallarta", airport: "PVR",
        hotels: [
            Hotel(name: "Garza Blanca Preserve Resort & Spa", price: 420, stars: 4.5, area: "South Shore", image: "pv-1"),
            Hotel(name: "The St. Regis Punta Mita Resort", price: 780, stars: 5.0, area: "Punta de Mita", image: "pv-2"),
            Hotel(name: "Sheraton Buganvilias Resort & Convention Center", price: 260, stars: 4.0, area: "Hotel Zone", image: "pv-3"),
            Hotel(name: "Krystal Puerto Vallarta", price: 113, stars: 4.0, area: "Zona Hotelera", image: "https://mediaim.expedia.com/lodging/1000000/20000/12000/11999/50f646c9.jpg"),
            Hotel(name: "Casa Kimberly", price: 390, stars: 4.5, area: "Gringo Gulch", image: "https://mediaim.expedia.com/lodging/15000000/14920000/14919200/14919137/08e670b8.jpg"),
            Hotel(name: "Casa Cúpula Luxury Boutique Hotel", price: 240, stars: 4.5, area: "Amapas", image: "https://mediaim.expedia.com/lodging/2000000/1630000/1622000/1621985/7a2db4c4.jpg"),
            Hotel(name: "Ocean Breeze Nuevo Vallarta", price: 150, stars: 3.5, area: "Nuevo Vallarta", image: "https://mediaim.expedia.com/lodging/3000000/2790000/2787200/2787178/2a5699f4.jpg"),
            Hotel(name: "Blue Chairs Resort by the Sea", price: 180, stars: 3.0, area: "Los Muertos Beach", image: "https://mediaim.expedia.com/lodging/2000000/1690000/1683700/1683671/4519c018.jpg"),
            Hotel(name: "Hotel Portonovo Plaza Malecón", price: 130, stars: 3.0, area: "Malecón", image: "https://mediaim.expedia.com/lodging/4000000/3450000/3441600/3441520/1090c169.jpg"),
            Hotel(name: "The Hacienda at Hilton Puerto Vallarta", price: 220, stars: 5.0, area: "Hotel Zone", image: "https://mediaim.expedia.com/lodging/25000000/24940000/24930700/24930665/dd9bb45d.jpg"),
        ],
        flights: [
            flight("JFK → PVR", dep: "6:45 am", arr: "3:45 pm", "9h 00m", "1 stop", cabin: "Economy", ["American", "Alaska"], 402),
            flight("JFK → PVR", dep: "8:00 am", arr: "5:30 pm", "9h 30m", "1 stop", cabin: "Economy, Premium", ["United", "Alaska"], 436),
            flight("JFK → PVR", dep: "7:20 am", arr: "5:20 pm", "10h 00m", "1 stop", cabin: "Economy", ["Delta", "Aeromexico"], 418),
            flight("IAH → PVR", dep: "9:50 am", arr: "11:55 am", "3h 05m", "Nonstop", cabin: "Economy", ["United"], 298),
            flight("IAH → PVR", dep: "6:30 am", arr: "12:30 pm", "6h 00m", "1 stop", cabin: "Economy", ["Aeromexico", "Delta"], 274),
            flight("IAH → PVR", dep: "11:25 am", arr: "5:25 pm", "7h 00m", "1 stop", cabin: "Economy", ["American", "Alaska"], 322),
        ],
        cars: cars,
        activities: [
            act("Marigalante pirate sunset cruise", 95, "5 hrs"),
            act("Yelapa & Majahuitas snorkel tour", 88, "Full day"),
            act("Sierra Madre canopy zipline", 115, "Half day"),
            act("Malecón art & food walking tour", 55, "3 hrs"),
            act("Whale watching tour", 90, "3 hrs"),
            act("Las Caletas beach day", 130, "Full day"),
        ]
    )

    // MARK: - Tulum (Tulum & Riviera Maya)

    static let tulum = City(
        slug: "tulum", name: "Tulum", airport: "TQO",
        hotels: [
            Hotel(name: "Ambassador at Grand Velas All Inclusive", price: 520, stars: 5.0, area: "Riviera Maya", image: "tulum-1"),
            Hotel(name: "Aldea Thai by Moskito", price: 260, stars: 4.5, area: "Riviera Maya", image: "tulum-2"),
            Hotel(name: "The Meridian by Bric", price: 240, stars: 4.5, area: "Riviera Maya", image: "tulum-3"),
            Hotel(name: "Hilton Playa del Carmen All-Inclusive Adult Resort", price: 430, stars: 5.0, area: "Playacar", image: "https://mediaim.expedia.com/lodging/2000000/1160000/1151600/1151540/e03f3ca2.jpg"),
            Hotel(name: "Magia Beachside by Bric", price: 250, stars: 4.0, area: "Riviera Maya", image: "https://mediaim.expedia.com/lodging/12000000/11540000/11539100/11539056/503f6224.jpg"),
            Hotel(name: "Bright, Airy Beachside Apartment", price: 145, stars: 4.0, area: "Puerto Morelos", image: "https://mediaim.expedia.com/lodging/22000000/21870000/21866100/21866014/8f39ebf0.jpg"),
            Hotel(name: "Casa Riviera Lol Tun", price: 99, stars: 3.5, area: "Riviera Maya", image: "https://mediaim.expedia.com/lodging/20000000/19490000/19488600/19488567/f1d353db.jpg"),
            Hotel(name: "Vainilla Bed & Breakfast", price: 130, stars: 3.0, area: "Riviera Maya", image: "https://mediaim.expedia.com/lodging/11000000/10930000/10923200/10923197/ece4d49a.jpg"),
            Hotel(name: "Poolside Balcony Apartment", price: 85, stars: 3.5, area: "Puerto Morelos", image: "https://mediaim.expedia.com/lodging/20000000/19970000/19960900/19960814/75ecae36.jpg"),
            Hotel(name: "The Royal Palms by Bric", price: 180, stars: 4.0, area: "Riviera Maya", image: "https://mediaim.expedia.com/lodging/12000000/11550000/11547700/11547656/38fae65b.jpg"),
        ],
        flights: [
            flight("JFK → TQO", dep: "8:25 am", arr: "12:55 pm", "4h 30m", "Nonstop", cabin: "Economy", ["JetBlue"], 342),
            flight("JFK → TQO", dep: "6:10 am", arr: "10:35 am", "4h 25m", "Nonstop", cabin: "Economy, Comfort+", ["Delta"], 368),
            flight("JFK → TQO", dep: "7:50 am", arr: "2:50 pm", "7h 00m", "1 stop", cabin: "Economy", ["Spirit", "JetBlue"], 268),
            flight("IAH → TQO", dep: "9:35 am", arr: "12:20 pm", "2h 45m", "Nonstop", cabin: "Economy", ["United"], 276),
            flight("IAH → TQO", dep: "6:55 am", arr: "9:45 am", "2h 50m", "Nonstop", cabin: "Economy", ["Spirit"], 212),
            flight("IAH → TQO", dep: "11:00 am", arr: "4:30 pm", "5h 30m", "1 stop", cabin: "Economy", ["American", "Alaska"], 254),
        ],
        cars: cars,
        activities: [
            act("Tulum Mayan ruins guided tour", 60, "Half day"),
            act("Gran Cenote snorkeling", 75, "Half day"),
            act("Sian Ka'an biosphere boat tour", 120, "Full day"),
            act("Beach club day pass", 85, "Full day"),
            act("Cobá ruins & cenote combo", 110, "Full day"),
            act("Tulum bike & taco tour", 50, "3 hrs"),
        ]
    )

    // MARK: - Playa del Carmen

    static let playaDelCarmen = City(
        slug: "playa", name: "Playa del Carmen", airport: "CUN",
        hotels: [
            Hotel(name: "Hilton Playa del Carmen All-Inclusive Adult Resort", price: 430, stars: 5.0, area: "Playacar", image: "playa-1"),
            Hotel(name: "Ambassador at Grand Velas All Inclusive", price: 520, stars: 5.0, area: "Riviera Maya", image: "playa-2"),
            Hotel(name: "Posada Mariposa Boutique Hotel", price: 190, stars: 4.0, area: "5th Avenue", image: "playa-3"),
            Hotel(name: "HM Playa del Carmen", price: 170, stars: 3.0, area: "Downtown", image: "https://mediaim.expedia.com/lodging/12000000/11520000/11517000/11516987/536076b5.jpg"),
            Hotel(name: "Aldea Thai by Moskito", price: 260, stars: 4.5, area: "Coco Beach", image: "https://mediaim.expedia.com/lodging/12000000/11690000/11688200/11688126/cd5e0abf.jpg"),
            Hotel(name: "Magia Beachside by Bric", price: 250, stars: 4.0, area: "North Beach", image: "https://mediaim.expedia.com/lodging/12000000/11540000/11539100/11539056/503f6224.jpg"),
            Hotel(name: "The Meridian by Bric", price: 240, stars: 4.5, area: "Coco Beach", image: "https://mediaim.expedia.com/lodging/12000000/11540000/11539100/11539068/e2fcf7e3.jpg"),
            Hotel(name: "Skyline 24th by Playa Paradise", price: 200, stars: 4.0, area: "Downtown", image: "https://mediaim.expedia.com/lodging/12000000/11270000/11267000/11266964/34184bb4.jpg"),
            Hotel(name: "Vainilla Bed & Breakfast", price: 130, stars: 3.0, area: "Downtown", image: "https://mediaim.expedia.com/lodging/11000000/10930000/10923200/10923197/ece4d49a.jpg"),
            Hotel(name: "The Royal Palms by Bric", price: 180, stars: 4.0, area: "5th Avenue", image: "https://mediaim.expedia.com/lodging/12000000/11550000/11547700/11547656/38fae65b.jpg"),
        ],
        flights: [
            flight("JFK → CUN", dep: "9:05 am", arr: "1:25 pm", "4h 20m", "Nonstop", cabin: "Economy", ["JetBlue"], 318),
            flight("JFK → CUN", dep: "6:30 am", arr: "10:45 am", "4h 15m", "Nonstop", cabin: "Economy, Comfort+", ["Delta"], 349),
            flight("JFK → CUN", dep: "7:15 am", arr: "1:55 pm", "6h 40m", "1 stop", cabin: "Economy", ["United", "JetBlue"], 305),
            flight("IAH → CUN", dep: "10:10 am", arr: "12:45 pm", "2h 35m", "Nonstop", cabin: "Economy", ["United"], 266),
            flight("IAH → CUN", dep: "8:00 am", arr: "10:40 am", "2h 40m", "Nonstop", cabin: "Economy", ["American"], 289),
            flight("IAH → CUN", dep: "6:35 am", arr: "12:25 pm", "5h 50m", "1 stop", cabin: "Economy", ["Spirit", "JetBlue"], 221),
        ],
        cars: cars,
        activities: [
            act("Cozumel snorkeling day trip", 95, "Full day"),
            act("Xplor adventure park", 150, "Full day"),
            act("5th Avenue food tour", 58, "3 hrs"),
            act("Rio Secreto underground river", 110, "Half day"),
            act("Cenote & cave diving", 130, "Half day"),
            act("Beach club catamaran party", 89, "5 hrs"),
        ]
    )

    static let mexico: [City] = [cancun, cabo, puertoVallarta, tulum, playaDelCarmen]

    // MARK: - Los Angeles

    static let losAngeles = City(
        slug: "la", name: "Los Angeles", airport: "LAX",
        hotels: [
            Hotel(name: "Millennium Biltmore Los Angeles", price: 329, stars: 4.0, area: "Downtown", image: "la-1"),
            Hotel(name: "Best Western Plus Sunset Plaza Hotel", price: 396, stars: 2.5, area: "West Hollywood", image: "la-2"),
            Hotel(name: "H Hotel Los Angeles, Curio Collection by Hilton", price: 240, stars: 3.0, area: "LAX", image: "la-3"),
            Hotel(name: "Homewood Suites by Hilton LAX", price: 316, stars: 3.0, area: "LAX", image: "https://mediaim.expedia.com/lodging/19000000/18960000/18952900/18952857/539c8fa1.jpg"),
            Hotel(name: "Ramada by Wyndham LA/Koreatown West", price: 222, stars: 2.5, area: "Koreatown", image: "https://mediaim.expedia.com/lodging/1000000/30000/25800/25793/c5e89aab.jpg"),
            Hotel(name: "DoubleTree by Hilton LA Rosemead", price: 761, stars: 4.0, area: "Rosemead", image: "https://mediaim.expedia.com/lodging/1000000/10000/2700/2630/35375b20.jpg"),
            Hotel(name: "SureStay Hotel Beverly Hills West LA", price: 237, stars: 2.5, area: "Beverly Blvd", image: "https://mediaim.expedia.com/lodging/1000000/290000/282300/282276/7c053be0.jpg"),
            Hotel(name: "Hilton Garden Inn LAX El Segundo", price: 196, stars: 3.0, area: "El Segundo", image: "https://mediaim.expedia.com/lodging/1000000/430000/424200/424167/4f76d4aa.jpg"),
            Hotel(name: "Foghorn Harbor Inn", price: 346, stars: 2.5, area: "Marina del Rey", image: "https://mediaim.expedia.com/lodging/3000000/2210000/2200100/2200019/0bffc34d.jpg"),
            Hotel(name: "Quality Inn & Suites Hermosa Beach", price: 206, stars: 2.5, area: "Hermosa Beach", image: "https://mediaim.expedia.com/lodging/1000000/20000/13700/13662/d3d8fe16.jpg"),
        ],
        flights: [
            flight("JFK → LAX", dep: "8:30 am", arr: "11:55 am", "6h 25m", "Nonstop", cabin: "Economy", ["JetBlue"], 324),
            flight("JFK → LAX", dep: "6:00 am", arr: "9:30 am", "6h 30m", "Nonstop", cabin: "Economy, Comfort+", ["Delta"], 358),
            flight("JFK → LAX", dep: "5:45 pm", arr: "9:05 pm", "6h 20m", "Nonstop", cabin: "Business, Economy", ["American"], 372),
            flight("IAH → LAX", dep: "9:15 am", arr: "11:10 am", "3h 55m", "Nonstop", cabin: "Economy", ["United"], 198),
            flight("IAH → LAX", dep: "6:40 am", arr: "8:45 am", "4h 05m", "Nonstop", cabin: "Economy", ["Spirit"], 156),
            flight("IAH → LAX", dep: "11:05 am", arr: "3:35 pm", "6h 30m", "1 stop", cabin: "Economy", ["Southwest", "Alaska"], 184),
        ],
        cars: cars,
        activities: [
            act("Warner Bros Studio Tour", 75, "3 hrs"),
            act("Universal Studios Hollywood", 135, "Full day"),
            act("Getty Center guided art walk", 25, "2 hrs"),
            act("Hollywood & Griffith Observatory tour", 69, "Half day"),
            act("Santa Monica & Venice bike tour", 55, "3 hrs"),
            act("Downtown LA food tour", 65, "3 hrs"),
        ]
    )

    // MARK: - Tampa

    static let tampa = City(
        slug: "tampa", name: "Tampa", airport: "TPA",
        hotels: [
            Hotel(name: "The Westin Tampa Waterside", price: 290, stars: 4.0, area: "Harbour Island", image: "tampa-1"),
            Hotel(name: "Tampa Airport Marriott", price: 210, stars: 4.0, area: "Airport", image: "tampa-2"),
            Hotel(name: "Wyndham Grand Clearwater Beach", price: 341, stars: 4.5, area: "Clearwater Beach", image: "tampa-3"),
            Hotel(name: "Home2 Suites by Hilton Brandon Tampa", price: 138, stars: 3.0, area: "Brandon", image: "https://mediaim.expedia.com/lodging/23000000/22940000/22935100/22935082/93e489dd.jpg"),
            Hotel(name: "Hampton Inn Tampa-Veterans Expwy", price: 114, stars: 2.5, area: "Airport North", image: "https://mediaim.expedia.com/lodging/1000000/580000/579200/579157/57e211d6.jpg"),
            Hotel(name: "Embassy Suites Tampa Downtown", price: 200, stars: 3.5, area: "Downtown", image: "https://mediaim.expedia.com/lodging/2000000/1410000/1407200/1407138/92ae60fc.jpg"),
            Hotel(name: "Courtyard by Marriott Tampa Downtown", price: 190, stars: 3.0, area: "Downtown", image: "https://mediaim.expedia.com/lodging/1000000/120000/116700/116643/d450ccda.jpg"),
            Hotel(name: "The Barrymore Hotel Tampa Riverwalk", price: 170, stars: 2.5, area: "Riverwalk", image: "https://mediaim.expedia.com/lodging/1000000/10000/2100/2040/4f49db4e.jpg"),
            Hotel(name: "Four Points by Sheraton Suites Tampa Airport", price: 160, stars: 3.0, area: "Westshore", image: "https://mediaim.expedia.com/lodging/1000000/20000/19400/19330/cba9d115.jpg"),
            Hotel(name: "Holiday Inn Express Rocky Point Island", price: 150, stars: 2.5, area: "Rocky Point", image: "https://mediaim.expedia.com/lodging/1000000/120000/116900/116834/2d1014fc.jpg"),
        ],
        flights: [
            flight("JFK → TPA", dep: "8:45 am", arr: "11:50 am", "3h 05m", "Nonstop", cabin: "Economy", ["JetBlue"], 178),
            flight("JFK → TPA", dep: "6:15 am", arr: "9:25 am", "3h 10m", "Nonstop", cabin: "Economy, Comfort+", ["Delta"], 204),
            flight("JFK → TPA", dep: "7:30 am", arr: "1:10 pm", "5h 40m", "1 stop", cabin: "Economy", ["American", "JetBlue"], 168),
            flight("HOU → TPA", dep: "9:40 am", arr: "1:00 pm", "2h 20m", "Nonstop", cabin: "Economy", ["United"], 214),
            flight("HOU → TPA", dep: "6:50 am", arr: "10:15 am", "2h 25m", "Nonstop", cabin: "Economy", ["Southwest"], 186),
            flight("HOU → TPA", dep: "11:20 am", arr: "5:30 pm", "5h 10m", "1 stop", cabin: "Economy", ["Spirit", "JetBlue"], 148),
        ],
        cars: cars,
        activities: [
            act("Busch Gardens theme park", 115, "Full day"),
            act("The Florida Aquarium", 40, "Half day"),
            act("Ybor City food & history tour", 60, "3 hrs"),
            act("Clearwater Beach dolphin cruise", 45, "2 hrs"),
            act("Monster Jam Freestyle Mania at Benchmark Arena", 45, "Evening"),
            act("Tampa Riverwalk & museum pass", 30, "Half day"),
        ]
    )
}
