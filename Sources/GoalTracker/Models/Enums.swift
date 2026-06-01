import SwiftUI

enum NavigationSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case values = "Values"
    case goals = "Goals"
    case milestones = "Milestones"
    case tasks = "Tasks"
    case sessions = "Sessions"
    case dailyStreak = "Daily Streak"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "rectangle.grid.2x2"
        case .values: "heart.text.square"
        case .goals: "scope"
        case .milestones: "flag"
        case .tasks: "checklist"
        case .sessions: "circle.dotted"
        case .dailyStreak: "calendar"
        case .settings: "gearshape"
        }
    }

    var navigationTitle: String {
        switch self {
        case .values: "Values Sheet"
        case .goals: "Goals Sheet"
        case .milestones: "Milestones Sheet"
        case .tasks: "Tasks Sheet"
        case .sessions: "Sessions Sheet"
        default: rawValue
        }
    }
}

enum GoalPriority: String, CaseIterable, Identifiable, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }

    init(storedValue: String) {
        switch storedValue {
        case "Primary", "High":
            self = .high
        case "Secondary", "Medium":
            self = .medium
        case "Low":
            self = .low
        default:
            self = .medium
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = GoalPriority(storedValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum ComputedPriority: String, CaseIterable, Identifiable, Codable {
    case highest = "Highest"
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case none = "No Priority"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highest:
            return "Highest"
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        case .none:
            return ""
        }
    }

    var sortRank: Int {
        switch self {
        case .highest: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        case .none: 4
        }
    }

    init(goalPriority: GoalPriority) {
        switch goalPriority {
        case .high:
            self = .high
        case .medium:
            self = .medium
        case .low:
            self = .low
        }
    }

    init(taskPriority: TaskPriority) {
        switch taskPriority {
        case .highest:
            self = .highest
        case .high:
            self = .high
        case .medium:
            self = .medium
        case .low:
            self = .low
        }
    }

    init(storedValue: String) {
        switch storedValue {
        case "Highest":
            self = .highest
        case "High", "Primary":
            self = .high
        case "Medium", "Secondary":
            self = .medium
        case "Low":
            self = .low
        default:
            self = .none
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = ComputedPriority(storedValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(displayName)
    }
}

enum GoalStatus: String, CaseIterable, Identifiable, Codable {
    case notPlanned = "Not Planned"
    case notStarted = "Not Started"
    case completed = "Completed"
    case inProgress = "In Progress"
    case overdue = "Overdue"

    var id: String { rawValue }
}

enum MilestoneStatus: String, CaseIterable, Identifiable, Codable {
    case completed = "Completed"
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case overdue = "Overdue"

    var id: String { rawValue }
}

enum TaskStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "Not Started"
    case active = "Active"
    case partiallyCompleted = "Partially Completed"
    case completed = "Completed"

    var id: String { rawValue }

    init(storedValue: String) {
        switch storedValue {
        case "Active":
            self = .active
        case "Incomplete", "Partially Completed":
            self = .partiallyCompleted
        case "Completed":
            self = .completed
        default:
            self = .notStarted
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = TaskStatus(storedValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum TaskType: String, CaseIterable, Identifiable, Codable {
    case deep = "Deep"
    case shallow = "Shallow"

    var id: String { rawValue }
}

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case highest = "Highest"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var id: String { rawValue }

    init(storedValue: String) {
        switch storedValue {
        case "Highest":
            self = .highest
        case "High", "Primary":
            self = .high
        case "Low":
            self = .low
        default:
            self = .medium
        }
    }

    init(goalPriority: GoalPriority) {
        switch goalPriority {
        case .high:
            self = .high
        case .medium:
            self = .medium
        case .low:
            self = .low
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = TaskPriority(storedValue: try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum SessionStatus: String, CaseIterable, Identifiable, Codable {
    case notStarted = "notStarted"
    case partial = "partial"
    case completed = "completed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notStarted: "Not Started"
        case .partial: "Partially Completed"
        case .completed: "Completed"
        }
    }

    var progressWeight: Double {
        switch self {
        case .notStarted: 0
        case .partial: 0.5
        case .completed: 1
        }
    }

    var countsTowardDailyStreak: Bool {
        self == .partial || self == .completed
    }
}

enum ThemePreference: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
