import Foundation

/// Canonical Mexico entities shared by the broad mock query engine and the
/// Figma narrative overlay. Narrative-specific ordering and copy live in
/// `NarrativeData`; this catalog owns product identity and relationships.
enum MexicoFixtureCatalog {
    struct Destination: Identifiable, Hashable {
        let id: String
        let name: String
        let airportCode: String
        let imageURL: String
        let packageFrom: Int
        let narrativeSummary: String
    }

    struct Hotel: Identifiable, Hashable {
        let id: String
        let name: String
        let destinationID: String
        let nightlyPrice: Int
        let stars: Double
        let rating: Double
        let reviewCount: Int
        let area: String
        let imageURL: String
        let highlights: [String]
    }

    struct Flight: Identifiable, Hashable {
        let id: String
        let origin: String
        let destination: String
        let departTime: String
        let arriveTime: String
        let duration: String
        let stops: String
        let airline: String
        let price: Int
        let seatsTogether: Bool
        let bagsIncluded: Int
    }

    struct Activity: Identifiable, Hashable {
        let id: String
        let destinationID: String
        let name: String
        let priceFrom: Int
        let duration: String
        let imageURL: String
    }

    struct Room: Identifiable, Hashable {
        let id: String
        let hotelID: String
        let name: String
        let nightlyPrice: Int
        let sleeps: Int
        let bedSummary: String
        let connected: Bool
    }

    struct Package: Identifiable, Hashable {
        let id: String
        let destinationID: String
        let hotelID: String
        let flightID: String
        let roomIDs: [String]
        let activityIDs: [String]
        let title: String
        let dateRange: String
        let totalPrice: Int
        let crossedOutPrice: Int?
        let discount: Int?
        let imageURL: String
        let summary: String
    }

    struct ReviewInsight: Identifiable, Hashable {
        let id: String
        let hotelID: String
        let title: String
        let detail: String
    }

    struct AddOn: Identifiable, Hashable {
        let id: String
        let packageID: String
        let title: String
        let price: Int
        let selected: Bool
    }

    static let destinations: [Destination] = [
        Destination(
            id: "destination-cancun",
            name: "Cancun",
            airportCode: "CUN",
            imageURL: "cancun-1",
            packageFrom: 4_850,
            narrativeSummary: "The most teen-friendly activities in budget, with an energetic nightlife scene."
        ),
        Destination(
            id: "destination-puerto-vallarta",
            name: "Puerto Vallarta",
            airportCode: "PVR",
            imageURL: "pv-1",
            packageFrom: 4_780,
            narrativeSummary: "A laid-back beach town with family-friendly dining and a calmer pace."
        ),
        Destination(
            id: "destination-playa-del-carmen",
            name: "Playa del Carmen",
            airportCode: "CUN",
            imageURL: "playa-1",
            packageFrom: 4_720,
            narrativeSummary: "Walkable beaches, activities, and shopping with easy access to Riviera Maya."
        ),
    ]

    static let hotels: [Hotel] = [
        Hotel(
            id: "hotel-ocean-dream",
            name: "Ocean Dream Cancun by GuruHotel",
            destinationID: "destination-cancun",
            nightlyPrice: 215,
            stars: 4,
            rating: 8.8,
            reviewCount: 1_058,
            area: "Zona Hotelera beachfront",
            imageURL: "package-cancun-ocean-dream",
            highlights: ["Beachfront", "Teen pool and waterslide", "3 restaurants"]
        ),
        Hotel(
            id: "hotel-hyatt-ziva",
            name: "Hyatt Ziva Cancun",
            destinationID: "destination-cancun",
            nightlyPrice: 250,
            stars: 5,
            rating: 9.2,
            reviewCount: 3_560,
            area: "Punta Cancun beachfront",
            imageURL: "package-cancun-hyatt-ziva",
            highlights: ["All-inclusive", "Teen club", "Waterslide", "Separate living area"]
        ),
        Hotel(
            id: "hotel-dreams-sands",
            name: "Dreams Sands Cancun Resort & Spa",
            destinationID: "destination-cancun",
            nightlyPrice: 230,
            stars: 4.5,
            rating: 9.0,
            reviewCount: 2_184,
            area: "Zona Hotelera beachfront",
            imageURL: "package-cancun-dreams-sands",
            highlights: ["Beachfront", "Family suites", "Kids and teens club", "Spa"]
        ),
        Hotel(
            id: "hotel-hard-rock",
            name: "Hard Rock Hotel Cancun - All Inclusive",
            destinationID: "destination-cancun",
            nightlyPrice: 274,
            stars: 5,
            rating: 8.6,
            reviewCount: 1_944,
            area: "Zona Hotelera beachfront",
            imageURL: "package-cancun-hard-rock",
            highlights: ["All-inclusive", "Music Lab", "Teen activities", "Multiple pools"]
        ),
        Hotel(
            id: "hotel-waldorf-riviera-maya",
            name: "Waldorf Astoria Riviera Maya",
            destinationID: "destination-cancun",
            nightlyPrice: 420,
            stars: 5,
            rating: 9.4,
            reviewCount: 486,
            area: "Riviera Maya beachfront",
            imageURL: "package-cancun-waldorf",
            highlights: ["Beachfront", "Family suites", "Five pools", "Kids club"]
        ),
    ]

    static let flights: [Flight] = [
        Flight(
            id: "flight-hou-cun-united",
            origin: "HOU",
            destination: "CUN",
            departTime: "8:10 am",
            arriveTime: "1:40 pm",
            duration: "5h 30m",
            stops: "Nonstop",
            airline: "United",
            price: 230,
            seatsTogether: true,
            bagsIncluded: 3
        ),
        Flight(
            id: "flight-iah-cun-spirit",
            origin: "IAH",
            destination: "CUN",
            departTime: "9:25 am",
            arriveTime: "11:45 am",
            duration: "2h 20m",
            stops: "Nonstop",
            airline: "Spirit",
            price: 205,
            seatsTogether: true,
            bagsIncluded: 1
        ),
    ]

    static let activities: [Activity] = [
        Activity(
            id: "activity-snorkeling",
            destinationID: "destination-cancun",
            name: "Snorkeling",
            priceFrom: 30,
            duration: "3 hrs",
            imageURL: "activity-cancun"
        ),
        Activity(
            id: "activity-water-park",
            destinationID: "destination-cancun",
            name: "Water park day",
            priceFrom: 95,
            duration: "Full day",
            imageURL: "activity-mexico"
        ),
        Activity(
            id: "activity-isla-mujeres",
            destinationID: "destination-cancun",
            name: "Isla Mujeres catamaran",
            priceFrom: 89,
            duration: "Full day",
            imageURL: "activity-cancun"
        ),
    ]

    static let rooms: [Room] = [
        Room(
            id: "room-hyatt-family",
            hotelID: "hotel-hyatt-ziva",
            name: "Family suite",
            nightlyPrice: 250,
            sleeps: 4,
            bedSummary: "1 king bed + sofa bed",
            connected: true
        ),
        Room(
            id: "room-hyatt-double",
            hotelID: "hotel-hyatt-ziva",
            name: "Oceanfront double",
            nightlyPrice: 215,
            sleeps: 4,
            bedSummary: "2 double beds",
            connected: true
        ),
    ]

    static let packages: [Package] = [
        Package(
            id: "package-ocean-dream",
            destinationID: "destination-cancun",
            hotelID: "hotel-ocean-dream",
            flightID: "flight-hou-cun-united",
            roomIDs: [],
            activityIDs: ["activity-snorkeling"],
            title: "Ocean Dream Cancun + Flights",
            dateRange: "Mar 14–20",
            totalPrice: 4_720,
            crossedOutPrice: 5_058,
            discount: 274,
            imageURL: "package-cancun-ocean-dream",
            summary: "Beachfront all-inclusive, teen pool and waterslide, 3 restaurants. Teens have their own space."
        ),
        Package(
            id: "package-hyatt-ziva",
            destinationID: "destination-cancun",
            hotelID: "hotel-hyatt-ziva",
            flightID: "flight-hou-cun-united",
            roomIDs: ["room-hyatt-family", "room-hyatt-double"],
            activityIDs: ["activity-snorkeling", "activity-water-park", "activity-isla-mujeres"],
            title: "Hyatt Ziva Cancun + Flight",
            dateRange: "Mar 15–21",
            totalPrice: 4_720,
            crossedOutPrice: 5_058,
            discount: 274,
            imageURL: "package-cancun-hyatt-ziva",
            summary: "Beachfront, separate living area, teens club, spa, and nonstop flights with seats together."
        ),
        Package(
            id: "package-dreams-sands",
            destinationID: "destination-cancun",
            hotelID: "hotel-dreams-sands",
            flightID: "flight-hou-cun-united",
            roomIDs: [],
            activityIDs: ["activity-snorkeling", "activity-water-park"],
            title: "Dreams Sands Cancun Resort & Spa + Flights",
            dateRange: "Mar 15–22",
            totalPrice: 4_720,
            crossedOutPrice: 5_058,
            discount: 274,
            imageURL: "package-cancun-dreams-sands",
            summary: "Beachfront all-inclusive with family suites, teen activities, and three restaurants."
        ),
        Package(
            id: "package-hard-rock",
            destinationID: "destination-cancun",
            hotelID: "hotel-hard-rock",
            flightID: "flight-hou-cun-united",
            roomIDs: [],
            activityIDs: ["activity-water-park"],
            title: "Hard Rock Hotel Cancun + Flights",
            dateRange: "Mar 14–20",
            totalPrice: 4_720,
            crossedOutPrice: nil,
            discount: nil,
            imageURL: "package-cancun-hard-rock",
            summary: "Beachfront all-inclusive with music, pools, and dedicated activities for teens."
        ),
    ]

    static let reviewInsights: [ReviewInsight] = [
        ReviewInsight(
            id: "review-family-rooms",
            hotelID: "hotel-hyatt-ziva",
            title: "Spacious family rooms",
            detail: "Extra space for everyone to relax after a day at the beach."
        ),
        ReviewInsight(
            id: "review-arcade",
            hotelID: "hotel-hyatt-ziva",
            title: "Arcade room for teens",
            detail: "Teens can play in the arcade room while adults relax."
        ),
        ReviewInsight(
            id: "review-insider-tip",
            hotelID: "hotel-hyatt-ziva",
            title: "Insider tip",
            detail: "Pool area can get loud at night. Request a room on the quiet side if your teens are early sleepers."
        ),
    ]

    static let addOns: [AddOn] = [
        AddOn(
            id: "addon-airport-transfer",
            packageID: "package-hyatt-ziva",
            title: "Round-trip airport transfer",
            price: 84,
            selected: false
        ),
    ]

    static func destination(id: String) -> Destination? {
        destinations.first { $0.id == id }
    }

    static func hotel(id: String) -> Hotel? {
        hotels.first { $0.id == id }
    }

    static func flight(id: String) -> Flight? {
        flights.first { $0.id == id }
    }
}
