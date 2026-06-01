import CoreData
import Foundation

@objc(Milestone)
final class Milestone: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var progress: Double
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var goal: Goal?
    @NSManaged var tasks: Set<TaskItem>

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        goal: Goal? = nil,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
        progress: Double = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.goal = goal
        self.startDate = startDate
        self.endDate = endDate
        self.progress = min(max(progress, 0), 100)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tasks = []
    }

    var status: MilestoneStatus {
        StatusCalculator.milestoneStatus(progress: computedProgress, startDate: startDate, endDate: endDate)
    }

    var duration: String {
        DateUtils.humanDuration(from: startDate, to: endDate)
    }

    var coreValueName: String {
        goal?.primaryCoreValueName ?? "No Core Value"
    }

    var goalName: String {
        goal?.name ?? "No Goal"
    }

    var linkedTasksCount: Int { tasks.count }

    var computedProgress: Double {
        guard linkedTasksCount > 0 else { return 0 }
        let averageTaskProgress = tasks.reduce(0) { total, task in
            total + task.sessionProgress
        } / Double(linkedTasksCount)
        return min(max(averageTaskProgress, 0), 100)
    }

    var activeTasksCount: Int {
        tasks.filter { $0.completionAwareStatus == .active }.count
    }

    var completedTasksCount: Int {
        tasks.filter { $0.isCompleteForProgress }.count
    }
}
