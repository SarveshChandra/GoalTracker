import Foundation

enum StatusTextStyle {
    static func usesBoldWeight(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == TaskStatus.partiallyCompleted.rawValue ||
            trimmed == TaskStatus.active.rawValue ||
            trimmed == GoalStatus.inProgress.rawValue ||
            trimmed.hasSuffix(" \(GoalStatus.inProgress.rawValue)")
    }
}
