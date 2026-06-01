import CoreData
import Foundation

@main
struct ReplaceTrackerDataPreservingValues {
    @MainActor
    static func main() throws {
        let context = PersistenceController.shared.container.viewContext
        let valuesBefore = try context.fetchAll(CoreValue.self).count
        let myValuesBefore = MyValueStore.currentValues().count

        DemoDataService.replaceTrackerDataPreservingValues(in: context)
        context.processPendingChanges()

        let goals = try context.fetchAll(Goal.self)
        let milestones = try context.fetchAll(Milestone.self)
        let tasks = try context.fetchAll(TaskItem.self)
        let sessions = try context.fetchAll(WorkSession.self)
        let valuesAfter = try context.fetchAll(CoreValue.self).count
        let myValuesAfter = MyValueStore.currentValues().count

        guard valuesBefore == valuesAfter else {
            throw ReplacementError.valuesChanged(before: valuesBefore, after: valuesAfter)
        }

        guard myValuesBefore == myValuesAfter else {
            throw ReplacementError.myValuesChanged(before: myValuesBefore, after: myValuesAfter)
        }

        guard tasks.count > 100 else {
            throw ReplacementError.tooFewTasks(tasks.count)
        }

        let health = try DataHealthService.run(in: context)
        guard health.isHealthy else {
            throw ReplacementError.dataHealthFailed(health.issues.joined(separator: "; "))
        }

        print("Replaced tracker data while preserving Values: values=\(valuesAfter), goals=\(goals.count), milestones=\(milestones.count), tasks=\(tasks.count), sessions=\(sessions.count).")
    }
}

enum ReplacementError: Error, CustomStringConvertible {
    case valuesChanged(before: Int, after: Int)
    case myValuesChanged(before: Int, after: Int)
    case tooFewTasks(Int)
    case dataHealthFailed(String)

    var description: String {
        switch self {
        case .valuesChanged(let before, let after):
            return "Core Values changed during replacement: before=\(before), after=\(after)."
        case .myValuesChanged(let before, let after):
            return "My Values changed during replacement: before=\(before), after=\(after)."
        case .tooFewTasks(let count):
            return "Expected more than 100 tasks, found \(count)."
        case .dataHealthFailed(let message):
            return "Data Health failed: \(message)"
        }
    }
}
