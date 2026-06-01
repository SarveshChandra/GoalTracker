import Foundation

enum GoalPriorityService {
    static func priorities(for goals: [Goal], today: Date = Date()) -> [UUID: ComputedPriority] {
        let goals = uniqueGoals(from: goals)
        let cacheKey = GoalPriorityCacheKey(goals: goals, today: today)
        if let cachedPriorities, cachedPriorities.key == cacheKey {
            return cachedPriorities.priorities
        }

        let metrics = goals.map { GoalPriorityMetrics(goal: $0, today: today) }
        var result = Dictionary(uniqueKeysWithValues: metrics.map { ($0.id, ComputedPriority.none) })
        let candidates = metrics.compactMap { metric -> GoalPriorityScore? in
            guard metric.isEligibleForPriority else { return nil }
            if metric.isOverdue {
                return GoalPriorityScore(metric: metric, score: .greatestFiniteMagnitude, isOverdue: true)
            }
            return GoalPriorityScore(metric: metric, score: urgencyScore(for: metric, startedGoalCount: 1), isOverdue: false)
        }

        let startedGoalCount = candidates.count
        let rescored = candidates.map { candidate in
            candidate.isOverdue
                ? candidate
                : GoalPriorityScore(
                    metric: candidate.metric,
                    score: urgencyScore(for: candidate.metric, startedGoalCount: startedGoalCount),
                    isOverdue: false
                )
        }

        let overdue = rescored.filter(\.isOverdue)
        for item in overdue {
            result[item.metric.id] = .highest
        }

        let active = rescored
            .filter { !$0.isOverdue }
            .sorted { left, right in
                if left.score != right.score { return left.score > right.score }
                if left.metric.progress != right.metric.progress {
                    return left.metric.progress < right.metric.progress
                }
                return left.metric.dueDate < right.metric.dueDate
            }

        for (index, item) in active.enumerated() {
            result[item.metric.id] = comparativePriority(
                forScore: item.score,
                rank: index,
                total: active.count,
                highestAlreadyAssigned: result.values.contains(.highest)
            )
        }

        cachedPriorities = GoalPriorityCache(key: cacheKey, priorities: result)
        return result
    }

    static func priority(for goal: Goal, among goals: [Goal], today: Date = Date()) -> ComputedPriority {
        priorities(for: goals, today: today)[goal.id] ?? .none
    }

    static func standalonePriority(for goal: Goal, today: Date = Date()) -> ComputedPriority {
        let metric = GoalPriorityMetrics(goal: goal, today: today)
        guard metric.isEligibleForPriority else { return .none }
        if metric.isOverdue { return .highest }
        return thresholdPriority(forScore: urgencyScore(for: metric, startedGoalCount: 1))
    }

    static func displayPriority(for task: TaskItem, goalPriorities: [UUID: ComputedPriority]) -> ComputedPriority {
        guard let goal = task.milestone?.goal else {
            guard task.baseComputedStatus != .completed else { return .none }
            return ComputedPriority(taskPriority: task.priority)
        }
        return goalPriorities[goal.id] ?? standalonePriority(for: goal)
    }

    private static func urgencyScore(for metric: GoalPriorityMetrics, startedGoalCount: Int) -> Double {
        let progress = min(max(metric.progress, 0), 100)
        let expectedProgress = min(100, (Double(metric.daysPassed) / Double(metric.totalDays)) * 100)
        let progressDeficit = max(0, expectedProgress - progress)
        let remainingProgress = max(0, 100 - progress)
        let actualDailyProgress = progress / Double(metric.daysPassed)
        let requiredDailyProgress = metric.daysRemaining > 0 ? remainingProgress / Double(metric.daysRemaining) : remainingProgress
        let pacePressure: Double
        if actualDailyProgress <= 0 {
            pacePressure = min(35, requiredDailyProgress * 8)
        } else {
            pacePressure = min(35, max(0, (requiredDailyProgress / max(actualDailyProgress, 0.1) - 1) * 12))
        }

        let taskPressure = metric.allTasks > 0 ? (Double(metric.pendingTasks) / Double(metric.allTasks)) * 15 : 10
        let sessionPressure = metric.allSessions > 0 ? (Double(metric.pendingSessions) / Double(metric.allSessions)) * 10 : 6
        let duePressure = min(25, max(0, 25 - Double(metric.daysRemaining) * 1.25))
        let multiGoalPressure = min(12, Double(max(0, startedGoalCount - 1)) * 3)

        return (progressDeficit * 0.5) + pacePressure + taskPressure + sessionPressure + duePressure + multiGoalPressure
    }

    private static func comparativePriority(
        forScore score: Double,
        rank: Int,
        total: Int,
        highestAlreadyAssigned: Bool
    ) -> ComputedPriority {
        var priority = thresholdPriority(forScore: score)
        guard total > 1 else { return priority }

        if priority == .highest && (highestAlreadyAssigned || rank > 0) {
            priority = .high
        }

        let highCutoff = max(1, Int(ceil(Double(total) * 0.25)))
        let mediumCutoff = max(highCutoff + 1, Int(ceil(Double(total) * 0.60)))

        if rank < highCutoff && score >= 58 {
            priority = moreUrgent(priority, .high)
        } else if rank < mediumCutoff && score >= 28 {
            priority = moreUrgent(priority, .medium)
        }

        return priority
    }

    private static func thresholdPriority(forScore score: Double) -> ComputedPriority {
        if score >= 92 { return .highest }
        if score >= 66 { return .high }
        if score >= 34 { return .medium }
        return .low
    }

    private static func moreUrgent(_ left: ComputedPriority, _ right: ComputedPriority) -> ComputedPriority {
        left.sortRank <= right.sortRank ? left : right
    }

    private static func uniqueGoals(from goals: [Goal]) -> [Goal] {
        var seen: Set<UUID> = []
        return goals.filter { seen.insert($0.id).inserted }
    }

    private static var cachedPriorities: GoalPriorityCache?
}

private struct GoalPriorityCache {
    let key: GoalPriorityCacheKey
    let priorities: [UUID: ComputedPriority]
}

private struct GoalPriorityCacheKey: Equatable {
    let day: Date
    let fingerprints: [String]

    init(goals: [Goal], today: Date) {
        day = DateUtils.startOfDay(today)
        fingerprints = goals
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { goal in
                [
                    goal.id.uuidString,
                    String(goal.startDate.timeIntervalSinceReferenceDate),
                    String(goal.endDate.timeIntervalSinceReferenceDate),
                    String(goal.updatedAt.timeIntervalSinceReferenceDate)
                ].joined(separator: ":")
            }
    }
}

private struct GoalPriorityScore {
    let metric: GoalPriorityMetrics
    let score: Double
    let isOverdue: Bool
}

private struct GoalPriorityMetrics {
    let id: UUID
    let dueDate: Date
    let progress: Double
    let daysPassed: Int
    let daysRemaining: Int
    let totalDays: Int
    let allTasks: Int
    let pendingTasks: Int
    let allSessions: Int
    let pendingSessions: Int
    let isEligibleForPriority: Bool
    let isOverdue: Bool

    init(goal: Goal, today: Date) {
        let todayDay = DateUtils.startOfDay(today)
        let startDay = DateUtils.startOfDay(goal.startDate)
        let dueDay = DateUtils.startOfDay(goal.endDate)
        let calendar = Calendar.current
        var taskProgressTotal = 0.0
        var taskCount = 0
        var completedTaskCount = 0
        var sessionCount = 0
        var completedSessionCount = 0

        for milestone in goal.milestones {
            for task in milestone.tasks {
                let sessions = task.sessions.filter { !$0.isDeleted }
                taskCount += 1
                sessionCount += sessions.count
                completedSessionCount += sessions.filter { $0.status == .completed }.count

                if !sessions.isEmpty {
                    let progress = sessions.reduce(0.0) { $0 + $1.status.progressWeight } / Double(sessions.count)
                    taskProgressTotal += progress * 100
                    if sessions.allSatisfy({ $0.status == .completed }) {
                        completedTaskCount += 1
                    }
                }
            }
        }

        let progress = taskCount > 0 ? min(max(taskProgressTotal / Double(taskCount), 0), 100) : 0

        self.id = goal.id
        self.dueDate = goal.endDate
        self.progress = progress
        self.daysPassed = max(1, (calendar.dateComponents([.day], from: startDay, to: todayDay).day ?? 0) + 1)
        self.daysRemaining = max(0, calendar.dateComponents([.day], from: todayDay, to: dueDay).day ?? 0)
        self.totalDays = max(1, (calendar.dateComponents([.day], from: startDay, to: dueDay).day ?? 0) + 1)
        self.allTasks = taskCount
        self.pendingTasks = max(0, taskCount - completedTaskCount)
        self.allSessions = sessionCount
        self.pendingSessions = max(0, sessionCount - completedSessionCount)
        self.isEligibleForPriority = startDay <= todayDay && progress < 100
        self.isOverdue = todayDay > dueDay && progress < 100
    }
}
