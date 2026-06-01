import CoreData
import Foundation

@main
struct SeedDemoData {
    @MainActor
    static func main() {
        let context = PersistenceController.shared.container.viewContext
        DemoDataService.installDemoData(in: context, markInstalled: true)
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Save failed: \(error)")
            }
        }
        let values = (try? context.fetchAll(CoreValue.self))?.count ?? -1
        let goals = (try? context.fetchAll(Goal.self))?.count ?? -1
        let milestones = (try? context.fetchAll(Milestone.self))?.count ?? -1
        let tasks = (try? context.fetchAll(TaskItem.self))?.count ?? -1
        let sessions = (try? context.fetchAll(WorkSession.self))?.count ?? -1
        print("Seeded Goal Tracker demo data: values=\(values), goals=\(goals), milestones=\(milestones), tasks=\(tasks), sessions=\(sessions).")
    }
}
