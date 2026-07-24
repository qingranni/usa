import Foundation

enum ConstraintStrength: String, Codable, Sendable { case hard, soft }
enum GoalType: String, Codable, Sendable { case find, explore, compare }
enum ProductType: String, Codable, Sendable { case lodging, flight, activities }
enum ProductRelationship: String, Codable, Sendable { case single, package, sequence }
enum IntentLevel: String, Codable, Sendable {
    case high, nearComplete = "near-complete", structuredFuzzy = "structured-fuzzy"
    case semiFuzzy = "semi-fuzzy", open, fullyOpen = "fully-open"
}
enum JourneyStage: String, Codable, Sendable { case inspire, orient, decide, commit }
enum EmotionalRegister: String, Codable, Sendable { case warm, neutral, flat }
enum AttributeActionType: String, Codable, Sendable {
    case askBlocking = "ask-blocking", askConversational = "ask-conversational"
    case infer, confirm, skip
}

struct Constraint<Value: Codable & Sendable>: Codable, Sendable {
    var field: String
    var value: Value
    var strength: ConstraintStrength
    var source: String
    var confidence: Double
    var timestamp: Double
}

struct ProductScope: Codable, Sendable {
    var primary: ProductType?
    var included: [ProductType]
    var relationship: ProductRelationship
    var confidence: Double
}

struct SearchIntent: Codable, Sendable {
    var destinations: Constraint<[String]>
}

struct AttributeAction: Codable, Sendable {
    var type: AttributeActionType
    var field: String
    var suggestion: JSONValue?
    var reason: String?
}

struct IntentEnvelope: Codable, Sendable {
    var goal: GoalType
    var products: ProductScope
    var completeness: IntentLevel
    var stage: JourneyStage
    var register: EmotionalRegister
    var intent: SearchIntent
    var actions: [AttributeAction]
}

enum IntentEventType: String, Codable, Sendable {
    case query, inference, uiSelection = "ui-selection", refinement, retraction
    case conflictDetected = "conflict-detected", conflictResolved = "conflict-resolved"
    case suggestion, systemDefault = "system-default"
}
enum IntentEventSource: String, Codable, Sendable { case user, agent, system }

struct IntentEvent: Codable, Sendable {
    var id: String
    var type: IntentEventType
    var timestamp: Double
    var field: String?
    var previousValue: JSONValue?
    var newValue: JSONValue?
    var strength: ConstraintStrength?
    var source: IntentEventSource
    var confidence: Double?
    var rawInput: String?
    var provenance: String?

    init(
        id: String,
        type: IntentEventType,
        timestamp: Double,
        field: String? = nil,
        previousValue: JSONValue? = nil,
        newValue: JSONValue? = nil,
        strength: ConstraintStrength? = nil,
        source: IntentEventSource,
        confidence: Double? = nil,
        rawInput: String? = nil,
        provenance: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.field = field
        self.previousValue = previousValue
        self.newValue = newValue
        self.strength = strength
        self.source = source
        self.confidence = confidence
        self.rawInput = rawInput
        self.provenance = provenance
    }
}
