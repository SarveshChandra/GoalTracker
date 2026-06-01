import CoreData
import Foundation

@objc(WorkSession)
final class WorkSession: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var sessionLabel: String
    @NSManaged var estimatedMinutes: Int64
    @NSManaged var actualMinutes: Int64
    @NSManaged var expectedResult: String
    @NSManaged var whatText: String
    @NSManaged var whenText: String
    @NSManaged var whyText: String
    @NSManaged var howText: String
    @NSManaged var howMuchText: String
    @NSManaged var statusRaw: String
    @NSManaged var sessionDate: Date?
    @NSManaged var sessionNotes: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var task: TaskItem?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        task: TaskItem? = nil,
        sessionLabel: String = "",
        estimatedMinutes: Int = 0,
        actualMinutes: Int = 0,
        expectedResult: String = "",
        whatText: String = "",
        whenText: String = "",
        whyText: String = "",
        howText: String = "",
        howMuchText: String = "",
        status: SessionStatus = .notStarted,
        sessionDate: Date? = nil,
        sessionNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.task = task
        self.sessionLabel = sessionLabel
        self.estimatedMinutes = Int64(max(0, estimatedMinutes))
        self.actualMinutes = Int64(max(0, actualMinutes))
        self.expectedResult = expectedResult
        self.whatText = whatText
        self.whenText = whenText
        self.whyText = whyText
        self.howText = howText
        self.howMuchText = howMuchText
        self.statusRaw = status.rawValue
        self.sessionDate = sessionDate
        self.sessionNotes = sessionNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .notStarted }
        set { statusRaw = newValue.rawValue }
    }

    var actualMinutesValue: Int {
        get { Int(actualMinutes) }
        set { actualMinutes = Int64(max(0, newValue)) }
    }

    var estimatedMinutesValue: Int {
        get { Int(estimatedMinutes) }
        set { estimatedMinutes = Int64(max(0, newValue)) }
    }

    var displayLabel: String {
        let trimmed = sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Session" : trimmed
    }

    var taskType: TaskType {
        task?.taskType ?? .deep
    }

    var coreValueName: String {
        task?.coreValueName ?? ""
    }

    var goalName: String {
        task?.goalName ?? ""
    }

    var milestoneName: String {
        task?.milestoneName ?? ""
    }

    var taskName: String {
        task?.name ?? "No Task"
    }

    var contextSummary: String {
        [goalName, milestoneName, coreValueName]
            .filter { !$0.isEmpty }
            .joined(separator: " | ")
    }

    var linkedAntiGoal: String {
        task?.milestone?.goal?.antiGoal ?? ""
    }

    var linkedSacrifice: String {
        task?.milestone?.goal?.sacrifice ?? ""
    }
}
