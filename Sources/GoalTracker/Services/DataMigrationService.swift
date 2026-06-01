import CoreData
import Foundation

@MainActor
enum DataMigrationService {
    @discardableResult
    static func backfillSessionLabels(in context: NSManagedObjectContext) -> Bool {
        let sessions = (try? context.fetchAll(WorkSession.self)) ?? []
        var changed = false

        for session in sessions {
            guard session.sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            session.sessionLabel = firstNonEmpty([
                session.expectedResult,
                session.whatText,
                session.taskName
            ])
            session.updatedAt = Date()
            changed = true
        }

        return changed
    }

    @discardableResult
    static func backfillSessionEstimatedMinutes(in context: NSManagedObjectContext) -> Bool {
        let sessions = (try? context.fetchAll(WorkSession.self)) ?? []
        var changed = false

        for session in sessions where session.estimatedMinutesValue == 0 {
            guard let taskMinutes = session.task?.estimatedMinutesValue, taskMinutes > 0 else {
                continue
            }

            session.estimatedMinutesValue = taskMinutes
            session.updatedAt = Date()
            changed = true
        }

        return changed
    }

    private static func firstNonEmpty(_ values: [String]) -> String {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Untitled Session"
    }
}
