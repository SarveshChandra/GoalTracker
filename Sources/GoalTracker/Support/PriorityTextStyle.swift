import Foundation

enum PriorityTextStyle {
    static func usesBoldWeight(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == ComputedPriority.high.displayName ||
            trimmed == ComputedPriority.highest.displayName
    }

    static func opacity(for text: String) -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == ComputedPriority.none.rawValue { return 0.42 }
        if trimmed == ComputedPriority.low.displayName { return 0.56 }
        return 1
    }
}
