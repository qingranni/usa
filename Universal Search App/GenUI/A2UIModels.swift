import Foundation

struct A2UIComponent: Codable, Sendable, Identifiable {
    var id: String
    var type: String
    var props: [String: JSONValue]
    var children: [A2UIComponent]?

    init(
        id: String,
        type: String,
        props: [String: JSONValue] = [:],
        children: [A2UIComponent]? = nil
    ) {
        self.id = id
        self.type = type
        self.props = props
        self.children = children
    }

    func typedProps<Props: Decodable>(
        as type: Props.Type = Props.self,
        using decoder: JSONDecoder = JSONDecoder()
    ) throws -> Props {
        try JSONValue.object(props).decode(type, using: decoder)
    }
}

struct SurfaceState: Codable, Sendable {
    var components: [A2UIComponent]
    var dataModel: [String: JSONValue]

    init(components: [A2UIComponent] = [], dataModel: [String: JSONValue] = [:]) {
        self.components = components
        self.dataModel = dataModel
    }
}

enum TemplateType: String, Codable, Sendable {
    case lodgingSearch = "lodging-search", destinationExplore = "destination-explore"
    case flightsSearch = "flights-search", activitiesSearch = "activities-search", mixed
    case lodgingList = "lodging-list", lodgingGroups = "lodging-groups"
    case flightList = "flight-list", destinationCarousel = "destination-carousel"
    case packageOverview = "package-overview", comparisonTable = "comparison-table"
    case mixedResults = "mixed-results", clarification
}

enum AgentPhase: String, Codable, Sendable { case intent, search }

struct AgentState: Codable, Sendable {
    var surfaces: [String: SurfaceState] = [:]
    var pageSpec: GeneratedPageSpec?
    var intent: SearchIntent?
    var intentEnvelope: IntentEnvelope?
    var intentEvents: [IntentEvent] = []
    var suggestions: [String] = []
    var sessionId: String?
    var template: TemplateType?
    var querySummary: String?
    var phase: AgentPhase?

    init(
        surfaces: [String: SurfaceState] = [:],
        pageSpec: GeneratedPageSpec? = nil,
        intent: SearchIntent? = nil,
        intentEnvelope: IntentEnvelope? = nil,
        intentEvents: [IntentEvent] = [],
        suggestions: [String] = [],
        sessionId: String? = nil,
        template: TemplateType? = nil,
        querySummary: String? = nil,
        phase: AgentPhase? = nil
    ) {
        self.surfaces = surfaces
        self.pageSpec = pageSpec
        self.intent = intent
        self.intentEnvelope = intentEnvelope
        self.intentEvents = intentEvents
        self.suggestions = suggestions
        self.sessionId = sessionId
        self.template = template
        self.querySummary = querySummary
        self.phase = phase
    }
}
