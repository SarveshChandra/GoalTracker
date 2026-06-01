import Foundation
import CoreData

enum ValidationService {
    static func clampProgress(_ progress: Double) -> Double {
        min(max(progress, 0), 100)
    }

    static func clampMinutes(_ minutes: Int) -> Int {
        max(0, minutes)
    }

    static func validateGoal(name: String, startDate: Date, dueDate: Date) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Goal Name is required."
        }
        if dueDate < startDate {
            return "Goal Due Date cannot be before Start Date."
        }
        return nil
    }

    static func validateMilestone(
        name: String,
        goal: Goal?,
        startDate: Date,
        dueDate: Date,
        excluding excludedMilestone: Milestone? = nil
    ) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Milestone Name is required."
        }
        guard let goal else {
            return "Milestone must belong to an existing Goal."
        }
        if dueDate < startDate {
            return "Milestone Due Date cannot be before Start Date."
        }
        let milestoneStart = DateUtils.startOfDay(startDate)
        let milestoneDue = DateUtils.startOfDay(dueDate)
        let goalStart = DateUtils.startOfDay(goal.startDate)
        let goalDue = DateUtils.startOfDay(goal.endDate)
        if milestoneStart < goalStart {
            return "Milestone Start Date must be on or after the Goal Start Date (\(DateUtils.displayDate(goal.startDate)))."
        }
        if milestoneDue > goalDue {
            return "Milestone Due Date must be on or before the Goal Due Date (\(DateUtils.displayDate(goal.endDate)))."
        }
        if let overlapping = firstOverlappingMilestone(
            in: goal.milestones,
            startDate: milestoneStart,
            dueDate: milestoneDue,
            excluding: excludedMilestone
        ) {
            return "Milestone date range overlaps \(overlapping.name). Milestones inside one Goal cannot overlap."
        }
        return nil
    }

    static func validateTask(name: String, milestone: Milestone?) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Task Name is required."
        }
        return nil
    }

    static func validateSession(sessionLabel: String, task: TaskItem?, estimatedMinutes: Int, actualMinutes: Int) -> String? {
        if sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Session label is required."
        }
        if task == nil {
            return "Session must belong to an existing Task."
        }
        if estimatedMinutes < 0 {
            return "Estimated Minutes cannot be negative."
        }
        if actualMinutes < 0 {
            return "Actual Minutes cannot be negative."
        }
        return nil
    }

    static func firstOverlappingMilestone(
        in milestones: Set<Milestone>,
        startDate: Date,
        dueDate: Date,
        excluding excludedMilestone: Milestone? = nil
    ) -> Milestone? {
        milestones
            .filter { milestone in
                if let excludedMilestone, milestone.id == excludedMilestone.id { return false }
                let existingStart = DateUtils.startOfDay(milestone.startDate)
                let existingDue = DateUtils.startOfDay(milestone.endDate)
                return dateRangesOverlap(startDate...dueDate, existingStart...existingDue)
            }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    static func overlappingMilestonePairs(in milestones: Set<Milestone>) -> [(Milestone, Milestone)] {
        let sortedMilestones = milestones.sorted {
            if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
            return $0.endDate < $1.endDate
        }

        guard sortedMilestones.count > 1 else { return [] }

        var overlaps: [(Milestone, Milestone)] = []
        for index in sortedMilestones.indices.dropLast() {
            let current = sortedMilestones[index]
            for next in sortedMilestones[(index + 1)...] {
                let currentRange = DateUtils.startOfDay(current.startDate)...DateUtils.startOfDay(current.endDate)
                let nextRange = DateUtils.startOfDay(next.startDate)...DateUtils.startOfDay(next.endDate)
                if dateRangesOverlap(currentRange, nextRange) {
                    overlaps.append((current, next))
                } else if DateUtils.startOfDay(next.startDate) > DateUtils.startOfDay(current.endDate) {
                    break
                }
            }
        }
        return overlaps
    }

    @discardableResult
    static func clampMilestonesToGoalDateRange(_ goal: Goal) -> Bool {
        var changed = false
        for milestone in goal.milestones {
            let nextStartDate = clamped(milestone.startDate, to: goal.startDate...goal.endDate)
            var nextEndDate = clamped(milestone.endDate, to: goal.startDate...goal.endDate)
            if nextEndDate < nextStartDate {
                nextEndDate = nextStartDate
            }

            if milestone.startDate != nextStartDate || milestone.endDate != nextEndDate {
                milestone.startDate = nextStartDate
                milestone.endDate = nextEndDate
                milestone.updatedAt = Date()
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    static func clampMilestonesToGoalDateRanges(_ goals: [Goal]) -> Bool {
        goals.reduce(false) { changed, goal in
            clampMilestonesToGoalDateRange(goal) || changed
        }
    }

    private static func clamped(_ date: Date, to range: ClosedRange<Date>) -> Date {
        min(max(date, range.lowerBound), range.upperBound)
    }

    private static func dateRangesOverlap(_ left: ClosedRange<Date>, _ right: ClosedRange<Date>) -> Bool {
        left.lowerBound <= right.upperBound && right.lowerBound <= left.upperBound
    }
}
