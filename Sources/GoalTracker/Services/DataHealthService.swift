import CoreData
import Foundation

struct DataHealthReport {
    let checkedAt: Date
    let valuesCount: Int
    let goalsCount: Int
    let milestonesCount: Int
    let tasksCount: Int
    let sessionsCount: Int
    let issues: [String]

    var isHealthy: Bool {
        issues.isEmpty
    }

    var statusText: String {
        isHealthy ? "Healthy" : "\(issues.count) issue\(issues.count == 1 ? "" : "s") found"
    }
}

@MainActor
enum DataHealthService {
    static func run(in context: NSManagedObjectContext) throws -> DataHealthReport {
        let values = try context.fetchAll(CoreValue.self)
        let goals = try context.fetchAll(Goal.self)
        let milestones = try context.fetchAll(Milestone.self)
        let tasks = try context.fetchAll(TaskItem.self)
        let sessions = try context.fetchAll(WorkSession.self)

        var issues: [String] = []

        for goal in goals {
            if goal.endDate < goal.startDate {
                issues.append("Goal has Due Date before Start Date: \(goal.name)")
            }

            let overlaps = ValidationService.overlappingMilestonePairs(in: goal.milestones)
            for overlap in overlaps {
                issues.append("Milestone date ranges overlap inside Goal \(goal.name): \(overlap.0.name) and \(overlap.1.name)")
            }
        }

        for milestone in milestones {
            guard let goal = milestone.goal else {
                issues.append("Milestone has no Goal: \(milestone.name)")
                continue
            }

            if milestone.endDate < milestone.startDate {
                issues.append("Milestone has Due Date before Start Date: \(milestone.name)")
            }

            if DateUtils.startOfDay(milestone.startDate) < DateUtils.startOfDay(goal.startDate) ||
                DateUtils.startOfDay(milestone.endDate) > DateUtils.startOfDay(goal.endDate) {
                issues.append("Milestone is outside its Goal date range: \(milestone.name)")
            }
        }

        for session in sessions {
            if session.task == nil {
                issues.append("Session has no Task: \(session.displayLabel)")
            }

            if session.estimatedMinutesValue < 0 {
                issues.append("Session has negative Estimated Minutes: \(session.displayLabel)")
            }

            if session.actualMinutesValue < 0 {
                issues.append("Session has negative Actual Minutes: \(session.displayLabel)")
            }
        }

        return DataHealthReport(
            checkedAt: Date(),
            valuesCount: values.count,
            goalsCount: goals.count,
            milestonesCount: milestones.count,
            tasksCount: tasks.count,
            sessionsCount: sessions.count,
            issues: issues
        )
    }
}
