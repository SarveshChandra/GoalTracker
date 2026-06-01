import CoreData
import Foundation

@objc(Goal)
final class Goal: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var priorityRaw: String
    @NSManaged var startDate: Date
    @NSManaged var endDate: Date
    @NSManaged var progress: Double
    @NSManaged var antiGoal: String
    @NSManaged var sacrifice: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var coreValues: Set<CoreValue>
    @NSManaged var milestones: Set<Milestone>

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        priority: GoalPriority = .medium,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date(),
        progress: Double = 0,
        antiGoal: String = "",
        sacrifice: String = "",
        coreValues: [CoreValue] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.priorityRaw = priority.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.progress = min(max(progress, 0), 100)
        self.antiGoal = antiGoal
        self.sacrifice = sacrifice
        self.coreValues = Set(coreValues)
        self.milestones = []
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var priority: GoalPriority {
        get { GoalPriority(storedValue: priorityRaw) }
        set { priorityRaw = newValue.rawValue }
    }

    var status: GoalStatus {
        StatusCalculator.goalStatus(
            progress: computedProgress,
            startDate: startDate,
            dueDate: endDate,
            isPlanned: isPlanned
        )
    }

    var timeHorizon: String {
        DateUtils.humanDuration(from: startDate, to: endDate)
    }

    var linkedMilestonesCount: Int { milestones.count }

    var computedProgress: Double {
        guard !milestones.isEmpty else { return 0 }
        let average = milestones.reduce(0) { total, milestone in
            total + milestone.computedProgress
        } / Double(milestones.count)
        return min(max(average, 0), 100)
    }

    var isPlanned: Bool {
        hasMilestoneBoundaryCoverage && !hasOverlappingMilestones
    }

    var hasMilestoneBoundaryCoverage: Bool {
        guard !milestones.isEmpty else { return false }
        let goalStart = DateUtils.startOfDay(startDate)
        let goalDue = DateUtils.startOfDay(endDate)
        let hasStartMatch = milestones.contains { DateUtils.startOfDay($0.startDate) == goalStart }
        let hasDueMatch = milestones.contains { DateUtils.startOfDay($0.endDate) == goalDue }
        return hasStartMatch && hasDueMatch
    }

    var hasOverlappingMilestones: Bool {
        ValidationService.overlappingMilestonePairs(in: milestones).isEmpty == false
    }

    var activeMilestonesCount: Int {
        milestones.filter { $0.status == .inProgress || $0.status == .overdue }.count
    }

    var completedMilestonesCount: Int {
        milestones.filter { $0.status == .completed }.count
    }

    var coreValueNames: String {
        coreValues.map(\.name).sorted().joined(separator: ", ")
    }

    var primaryCoreValueName: String {
        coreValues.sorted { $0.name < $1.name }.first?.name ?? "No Core Value"
    }
}
