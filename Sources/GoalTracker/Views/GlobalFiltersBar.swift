import CoreData
import SwiftUI

struct GoalTrackerGlobalFilters {
    let goalID: UUID?
    let milestoneID: UUID?
    let taskID: UUID?

    var hasActiveSelection: Bool {
        goalID != nil || milestoneID != nil || taskID != nil
    }

    func includes(goal: Goal) -> Bool {
        guard let goalID else { return true }
        return goal.id == goalID
    }

    func includes(milestone: Milestone) -> Bool {
        if let goalID, milestone.goal?.id != goalID { return false }
        if let milestoneID, milestone.id != milestoneID { return false }
        return true
    }

    func includes(task: TaskItem) -> Bool {
        if let goalID, task.milestone?.goal?.id != goalID { return false }
        if let milestoneID, task.milestone?.id != milestoneID { return false }
        if let taskID, task.id != taskID { return false }
        return true
    }

    func includes(session: WorkSession) -> Bool {
        guard let task = session.task else {
            return goalID == nil && milestoneID == nil && taskID == nil
        }
        return includes(task: task)
    }

    func isLockedOut(goal: Goal) -> Bool {
        guard hasActiveSelection else { return false }
        guard let goalID else { return true }
        return goal.id != goalID
    }

    func isLockedOut(milestone: Milestone) -> Bool {
        guard hasActiveSelection else { return false }
        if let milestoneID {
            return milestone.id != milestoneID
        }
        if let goalID {
            return milestone.goal?.id != goalID
        }
        return true
    }

    func isLockedOut(task: TaskItem) -> Bool {
        guard hasActiveSelection else { return false }
        if let taskID {
            return task.id != taskID
        }
        if let milestoneID {
            return task.milestone?.id != milestoneID
        }
        if let goalID {
            return task.milestone?.goal?.id != goalID
        }
        return true
    }

    func isLockedOut(session: WorkSession) -> Bool {
        guard hasActiveSelection else { return false }
        guard let task = session.task else { return true }
        return isLockedOut(task: task)
    }
}

enum GoalTrackerFocusRowStyle {
    static let lockedOpacity = 0.16

    static func opacity(isLockedOut: Bool) -> Double {
        isLockedOut ? lockedOpacity : 1
    }
}

struct GoalTrackerSelectionActions {
    let selectGoal: (Goal) -> Void
    let selectMilestone: (Milestone) -> Void
    let selectTask: (TaskItem) -> Void
    let clearGoal: () -> Void
    let clearMilestone: () -> Void
    let clearTask: () -> Void
}

private enum FilterBarMetrics {
    static let minimumFilterWidth: CGFloat = 180
}

struct GlobalFiltersBar: View {
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @FetchRequest(sortDescriptors: []) private var milestones: FetchedResults<Milestone>
    @FetchRequest(sortDescriptors: []) private var tasks: FetchedResults<TaskItem>

    @Binding var selectedGoalIDRaw: String
    @Binding var selectedMilestoneIDRaw: String
    @Binding var selectedTaskIDRaw: String

    private var selectedGoalID: UUID? { UUID(uuidString: selectedGoalIDRaw) }
    private var selectedMilestoneID: UUID? { UUID(uuidString: selectedMilestoneIDRaw) }
    private var selectedTaskID: UUID? { UUID(uuidString: selectedTaskIDRaw) }

    private var selectedGoal: Goal? {
        guard let selectedGoalID else { return nil }
        return goals.first { $0.id == selectedGoalID }
    }

    private var selectedMilestone: Milestone? {
        guard let selectedMilestoneID else { return nil }
        return milestones.first { $0.id == selectedMilestoneID }
    }

    private var selectedTask: TaskItem? {
        guard let selectedTaskID else { return nil }
        return tasks.first { $0.id == selectedTaskID }
    }

    private var selectedStandaloneTask: Bool {
        selectedTask?.isStandalone == true
    }

    private var selectedSession: WorkSession? {
        SessionFocusService.firstIncompleteSession(for: selectedTask)
    }

    var body: some View {
        barContent
            .frame(maxWidth: .infinity, alignment: .center)
            .onAppear(perform: synchronizeSelections)
            .onChange(of: selectedGoalIDRaw) { _, _ in
                synchronizeGoalSelection()
            }
            .onChange(of: selectedMilestoneIDRaw) { _, _ in
                synchronizeMilestoneSelection()
            }
            .onChange(of: selectedTaskIDRaw) { _, _ in
                synchronizeTaskSelection()
            }
            .onChange(of: optionSignature) { _, _ in
                synchronizeSelections()
            }
    }

    private var barContent: some View {
        filterFields
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var filterFields: some View {
        HStack(alignment: .top, spacing: 12) {
            FocusPlaceholderField(
                systemImage: "scope",
                text: selectedGoal?.name ?? (selectedStandaloneTask ? "No Goal" : "Selected Goal"),
                isSelected: selectedGoal != nil
            )
            .frame(minWidth: FilterBarMetrics.minimumFilterWidth, maxWidth: .infinity)

            FocusPlaceholderField(
                systemImage: "flag",
                text: selectedMilestone?.name ?? (selectedStandaloneTask ? "No Milestone" : "Selected Milestone"),
                isSelected: selectedMilestone != nil
            )
            .frame(minWidth: FilterBarMetrics.minimumFilterWidth, maxWidth: .infinity)

            FocusPlaceholderField(
                systemImage: "checklist",
                text: selectedTask?.name ?? "Selected Task",
                isSelected: selectedTask != nil
            )
            .frame(minWidth: FilterBarMetrics.minimumFilterWidth, maxWidth: .infinity)

            FocusPlaceholderField(
                systemImage: "record.circle",
                text: selectedSessionText,
                isSelected: selectedSession != nil
            )
            .frame(minWidth: FilterBarMetrics.minimumFilterWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
    }

    private var selectedSessionText: String {
        guard selectedTask != nil else { return "Selected Session" }
        if let selectedSession {
            return selectedSession.displayLabel
        }
        if selectedTask?.activeSessions.isEmpty == true {
            return "No Session"
        }
        return "All Sessions Completed"
    }

    private var optionSignature: String {
        let goalIDs = goals.map { $0.id.uuidString }.joined(separator: ",")
        let milestoneIDs = milestones.map { $0.id.uuidString }.joined(separator: ",")
        let taskIDs = tasks.map { $0.id.uuidString }.joined(separator: ",")
        return "\(goalIDs)|\(milestoneIDs)|\(taskIDs)"
    }

    private func synchronizeSelections() {
        if !selectedTaskIDRaw.isEmpty {
            synchronizeTaskSelection()
        }

        if !selectedMilestoneIDRaw.isEmpty {
            synchronizeMilestoneSelection()
        }

        synchronizeGoalSelection()
    }

    private func synchronizeGoalSelection() {
        if selectedGoalIDRaw.isEmpty {
            selectedMilestoneIDRaw = ""
            if selectedTask?.milestone != nil {
                selectedTaskIDRaw = ""
            }
            return
        }

        if !selectedGoalIDRaw.isEmpty && selectedGoal == nil {
            selectedGoalIDRaw = ""
            selectedMilestoneIDRaw = ""
            selectedTaskIDRaw = ""
            return
        }

        if let selectedGoalID {
            if let selectedMilestone, selectedMilestone.goal?.id != selectedGoalID {
                selectedMilestoneIDRaw = ""
                selectedTaskIDRaw = ""
            }
            if let selectedTask, selectedTask.milestone?.goal?.id != selectedGoalID {
                selectedTaskIDRaw = ""
            }
        }
    }

    private func synchronizeMilestoneSelection() {
        guard !selectedMilestoneIDRaw.isEmpty else {
            if selectedTask?.milestone != nil {
                selectedTaskIDRaw = ""
            }
            return
        }

        guard let selectedMilestone else {
            selectedMilestoneIDRaw = ""
            selectedTaskIDRaw = ""
            return
        }

        if let goal = selectedMilestone.goal {
            selectedGoalIDRaw = goal.id.uuidString
        }

        if let selectedTask, selectedTask.milestone?.id != selectedMilestone.id {
            selectedTaskIDRaw = ""
        }
    }

    private func synchronizeTaskSelection() {
        if let task = selectedTask {
            if let milestone = task.milestone {
                selectedMilestoneIDRaw = milestone.id.uuidString
                if let goal = milestone.goal {
                    selectedGoalIDRaw = goal.id.uuidString
                }
            } else {
                selectedGoalIDRaw = ""
                selectedMilestoneIDRaw = ""
            }
        } else if !selectedTaskIDRaw.isEmpty {
            selectedTaskIDRaw = ""
        }
    }
}

private struct FocusPlaceholderField: View {
    let systemImage: String
    let text: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(GoalTrackerTheme.moduleIconRed.opacity(isSelected ? 1 : 0.34))
                .frame(width: 18, height: TableMetrics.focusPlaceholderHeight, alignment: .center)

            Text(text)
                .font(.custom("Helvetica Neue", size: 12).weight(.semibold))
                .foregroundStyle(Color.black.opacity(isSelected ? 0.92 : 0.36))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: TableMetrics.focusPlaceholderHeight, maxHeight: TableMetrics.focusPlaceholderHeight, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .frame(height: TableMetrics.focusPlaceholderHeight, alignment: .center)
        .background(Color(nsColor: .textBackgroundColor).opacity(isSelected ? 0.86 : 0.48))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(isSelected ? 0.14 : 0.06), lineWidth: 1)
        )
        .help(text)
    }
}
