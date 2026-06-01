import CoreData
import Foundation

@objc(TaskItem)
final class TaskItem: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var priorityRaw: String
    @NSManaged var statusRaw: String
    @NSManaged var taskTypeRaw: String
    @NSManaged var taskDescription: String
    @NSManaged var estimatedMinutes: Int64
    @NSManaged var resultNotes: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var coreValue: CoreValue?
    @NSManaged var milestone: Milestone?
    @NSManaged var sessions: Set<WorkSession>

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        coreValue: CoreValue? = nil,
        milestone: Milestone? = nil,
        priority: TaskPriority = .medium,
        status: TaskStatus = .notStarted,
        taskType: TaskType = .deep,
        taskDescription: String = "",
        estimatedMinutes: Int = 0,
        resultNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.coreValue = coreValue
        self.milestone = milestone
        self.priorityRaw = priority.rawValue
        self.statusRaw = status.rawValue
        self.taskTypeRaw = taskType.rawValue
        self.taskDescription = taskDescription
        self.estimatedMinutes = Int64(max(0, estimatedMinutes))
        self.resultNotes = resultNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sessions = []
    }

    var priority: TaskPriority {
        get { TaskPriority(storedValue: priorityRaw) }
        set { priorityRaw = newValue.rawValue }
    }

    var effectivePriority: TaskPriority {
        if let goalPriority = milestone?.goal?.priority {
            return TaskPriority(goalPriority: goalPriority)
        }

        return priority
    }

    var status: TaskStatus {
        get { TaskStatus(storedValue: statusRaw) }
        set { statusRaw = newValue.rawValue }
    }

    var taskType: TaskType {
        get { TaskType(rawValue: taskTypeRaw) ?? .deep }
        set { taskTypeRaw = newValue.rawValue }
    }

    var estimatedMinutesValue: Int {
        get { Int(estimatedMinutes) }
        set { estimatedMinutes = Int64(max(0, newValue)) }
    }

    var activeSessions: [WorkSession] {
        sessions.filter { !$0.isDeleted }
    }

    var hasCompletedSession: Bool {
        activeSessions.contains { $0.status == .completed }
    }

    var hasPartialSession: Bool {
        activeSessions.contains { $0.status == .partial }
    }

    var hasStartedSession: Bool {
        activeSessions.contains { $0.status == .partial || $0.status == .completed }
    }

    var areAllSessionsCompleted: Bool {
        !activeSessions.isEmpty && activeSessions.allSatisfy { $0.status == .completed }
    }

    var sessionProgress: Double {
        let sessions = activeSessions
        guard !sessions.isEmpty else { return 0 }

        let weightedCompletion = sessions.reduce(0) { total, session in
            total + session.status.progressWeight
        }
        return min(max((weightedCompletion / Double(sessions.count)) * 100, 0), 100)
    }

    var isCompleteForProgress: Bool {
        areAllSessionsCompleted
    }

    var baseComputedStatus: TaskStatus {
        if isCompleteForProgress {
            return .completed
        }

        if hasStartedSession {
            return .partiallyCompleted
        }

        return .notStarted
    }

    var completionAwareStatus: TaskStatus {
        baseComputedStatus
    }

    func computedStatus(selectedTaskID: UUID?) -> TaskStatus {
        let baseStatus = baseComputedStatus
        if selectedTaskID == id {
            return .active
        }

        return baseStatus
    }

    var isStandalone: Bool {
        milestone == nil
    }

    var coreValueName: String {
        milestone?.coreValueName ?? coreValue?.name ?? ""
    }

    var goalName: String {
        milestone?.goalName ?? ""
    }

    var milestoneName: String {
        milestone?.name ?? ""
    }

    var displayGoalName: String {
        isStandalone ? "No Goal" : goalName
    }

    var displayMilestoneName: String {
        isStandalone ? "No Milestone" : milestoneName
    }

    var contextSummary: String {
        [goalName, milestoneName, coreValueName]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    var pickerSummary: String {
        contextSummary.isEmpty ? "Standalone Task" : contextSummary
    }
}
