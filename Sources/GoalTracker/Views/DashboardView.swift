import Charts
import CoreData
import SwiftUI

struct DashboardView: View {
    let filters: GoalTrackerGlobalFilters

    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @FetchRequest(sortDescriptors: []) private var milestones: FetchedResults<Milestone>
    @FetchRequest(sortDescriptors: []) private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: []) private var sessions: FetchedResults<WorkSession>

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: Array(goals))
    }

    private var sortedGoals: [Goal] {
        goals.sorted { GoalTrackerSort.goals($0, $1, priorities: goalPriorities) }
    }

    private var dashboardGoals: [Goal] {
        let activeGoals = sortedGoals.filter { $0.status != .completed }
        return Array((activeGoals.isEmpty ? sortedGoals : activeGoals).prefix(3))
    }

    private var goalGridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: min(max(dashboardGoals.count, 1), 3))
    }

    private var activeMilestones: [Milestone] {
        milestones
            .filter { $0.status == .inProgress || $0.status == .overdue }
            .sorted { GoalTrackerSort.milestones($0, $1, priorities: goalPriorities) }
    }

    private var activeTasks: [TaskItem] {
        guard let selectedTask, selectedTask.computedStatus(selectedTaskID: filters.taskID) == .active else { return [] }
        return [selectedTask]
    }

    private var todaySessions: [WorkSession] {
        sessions.filter { DateUtils.isToday($0.sessionDate) }
    }

    private var recentCompletedSessions: [WorkSession] {
        sessions
            .filter { $0.status == .completed }
            .sorted { ($0.sessionDate ?? .distantPast) > ($1.sessionDate ?? .distantPast) }
            .prefix(6)
            .map { $0 }
    }

    private var overdueGoals: [Goal] {
        goals.filter { $0.status == .overdue }
    }

    private var overdueMilestones: [Milestone] {
        milestones.filter { $0.status == .overdue }
    }

    private var completedSessionsThisMonth: Int {
        sessions.filter { $0.status == .completed && DateUtils.isDateInCurrentMonth($0.sessionDate) }.count
    }

    private var actualMinutesThisMonth: Int {
        sessions
            .filter { DateUtils.isDateInCurrentMonth($0.sessionDate) }
            .reduce(0) { $0 + $1.actualMinutesValue }
    }

    private var currentStreak: Int {
        StreakMetrics.currentStreak(from: Array(sessions))
    }

    private var bestStreak: Int {
        StreakMetrics.bestStreak(from: Array(sessions))
    }

    private var selectedTask: TaskItem? {
        guard let taskID = filters.taskID else { return nil }
        return tasks.first { $0.id == taskID }
    }

    private var selectedTaskSessions: [WorkSession] {
        guard let selectedTask else { return [] }
        return SessionFocusService.orderedSessions(
            sessions.filter { $0.task?.id == selectedTask.id }
        )
    }

    private var selectedTaskFocusSession: WorkSession? {
        SessionFocusService.firstIncompleteSession(in: selectedTaskSessions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModuleHeader(
                    title: "Dashboard",
                    subtitle: "Read-only focus surface. Edit in Values, Goals, Milestones, Tasks, or Sessions."
                ) {
                    StatusBadge(text: "Goal Tracker", color: GoalTrackerTheme.appYellow.opacity(0.80))
                }

                if let selectedTask {
                    DashboardSelectedTaskSessionCard(
                        task: selectedTask,
                        selectedSession: selectedTaskFocusSession,
                        sessionsCount: selectedTaskSessions.count
                    )
                }

                if dashboardGoals.isEmpty {
                    EmptyStateView(
                        systemImage: "scope",
                        title: "No Goals yet.",
                        message: "Add Goals and assign High, Medium, or Low priority.",
                        iconColor: GoalTrackerTheme.moduleIconRed.opacity(0.52)
                    )
                    .frame(minHeight: 220)
                } else {
                    LazyVGrid(columns: goalGridColumns, spacing: 16) {
                        ForEach(dashboardGoals) { goal in
                            DashboardGoalCard(
                                goal: goal,
                                priority: goalPriorities[goal.id] ?? GoalPriorityService.standalonePriority(for: goal),
                                selectedTaskID: filters.taskID
                            )
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DashboardListCard(title: "Active Milestones", systemImage: "flag") {
                        if activeMilestones.isEmpty {
                            Text("No active Milestones.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeMilestones.prefix(8)) { milestone in
                                DashboardMilestoneRow(milestone: milestone)
                            }
                        }
                    }

                    DashboardListCard(title: "Active Tasks", systemImage: "checklist") {
                        if activeTasks.isEmpty {
                            Text("No active Tasks.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeTasks.prefix(8)) { task in
                                DashboardTaskRow(task: task)
                            }
                        }
                    }

                    DashboardListCard(title: "Today / Recent Sessions", systemImage: "circle.dotted") {
                        if todaySessions.isEmpty && recentCompletedSessions.isEmpty {
                            Text("No sessions completed this month. Complete a session to begin your streak.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(todaySessions.prefix(4)) { session in
                                DashboardSessionRow(session: session, prefix: "Today")
                            }
                            ForEach(recentCompletedSessions.prefix(4)) { session in
                                DashboardSessionRow(session: session, prefix: "Recent")
                            }
                        }
                    }

                    DashboardListCard(title: "Overdue Things", systemImage: "exclamationmark.triangle") {
                        if overdueGoals.isEmpty && overdueMilestones.isEmpty {
                            Text("No overdue Goals or Milestones.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(overdueGoals) { goal in
                                Label {
                                    Text(goal.name)
                                        .foregroundStyle(.red)
                                } icon: {
                                    Image(systemName: "scope")
                                        .foregroundStyle(GoalTrackerTheme.moduleIconRed)
                                }
                            }
                            ForEach(overdueMilestones) { milestone in
                                Label {
                                    Text("\(milestone.name) | \(milestone.goalName)")
                                        .foregroundStyle(.red)
                                } icon: {
                                    Image(systemName: "flag")
                                        .foregroundStyle(GoalTrackerTheme.moduleIconRed)
                                }
                            }
                        }
                    }
                }

                MetricsStrip(
                    completedSessionsThisMonth: completedSessionsThisMonth,
                    actualMinutesThisMonth: actualMinutesThisMonth,
                    deepTasks: tasks.filter { $0.taskType == .deep }.count,
                    shallowTasks: tasks.filter { $0.taskType == .shallow }.count,
                    completedTasks: tasks.filter { $0.isCompleteForProgress }.count,
                    activeTasks: activeTasks.count,
                    currentStreak: currentStreak,
                    bestStreak: bestStreak
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ChartCard(title: "Task Type Distribution") {
                        PieChart(data: [
                            ChartDatum(label: "Deep", count: tasks.filter { $0.taskType == .deep }.count),
                            ChartDatum(label: "Shallow", count: tasks.filter { $0.taskType == .shallow }.count)
                        ])
                    }

                    ChartCard(title: "Session Status Distribution") {
                        PieChart(data: [
                            ChartDatum(label: "Completed", count: sessions.filter { $0.status == .completed }.count),
                            ChartDatum(label: "Partial", count: sessions.filter { $0.status == .partial }.count),
                            ChartDatum(label: "Not Started", count: sessions.filter { $0.status == .notStarted }.count)
                        ])
                    }

                    ChartCard(title: "Goal Priority Distribution") {
                        PieChart(data: [
                            ChartDatum(label: "Highest", count: goalPriorities.values.filter { $0 == .highest }.count),
                            ChartDatum(label: "High", count: goalPriorities.values.filter { $0 == .high }.count),
                            ChartDatum(label: "Medium", count: goalPriorities.values.filter { $0 == .medium }.count),
                            ChartDatum(label: "Low", count: goalPriorities.values.filter { $0 == .low }.count)
                        ])
                    }

                    ChartCard(title: "Goal Progress") {
                        GoalsProgressChart(goals: Array(sortedGoals.prefix(8)), priorities: goalPriorities)
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct DashboardGoalCard: View {
    let goal: Goal
    let priority: ComputedPriority
    let selectedTaskID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(priority == .none ? "" : "\(priority.displayName) Priority Goal")
                    .font(.custom("Helvetica Neue", size: 14).weight(PriorityTextStyle.usesBoldWeight(priority.displayName) ? .bold : .regular))
                    .foregroundStyle(priorityTextColor.opacity(PriorityTextStyle.opacity(for: priority.displayName)))
                Spacer()
                StatusBadge(
                    text: goal.status.rawValue,
                    color: GoalTrackerTheme.background(for: goal.status)
                )
            }

            Text(goal.name)
                .font(.custom("Helvetica Neue", size: 20).weight(.bold))
                .lineLimit(2)
            Text(goal.coreValueNames)
                .foregroundStyle(.secondary)

            ProgressView(value: goal.computedProgress, total: 100)
            Text(Formatters.percent(goal.computedProgress))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                ReadOnlyField(title: "Start Date", value: DateUtils.displayDate(goal.startDate))
                ReadOnlyField(title: "Due Date", value: DateUtils.displayDate(goal.endDate))
                ReadOnlyField(title: "Time Horizon", value: goal.timeHorizon)
                ReadOnlyField(title: "Milestones", value: "\(goal.activeMilestonesCount) active / \(goal.completedMilestonesCount) done")
            }

            ReadOnlyField(title: "Current / Next Active Milestones", value: goal.milestones.filter { $0.status == .inProgress || $0.status == .overdue }.prefix(3).map(\.name).joined(separator: ", "))
            ReadOnlyField(title: "Next Active Tasks", value: goal.milestones.flatMap(\.tasks).filter { $0.computedStatus(selectedTaskID: selectedTaskID) == .active }.prefix(3).map(\.name).joined(separator: ", "))
            ReadOnlyField(title: "Anti-Goal", value: goal.antiGoal)
            ReadOnlyField(title: "Sacrifice", value: goal.sacrifice)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .goalCard()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(priorityColor)
                .frame(height: priority == .high ? 4 : 3)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .highest:
            GoalTrackerTheme.appYellow
        case .high:
            GoalTrackerTheme.appYellow
        case .medium:
            GoalTrackerTheme.secondaryAccent
        case .low:
            GoalTrackerTheme.neutral
        case .none:
            GoalTrackerTheme.neutral.opacity(0.42)
        }
    }

    private var priorityTextColor: Color {
        priority == .highest ? GoalTrackerTheme.devotionalRed : Color.black
    }
}

private struct DashboardListCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .foregroundStyle(moduleIconColor)
                Text(title)
            }
            .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 220, alignment: .topLeading)
        .goalCard()
    }
}

private extension DashboardListCard {
    var moduleIconColor: Color {
        switch systemImage {
        case "scope", "flag", "checklist", "circle.dotted":
            GoalTrackerTheme.moduleIconRed
        default:
            Color.primary
        }
    }
}

private struct DashboardSelectedTaskSessionCard: View {
    let task: TaskItem
    let selectedSession: WorkSession?
    let sessionsCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Task Focus")
                        .font(.custom("Helvetica Neue", size: 16).weight(.bold))
                    Text(task.name)
                        .font(.custom("Helvetica Neue", size: 20).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(task.contextSummary.isEmpty ? "Standalone Task" : task.contextSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let status = task.computedStatus(selectedTaskID: task.id)
                StatusBadge(text: status.rawValue, color: GoalTrackerTheme.background(for: status))
            }

            if let selectedSession {
                HStack(alignment: .top, spacing: 12) {
                    SessionStatusCircle(status: selectedSession.status, size: 22)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Session")
                            .font(.custom("Helvetica Neue", size: 14).weight(.bold))
                        SessionStudyGrid(session: selectedSession)
                    }
                }
            } else if sessionsCount == 0 {
                Label {
                    Text("No session has been created for this selected task.")
                } icon: {
                    Image(systemName: "circle.dotted")
                        .foregroundStyle(GoalTrackerTheme.moduleIconRed)
                }
                    .font(.custom("Helvetica Neue", size: 14).weight(.semibold))
                    .foregroundStyle(Color.black)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GoalTrackerTheme.creamWork)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Label("All sessions are completed for this selected task.", systemImage: "checkmark.circle")
                    .font(.custom("Helvetica Neue", size: 14).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .goalCard()
        .overlay(alignment: .top) {
            Rectangle()
                .fill(GoalTrackerTheme.appYellow)
                .frame(height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct DashboardMilestoneRow: View {
    let milestone: Milestone

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.name)
                    .fontWeight(.bold)
                Text("\(milestone.goalName) | \(DateUtils.displayDate(milestone.startDate)) - \(DateUtils.displayDate(milestone.endDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: "\(Formatters.percent(milestone.computedProgress)) \(milestone.status.rawValue)", color: GoalTrackerTheme.background(for: milestone.status))
        }
    }
}

private struct DashboardTaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .fontWeight(.bold)
                Text(task.contextSummary.isEmpty ? "Standalone Task" : task.contextSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatusBadge(text: task.taskType.rawValue, color: task.taskType == .deep ? GoalTrackerTheme.appYellow.opacity(0.75) : GoalTrackerTheme.neutral)
        }
    }
}

private struct DashboardSessionRow: View {
    let session: WorkSession
    let prefix: String

    var body: some View {
        HStack(spacing: 8) {
            SessionStatusCircle(status: session.status)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(prefix): \(session.taskName)")
                    .fontWeight(.bold)
                Text(session.contextSummary.isEmpty ? Formatters.minutes(session.actualMinutesValue) : "\(Formatters.minutes(session.actualMinutesValue)) | \(session.contextSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct MetricsStrip: View {
    let completedSessionsThisMonth: Int
    let actualMinutesThisMonth: Int
    let deepTasks: Int
    let shallowTasks: Int
    let completedTasks: Int
    let activeTasks: Int
    let currentStreak: Int
    let bestStreak: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            MetricCard(title: "Completed Sessions", value: "\(completedSessionsThisMonth)", detail: "This month")
            MetricCard(title: "Actual Minutes", value: "\(actualMinutesThisMonth)", detail: "This month")
            MetricCard(title: "Deep / Shallow", value: "\(deepTasks) / \(shallowTasks)", detail: "Task ratio")
            MetricCard(title: "Tasks", value: "\(activeTasks) / \(completedTasks)", detail: "Active / completed")
            MetricCard(title: "Current Streak", value: "\(currentStreak)", detail: "days")
            MetricCard(title: "Best Streak", value: "\(bestStreak)", detail: "days")
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .goalCard()
    }
}

private struct ChartDatum: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
}

private struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
                .frame(height: 220)
        }
        .goalCard()
    }
}

private struct PieChart: View {
    let data: [ChartDatum]

    private var chartData: [ChartDatum] {
        data.filter { $0.count > 0 }
    }

    var body: some View {
        if chartData.isEmpty {
            EmptyStateView(systemImage: "chart.pie", title: "No data yet.", message: "Charts appear after Tasks and Sessions exist.")
        } else {
            Chart(chartData) { item in
                SectorMark(angle: .value("Count", item.count))
                    .foregroundStyle(by: .value("Type", item.label))
            }
            .chartLegend(position: .bottom)
        }
    }
}

private struct GoalsProgressChart: View {
    let goals: [Goal]
    let priorities: [UUID: ComputedPriority]

    var body: some View {
        if !goals.isEmpty {
            Chart {
                ForEach(goals) { goal in
                    BarMark(
                        x: .value("Progress", goal.computedProgress),
                        y: .value("Goal", goal.name)
                    )
                    .foregroundStyle(by: .value("Priority", (priorities[goal.id] ?? .none).displayName))
                }
                RuleMark(x: .value("Complete", 100))
                    .foregroundStyle(.secondary)
            }
            .chartXScale(domain: 0...100)
        } else {
            EmptyStateView(systemImage: "chart.bar", title: "No Goals yet.", message: "Add Goals to see progress.")
        }
    }
}

private enum StreakMetrics {
    static func currentStreak(from sessions: [WorkSession]) -> Int {
        let days = activeDays(from: sessions)
        var cursor = Calendar.current.startOfDay(for: Date())
        var count = 0

        while days.contains(cursor) {
            count += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor.addingTimeInterval(-86_400)
        }

        return count
    }

    static func bestStreak(from sessions: [WorkSession]) -> Int {
        let sortedDays = activeDays(from: sessions).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1

        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let currentDay = sortedDays[index]
            let delta = Calendar.current.dateComponents([.day], from: previous, to: currentDay).day ?? 0
            if delta == 1 {
                current += 1
            } else {
                best = max(best, current)
                current = 1
            }
        }

        return max(best, current)
    }

    private static func activeDays(from sessions: [WorkSession]) -> Set<Date> {
        Set(
            sessions
                .filter { $0.status == .completed || $0.status == .partial }
                .compactMap(\.sessionDate)
                .map { Calendar.current.startOfDay(for: $0) }
        )
    }
}
