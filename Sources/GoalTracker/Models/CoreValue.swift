import CoreData
import Foundation

@objc(CoreValue)
final class CoreValue: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var valueDescription: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var goals: Set<Goal>
    @NSManaged var standaloneTasks: Set<TaskItem>

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        valueDescription: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.valueDescription = valueDescription
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.goals = []
        self.standaloneTasks = []
    }

    var linkedGoalsCount: Int { goals.count }

    var linkedTasksCount: Int {
        let goalTaskCount = goals.reduce(0) { total, goal in
            total + goal.milestones.reduce(0) { milestoneTotal, milestone in
                milestoneTotal + milestone.tasks.count
            }
        }
        return goalTaskCount + standaloneTasks.count
    }

    var hasActiveGoal: Bool {
        goals.contains { $0.computedProgress < 100 }
    }
}
