import Foundation

struct LodgingAmenity: Codable, Sendable { var text: String; var icon: String? }
struct LodgingCardProps: Codable, Sendable {
    var id: String; var name: String; var location: String; var distance: String?
    var amenities: [LodgingAmenity]?; var imageUrl: String?
    var priceNightly: String?; var priceTotal: String?
    var reviewScore: Double?; var reviewCount: Double?
    var refundableLabel: String?; var refundableSublabel: String?; var highlight: String?
}
struct DestinationCardProps: Codable, Sendable {
    var name: String; var country: String?; var description: String?; var imageUrl: String?
    var highlights: [String]; var rationale: String?; var airportCode: String?
    var packageFrom: Double?; var currency: String?; var dataSource: String?
}
struct ActivityCardProps: Codable, Sendable {
    var id: String; var name: String; var description: String?; var highlights: [String]
    var imageUrl: String?; var price: Double?; var formattedPrice: String?; var currency: String?
    var reviewScore: Double?; var reviewCount: Double?; var dataSource: String?
}
struct FlightCardProps: Codable, Sendable {
    var id: String; var airline: String; var flightNumber: String
    var origin: String; var destination: String; var departureTime: String; var arrivalTime: String
    var durationMinutes: Int; var price: Double; var currency: String; var stops: Int
    var `class`: String; var totalPrice: Double?; var bagsIncluded: String?
    var priceBasis: String?; var dataSource: String?; var provisional: Bool?
}
struct Coordinates: Codable, Sendable { var lat: Double; var lng: Double }
struct MapPin: Codable, Sendable { var lat: Double; var lng: Double; var label: String; var id: String }
struct MapViewProps: Codable, Sendable { var center: Coordinates?; var zoom: Double?; var pins: [MapPin] }
struct ConstraintPill: Codable, Sendable {
    var field: String; var label: String; var type: String; var tier: String
}
struct ConstraintBarProps: Codable, Sendable {
    var primary: [ConstraintPill]; var secondary: [ConstraintPill]; var refinements: [String]
}
struct SectionHeadingProps: Codable, Sendable { var text: String; var level: Int? }
struct TextBlockProps: Codable, Sendable { var content: String }
struct ClarificationOption: Codable, Sendable { var label: String; var value: JSONValue }
struct ClarificationProps: Codable, Sendable {
    var field: String; var question: String; var reason: String; var required: Bool
    var suggestion: JSONValue?; var suggestionLabel: String?; var options: [ClarificationOption]?
}
struct ResultStateSummaryProps: Codable, Sendable {
    var headline: String; var status: String; var count: Int?; var detail: String?; var sourceLabel: String?
}
struct PackageSummaryProps: Codable, Sendable {
    var id: String; var area: String; var destination: String; var airportCodes: [String]
    var currency: String; var flightTotal: Double; var lodgingBudgetRemaining: Double?
    var packageFrom: Double; var fitCount: Int; var priceBasis: String
    var imageUrl: String?; var highlights: [String]?; var dataSource: String
    var title: String?; var rationale: String?; var departureDate: String?; var returnDate: String?
    var listPrice: Double?; var savings: Double?
}
struct ComparisonTableProps: Codable, Sendable {
    var headers: [String]; var rows: [[String: JSONValue]]; var title: String?
}
struct ExplainabilityNoteProps: Codable, Sendable { var content: String }
struct ValidationBlockProps: Codable, Sendable { var title: String }
struct CapabilityStateProps: Codable, Sendable {
    var product: String; var title: String; var message: String; var available: Bool; var fixture: Bool?
}

extension A2UIComponent {
    func flightProps() throws -> FlightCardProps { try typedProps() }
    func lodgingProps() throws -> LodgingCardProps { try typedProps() }
    func destinationProps() throws -> DestinationCardProps { try typedProps() }
    func activityProps() throws -> ActivityCardProps { try typedProps() }
    func mapProps() throws -> MapViewProps { try typedProps() }
    func constraintBarProps() throws -> ConstraintBarProps { try typedProps() }
    func clarificationProps() throws -> ClarificationProps { try typedProps() }
    func resultStateSummaryProps() throws -> ResultStateSummaryProps { try typedProps() }
    func packageSummaryProps() throws -> PackageSummaryProps { try typedProps() }
    func comparisonTableProps() throws -> ComparisonTableProps { try typedProps() }
    func explainabilityNoteProps() throws -> ExplainabilityNoteProps { try typedProps() }
    func validationBlockProps() throws -> ValidationBlockProps { try typedProps() }
    func capabilityStateProps() throws -> CapabilityStateProps { try typedProps() }
}
