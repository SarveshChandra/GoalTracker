import Foundation

enum SessionFocusService {
    static func orderedSessions(for task: TaskItem?) -> [WorkSession] {
        guard let task else { return [] }
        return orderedSessions(Array(task.activeSessions))
    }

    static func orderedSessions(_ sessions: [WorkSession]) -> [WorkSession] {
        sessions
            .filter { !$0.isDeleted }
            .sorted { left, right in
                if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
                let leftDate = left.sessionDate ?? .distantFuture
                let rightDate = right.sessionDate ?? .distantFuture
                if leftDate != rightDate { return leftDate < rightDate }
                return left.id.uuidString < right.id.uuidString
            }
    }

    static func firstIncompleteSession(for task: TaskItem?) -> WorkSession? {
        firstIncompleteSession(in: orderedSessions(for: task))
    }

    static func firstIncompleteSession(in sessions: [WorkSession]) -> WorkSession? {
        orderedSessions(sessions).first { $0.status != .completed }
    }
}
