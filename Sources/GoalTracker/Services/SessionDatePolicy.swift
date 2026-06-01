import Foundation

enum SessionDatePolicy {
    static func dateAfterStatusChange(
        to status: SessionStatus,
        currentDate: Date?,
        now: Date = Date()
    ) -> Date? {
        status.usesAutomaticSessionDate ? now : currentDate
    }

    static func resolvedDateForSave(
        previousStatus: SessionStatus?,
        newStatus: SessionStatus,
        proposedDate: Date?,
        dateWasManuallyEdited: Bool,
        now: Date = Date()
    ) -> Date? {
        guard newStatus.usesAutomaticSessionDate else {
            return proposedDate
        }

        if dateWasManuallyEdited {
            return proposedDate ?? now
        }

        if previousStatus != newStatus {
            return now
        }

        return proposedDate ?? now
    }
}

extension SessionStatus {
    var usesAutomaticSessionDate: Bool {
        self == .partial || self == .completed
    }
}
