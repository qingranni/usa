//
//  ChipComposerCatalog.swift
//  Universal Search App
//
//  Static data backing the inline-chip composer (ported from TravelAI's
//  MockData). Kept separate from the app's `Mock` message database so the two
//  mock systems don't collide. Feeds the natural-language `SearchInputParser`
//  (destination matching) and the composer's filter sheets / ghost menu.
//

import Foundation

/// A destination the parser can resolve typed text into, and the composer's
/// destination search / ghost menu can list.
struct DestinationSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let imageURL: String
}

enum ChipComposerCatalog {

    // MARK: - Filter chips per category

    /// Filter pills offered for each search category. The composer defaults to
    /// "Stays"; the others are here for parity with the source.
    static let quickActionFilterChips: [String: [String]] = [
        "Stays": ["Destination", "Dates", "Guests"],
        "Flights": ["From", "To", "Dates", "Travelers"],
        "Packages": ["Destination", "Dates", "Guests"],
        "Cars": ["Pick-up", "Drop-off", "Dates"],
        "Activities": ["Destination", "Dates", "Guests"],
    ]

    // MARK: - Destination image pool

    private static let cityImagePool: [String] = [
        "https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=120&q=80",
        "https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=120&q=80",
        "https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=120&q=80",
        "https://images.unsplash.com/photo-1583422409516-2895a77efded?w=120&q=80",
        "https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=120&q=80",
        "https://images.unsplash.com/photo-1585208798174-6cedd86e019a?w=120&q=80",
        "https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=120&q=80",
        "https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=120&q=80",
        "https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=120&q=80",
        "https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=120&q=80",
        "https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=120&q=80",
        "https://images.unsplash.com/photo-1613395877344-13d4a8e0d49e?w=120&q=80",
        "https://images.unsplash.com/photo-1597211833712-5e41faa202ea?w=120&q=80",
        "https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=120&q=80",
        "https://images.unsplash.com/photo-1516550893923-42d28e5677af?w=120&q=80",
        "https://images.unsplash.com/photo-1580060839134-75a5edca2e99?w=120&q=80",
        "https://images.unsplash.com/photo-1502175353174-a7a70e73b4c3?w=120&q=80",
        "https://images.unsplash.com/photo-1474044159687-1ee9f3a51722?w=120&q=80",
        "https://images.unsplash.com/photo-1527333656061-ce7e8a2538e1?w=120&q=80",
        "https://images.unsplash.com/photo-1605999239618-9a782f36ef22?w=120&q=80",
        "https://images.unsplash.com/photo-1502680390548-bdbac40cef78?w=120&q=80",
        "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=120&q=80",
        "https://images.unsplash.com/photo-1519046904884-53103b34b206?w=120&q=80",
        "https://images.unsplash.com/photo-1473116763249-2faaef81ccda?w=120&q=80",
        "https://images.unsplash.com/photo-1455729552457-5c322b382999?w=120&q=80",
        "https://images.unsplash.com/photo-1505228395891-9a51e7e86bf6?w=120&q=80",
        "https://images.unsplash.com/photo-1533106497176-45ae19e68ba2?w=120&q=80",
        "https://images.unsplash.com/photo-1510097467424-192d713fd8b2?w=120&q=80",
        "https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=120&q=80",
    ]

    private static let airportImageURL = "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=120&q=80"

    private static func img(_ index: Int) -> String {
        cityImagePool[index % cityImagePool.count]
    }

    // MARK: - Destination suggestions

    static let destinationSuggestions: [DestinationSuggestion] = [
        // Top global cities
        DestinationSuggestion(name: "Paris, France", subtitle: "Popular", imageURL: img(0)),
        DestinationSuggestion(name: "London, England", subtitle: "Recent", imageURL: img(1)),
        DestinationSuggestion(name: "Tokyo, Japan", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "New York, New York", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Dubai, UAE", subtitle: "Trending", imageURL: img(7)),
        DestinationSuggestion(name: "Bangkok, Thailand", subtitle: "Trending", imageURL: img(9)),
        DestinationSuggestion(name: "Singapore", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "Istanbul, Turkey", subtitle: "Trending", imageURL: img(15)),
        DestinationSuggestion(name: "Hong Kong", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Seoul, South Korea", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "Kuala Lumpur, Malaysia", subtitle: "Trending", imageURL: img(9)),
        DestinationSuggestion(name: "Mexico City, Mexico", subtitle: "Popular", imageURL: img(26)),
        DestinationSuggestion(name: "Buenos Aires, Argentina", subtitle: "Trending", imageURL: img(4)),
        DestinationSuggestion(name: "Rio de Janeiro, Brazil", subtitle: "Trending", imageURL: img(26)),
        DestinationSuggestion(name: "São Paulo, Brazil", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Johannesburg, South Africa", subtitle: "Popular", imageURL: img(15)),
        DestinationSuggestion(name: "Cairo, Egypt", subtitle: "Trending", imageURL: img(12)),
        DestinationSuggestion(name: "Mumbai, India", subtitle: "Trending", imageURL: img(9)),
        DestinationSuggestion(name: "Delhi, India", subtitle: "Popular", imageURL: img(9)),
        DestinationSuggestion(name: "Shanghai, China", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "Beijing, China", subtitle: "Popular", imageURL: img(2)),
        DestinationSuggestion(name: "Taipei, Taiwan", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "Ho Chi Minh City, Vietnam", subtitle: "Trending", imageURL: img(9)),
        DestinationSuggestion(name: "Jakarta, Indonesia", subtitle: "Popular", imageURL: img(28)),
        DestinationSuggestion(name: "Manila, Philippines", subtitle: "Popular", imageURL: img(28)),

        // European leisure
        DestinationSuggestion(name: "Barcelona, Spain", subtitle: "Popular", imageURL: img(3)),
        DestinationSuggestion(name: "Madrid, Spain", subtitle: "Popular", imageURL: img(3)),
        DestinationSuggestion(name: "Seville, Spain", subtitle: "Popular", imageURL: img(3)),
        DestinationSuggestion(name: "Valencia, Spain", subtitle: "Popular", imageURL: img(3)),
        DestinationSuggestion(name: "Ibiza, Spain", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Mallorca, Spain", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Lisbon, Portugal", subtitle: "Trending", imageURL: img(5)),
        DestinationSuggestion(name: "Porto, Portugal", subtitle: "Popular", imageURL: img(5)),
        DestinationSuggestion(name: "Rome, Italy", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Florence, Italy", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Venice, Italy", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Milan, Italy", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Naples, Italy", subtitle: "Popular", imageURL: img(4)),
        DestinationSuggestion(name: "Amalfi Coast, Italy", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Berlin, Germany", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Munich, Germany", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Athens, Greece", subtitle: "Popular", imageURL: img(11)),
        DestinationSuggestion(name: "Santorini, Greece", subtitle: "Popular", imageURL: img(11)),
        DestinationSuggestion(name: "Mykonos, Greece", subtitle: "Trending", imageURL: img(11)),
        DestinationSuggestion(name: "Crete, Greece", subtitle: "Popular", imageURL: img(11)),
        DestinationSuggestion(name: "Amsterdam, Netherlands", subtitle: "Popular", imageURL: img(6)),
        DestinationSuggestion(name: "Copenhagen, Denmark", subtitle: "Trending", imageURL: img(14)),
        DestinationSuggestion(name: "Stockholm, Sweden", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Oslo, Norway", subtitle: "Trending", imageURL: img(14)),
        DestinationSuggestion(name: "Helsinki, Finland", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Reykjavik, Iceland", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Edinburgh, Scotland", subtitle: "Popular", imageURL: img(1)),
        DestinationSuggestion(name: "Dublin, Ireland", subtitle: "Popular", imageURL: img(1)),
        DestinationSuggestion(name: "Budapest, Hungary", subtitle: "Trending", imageURL: img(13)),
        DestinationSuggestion(name: "Prague, Czech Republic", subtitle: "Popular", imageURL: img(13)),
        DestinationSuggestion(name: "Warsaw, Poland", subtitle: "Popular", imageURL: img(13)),
        DestinationSuggestion(name: "Krakow, Poland", subtitle: "Popular", imageURL: img(13)),
        DestinationSuggestion(name: "Vienna, Austria", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Zurich, Switzerland", subtitle: "Popular", imageURL: img(17)),
        DestinationSuggestion(name: "Geneva, Switzerland", subtitle: "Popular", imageURL: img(17)),
        DestinationSuggestion(name: "Interlaken, Switzerland", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Brussels, Belgium", subtitle: "Popular", imageURL: img(14)),
        DestinationSuggestion(name: "Bruges, Belgium", subtitle: "Popular", imageURL: img(14)),

        // Beach / island
        DestinationSuggestion(name: "Maui, Hawaii", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Oahu, Hawaii", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Kauai, Hawaii", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Honolulu, Hawaii", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Phuket, Thailand", subtitle: "Trending", imageURL: img(22)),
        DestinationSuggestion(name: "Koh Samui, Thailand", subtitle: "Popular", imageURL: img(22)),
        DestinationSuggestion(name: "Bali, Indonesia", subtitle: "Trending", imageURL: img(28)),
        DestinationSuggestion(name: "Maldives", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Mauritius", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Seychelles", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Fiji", subtitle: "Popular", imageURL: img(22)),
        DestinationSuggestion(name: "Bora Bora, French Polynesia", subtitle: "Trending", imageURL: img(21)),
        DestinationSuggestion(name: "Turks and Caicos", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "Aruba", subtitle: "Popular", imageURL: img(23)),
        DestinationSuggestion(name: "Barbados", subtitle: "Popular", imageURL: img(23)),
        DestinationSuggestion(name: "St. Lucia", subtitle: "Trending", imageURL: img(23)),
        DestinationSuggestion(name: "Tulum, Mexico", subtitle: "Trending", imageURL: img(27)),
        DestinationSuggestion(name: "Cabo San Lucas, Mexico", subtitle: "Popular", imageURL: img(27)),
        DestinationSuggestion(name: "Cancun, Mexico", subtitle: "Popular", imageURL: img(27)),
        DestinationSuggestion(name: "Zanzibar, Tanzania", subtitle: "Trending", imageURL: img(22)),

        // Adventure / nature
        DestinationSuggestion(name: "Queenstown, New Zealand", subtitle: "Trending", imageURL: img(18)),
        DestinationSuggestion(name: "Banff, Canada", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Whistler, Canada", subtitle: "Popular", imageURL: img(17)),
        DestinationSuggestion(name: "Patagonia, Argentina", subtitle: "Trending", imageURL: img(18)),
        DestinationSuggestion(name: "Torres del Paine, Chile", subtitle: "Trending", imageURL: img(18)),
        DestinationSuggestion(name: "Galapagos Islands, Ecuador", subtitle: "Trending", imageURL: img(28)),
        DestinationSuggestion(name: "Machu Picchu, Peru", subtitle: "Trending", imageURL: img(18)),
        DestinationSuggestion(name: "Cusco, Peru", subtitle: "Popular", imageURL: img(18)),
        DestinationSuggestion(name: "Serengeti, Tanzania", subtitle: "Trending", imageURL: img(15)),
        DestinationSuggestion(name: "Kruger National Park, South Africa", subtitle: "Trending", imageURL: img(15)),
        DestinationSuggestion(name: "Kilimanjaro, Tanzania", subtitle: "Trending", imageURL: img(18)),
        DestinationSuggestion(name: "Kyoto, Japan", subtitle: "Trending", imageURL: img(2)),
        DestinationSuggestion(name: "Osaka, Japan", subtitle: "Popular", imageURL: img(2)),
        DestinationSuggestion(name: "Hokkaido, Japan", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Marrakech, Morocco", subtitle: "Trending", imageURL: img(12)),
        DestinationSuggestion(name: "Cape Town, South Africa", subtitle: "Trending", imageURL: img(15)),

        // U.S. cities
        DestinationSuggestion(name: "Los Angeles, California", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "San Diego, California", subtitle: "Popular", imageURL: img(21)),
        DestinationSuggestion(name: "San Francisco, California", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Las Vegas, Nevada", subtitle: "Popular", imageURL: img(7)),
        DestinationSuggestion(name: "Chicago, Illinois", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Boston, Massachusetts", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Washington, DC", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Denver, Colorado", subtitle: "Popular", imageURL: img(17)),
        DestinationSuggestion(name: "Austin, Texas", subtitle: "Trending", imageURL: img(8)),
        DestinationSuggestion(name: "Nashville, Tennessee", subtitle: "Trending", imageURL: img(8)),
        DestinationSuggestion(name: "New Orleans, Louisiana", subtitle: "Popular", imageURL: img(8)),
        DestinationSuggestion(name: "Portland, Oregon", subtitle: "Popular", imageURL: img(16)),
        DestinationSuggestion(name: "Seattle, Washington", subtitle: "Recent", imageURL: img(16)),
        DestinationSuggestion(name: "Anchorage, Alaska", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Orlando, Florida", subtitle: "Popular", imageURL: img(26)),
        DestinationSuggestion(name: "Miami, Florida", subtitle: "Popular", imageURL: img(26)),
        DestinationSuggestion(name: "Charleston, South Carolina", subtitle: "Trending", imageURL: img(8)),
        DestinationSuggestion(name: "Savannah, Georgia", subtitle: "Trending", imageURL: img(8)),
        DestinationSuggestion(name: "Asheville, North Carolina", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Jackson Hole, Wyoming", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Aspen, Colorado", subtitle: "Trending", imageURL: img(17)),
        DestinationSuggestion(name: "Park City, Utah", subtitle: "Trending", imageURL: img(19)),
        DestinationSuggestion(name: "Zion National Park, Utah", subtitle: "Trending", imageURL: img(17)),

        // Ambiguity / same-name cities
        DestinationSuggestion(name: "Cambridge, Massachusetts", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Cambridge, England", subtitle: "UK", imageURL: img(1)),
        DestinationSuggestion(name: "Portland, Maine", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Springfield, Illinois", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Springfield, Missouri", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Venice, California", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Naples, Florida", subtitle: "USA", imageURL: img(26)),
        DestinationSuggestion(name: "Athens, Georgia", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "London, Ontario, Canada", subtitle: "Canada", imageURL: img(1)),
        DestinationSuggestion(name: "Paris, Texas", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Rome, Georgia", subtitle: "USA", imageURL: img(8)),
        DestinationSuggestion(name: "Miami, Ohio", subtitle: "USA", imageURL: img(8)),

        // Multi-airport groupings
        DestinationSuggestion(name: "London Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "New York Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Paris Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Tokyo Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Bay Area Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Los Angeles Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Milan Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
        DestinationSuggestion(name: "Moscow Airports", subtitle: "Multi-airport", imageURL: airportImageURL),
    ]
}
