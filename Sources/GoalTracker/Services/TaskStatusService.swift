import CoreData
import Foundation

enum TaskStatusService {
    @discardableResult
    static func refreshStoredStatus(for task: TaskItem?, now: Date = Date()) -> Bool {
        guard let task else { return false }

        let nextStatus = sessionDerivedStatus(for: task)
        guard task.status != nextStatus else { return false }

        task.status = nextStatus
        task.updatedAt = now
        return true
    }

    @discardableResult
    static func refreshAllStoredStatuses(in context: NSManagedObjectContext, now: Date = Date()) -> Bool {
        let tasks = (try? context.fetchAll(TaskItem.self)) ?? []
        var changed = false
        for task in tasks {
            if refreshStoredStatus(for: task, now: now) {
                changed = true
            }
        }
        return changed
    }

    private static func sessionDerivedStatus(for task: TaskItem) -> TaskStatus {
        let activeSessions = task.sessions.filter { !$0.isDeleted }
        if !activeSessions.isEmpty && activeSessions.allSatisfy({ $0.status == .completed }) {
            return .completed
        } else if activeSessions.contains(where: { $0.status == .partial || $0.status == .completed }) {
            return .partiallyCompleted
        } else {
            return .notStarted
        }
    }
}
