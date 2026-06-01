import Foundation

enum StatusCalculator {
    static func goalStatus(
        progress: Double,
        startDate: Date,
        dueDate: Date,
        isPlanned: Bool,
        today: Date = Date()
    ) -> GoalStatus {
        if !isPlanned { return .notPlanned }
        if progress >= 100 { return .completed }
        if Calendar.current.startOfDay(for: today) > Calendar.current.startOfDay(for: dueDate) { return .overdue }
        if progress <= 0 { return .notStarted }
        return .inProgress
    }

    static func milestoneStatus(progress: Double, startDate: Date, endDate: Date, today: Date = Date()) -> MilestoneStatus {
        let todayDay = Calendar.current.startOfDay(for: today)
        let startDay = Calendar.current.startOfDay(for: startDate)
        let endDay = Calendar.current.startOfDay(for: endDate)

        if progress >= 100 { return .completed }
        if todayDay < startDay && progress == 0 { return .notStarted }
        if todayDay > endDay && progress < 100 { return .overdue }
        return .inProgress
    }
}
