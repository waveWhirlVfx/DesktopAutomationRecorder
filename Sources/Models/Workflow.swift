import Foundation

// MARK: - Workflow

struct Workflow: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String = ""
    var createdAt: Date = Date()
    var lastModified: Date = Date()
    var steps: [WorkflowStep] = []
    var variables: [WorkflowVariable] = []
    var metadata: WorkflowMetadata = WorkflowMetadata()
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Workflow, rhs: Workflow) -> Bool { lhs.id == rhs.id }
}

// MARK: - Metadata

struct WorkflowMetadata: Codable {
    var recordedOnOSVersion: String = ProcessInfo.processInfo.operatingSystemVersionString
    var totalDuration: TimeInterval = 0
    var stepCount: Int = 0
    var exportVersion: Int = 1
    var tags: [String] = []
}

// MARK: - WorkflowVariable

struct WorkflowVariable: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var defaultValue: String = ""
    var type: VariableType = .string
    var promptOnRun: Bool = false
}

enum VariableType: String, Codable, CaseIterable {
    case string, number, boolean, filePath
    var displayName: String { rawValue.capitalized }
}

// MARK: - RetryPolicy

struct RetryPolicy: Codable {
    var maxAttempts: Int = 3
    var backoffSeconds: Double = 0.5
}

// MARK: - LoopConfig

struct LoopConfig: Codable {
    var count: Int?
    var whileCondition: StepCondition?
    var steps: [WorkflowStep] = []
}

// MARK: - StepCondition

struct StepCondition: Codable {
    var lhs: String
    var op: ConditionOperator
    var rhs: String
}

enum ConditionOperator: String, Codable, CaseIterable {
    case equals, notEquals, contains, notContains, exists, notExists
    var displayName: String {
        switch self {
        case .equals: return "=="
        case .notEquals: return "!="
        case .contains: return "contains"
        case .notContains: return "does not contain"
        case .exists: return "exists"
        case .notExists: return "does not exist"
        }
    }
}
