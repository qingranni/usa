import Foundation

enum SearchRouteLean: String, Codable, Sendable {
    case itinerary
    case results
}

struct SearchRouteSpec: Codable, Sendable {
    /// 0 is itinerary-building; 1 is direct result viewing.
    var score: Double
    var lean: SearchRouteLean
}

enum DataRequirementLevel: String, Codable, Sendable {
    case required
    case optional
}

struct DataRequirementSpec: Codable, Sendable {
    var field: String
    var level: DataRequirementLevel
    var isPresent: Bool
    var capturePrompt: String?
}

enum PageConstructKind: String, Codable, Sendable {
    case mapOverlaySheet = "map-overlay-sheet"
    case listOnly = "list-only"
}

struct PageConstructSpec: Codable, Sendable {
    var kind: PageConstructKind
    var loadMap: Bool
    var showFilters: Bool
    var overlaySheet: Bool
}

enum NarrativeRole: String, Codable, Sendable, CaseIterable {
    case topMatch = "top-match"
    case closeAlternative = "close-alternative"
    case furtherAlternative = "further-alternative"
    case wildCard = "wild-card"
    case rest
}

enum SectionComponentType: String, Codable, Sendable {
    case highlight
    case list
    case carousel
}

struct PageSectionCopy: Codable, Sendable {
    var heading: String
    var subheading: String
}

struct GeneratedPageSection: Codable, Sendable, Identifiable {
    var id: String
    var role: NarrativeRole
    var component: SectionComponentType
    var copy: PageSectionCopy
    var items: [A2UIComponent]
}

struct GeneratedPageSpec: Codable, Sendable {
    var route: SearchRouteSpec
    var requirements: [DataRequirementSpec]
    var construct: PageConstructSpec
    var sections: [GeneratedPageSection]
}
