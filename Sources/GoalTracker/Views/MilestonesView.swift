import CoreData
import SwiftUI

struct MilestonesView: View {
    let filters: GoalTrackerGlobalFilters
    let selectionActions: GoalTrackerSelectionActions

    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var milestones: FetchedResults<Milestone>
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingMilestone: Milestone?
    @State private var deleteCandidate: Milestone?
    @State private var milestoneRefreshID = 0
    @State private var availableScrollTargetID: UUID?
    @State private var availableScrollNonce = 0
    @State private var availableSetCursor = -1

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: milestones.compactMap(\.goal))
    }

    private var filteredMilestones: [Milestone] {
        let priorities = goalPriorities
        return milestones
            .filter(milestoneMatchesSearch)
            .sorted { GoalTrackerSort.milestones($0, $1, priorities: priorities) }
    }

    private func milestoneMatchesSearch(_ milestone: Milestone) -> Bool {
        searchText.isEmpty ||
        milestone.name.localizedCaseInsensitiveContains(searchText) ||
        milestone.goalName.localizedCaseInsensitiveContains(searchText) ||
        milestone.coreValueName.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Milestones Sheet",
                subtitle: ""
            ) {
                HStack(spacing: 8) {
                    SheetHeaderSearchField(text: $searchText, prompt: "Search Milestones")

                    if shouldShowFindAvailableButton {
                        GoalTrackerFindAvailableButton {
                            scrollToNextAvailableMilestoneSet()
                        }
                    }

                    Button {
                        editingMilestone = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(GoalTrackerDimIconButtonStyle())
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Add Milestone")
                }
            }

            if filteredMilestones.isEmpty {
                EmptyStateView(
                    systemImage: "flag",
                    title: "No Milestones.",
                    message: "Create Milestones to make Goal progress visible.",
                    iconColor: GoalTrackerTheme.moduleIconRed.opacity(0.52)
                )
            } else {
                milestoneTable
                    .id(milestoneRefreshID)
            }
        }
        .padding(24)
        .sheet(isPresented: $showEditor) {
            MilestoneEditor(milestone: nil, defaultGoalID: filters.goalID, onSave: refreshMilestoneRows)
        }
        .sheet(item: $editingMilestone) { milestone in
            MilestoneEditor(milestone: milestone, onSave: refreshMilestoneRows)
        }
        .confirmationDialog("Delete Milestone?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleteCandidate {
                    deleteMilestone(deleteCandidate)
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("This also deletes related Tasks and Sessions.")
        }
    }

    private var milestoneTable: some View {
        FixedFeatureTable(
            fixedColumnWidth: MilestoneColumns.name,
            contentHeight: tableContentHeight,
            scrollTarget: availableScrollTarget
        ) {
            HeaderCell(text: "Milestone", width: MilestoneColumns.name)
        } fixedRows: {
            ForEach(filteredMilestones) { milestone in
                let rowHeight = rowHeight(for: milestone)
                let isLockedOut = filters.isLockedOut(milestone: milestone)
                DataCell(text: milestone.name, width: MilestoneColumns.name, bold: true)
                    .environment(\.goalTrackerTableRowHeight, rowHeight)
                    .background(GoalTrackerTheme.tableRowBackground(for: milestone.status))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                    }
                    .opacity(GoalTrackerFocusRowStyle.opacity(isLockedOut: isLockedOut))
                    .id(milestone.id)
            }
        } scrollHeader: {
            HStack(spacing: 0) {
                HeaderCell(text: "Core Values", width: MilestoneColumns.coreValue)
                HeaderCell(text: "Goal", width: MilestoneColumns.goal)
                HeaderCell(text: "Priority", width: MilestoneColumns.priority)
                HeaderCell(text: "Start Date", width: MilestoneColumns.startDate)
                HeaderCell(text: "Due Date", width: MilestoneColumns.endDate)
                HeaderCell(text: "Duration", width: MilestoneColumns.duration)
                HeaderCell(text: "Progress %", width: MilestoneColumns.progress)
                HeaderCell(text: "Status", width: MilestoneColumns.status)
                HeaderCell(text: "", width: MilestoneColumns.actions)
            }
        } scrollRows: {
            ForEach(filteredMilestones) { milestone in
                let rowHeight = rowHeight(for: milestone)
                let isLockedOut = filters.isLockedOut(milestone: milestone)
                HStack(spacing: 0) {
                    DataCell(text: milestone.coreValueName, width: MilestoneColumns.coreValue, computed: true)
                    DataCell(text: milestone.goalName, width: MilestoneColumns.goal)
                    let priority = priorityText(for: milestone)
                    DataCell(text: priority, width: MilestoneColumns.priority, bold: PriorityTextStyle.usesBoldWeight(priority), computed: true)
                    DataCell(text: DateUtils.displayDate(milestone.startDate), width: MilestoneColumns.startDate)
                    DataCell(text: DateUtils.displayDate(milestone.endDate), width: MilestoneColumns.endDate)
                    NumberCell(text: milestone.duration, width: MilestoneColumns.duration)
                    ProgressCell(value: milestone.computedProgress, width: MilestoneColumns.progress)
                    StatusCell(text: milestone.status.rawValue, color: GoalTrackerTheme.background(for: milestone.status), width: MilestoneColumns.status)
                    let isSelected = filters.milestoneID == milestone.id
                    TableActionsCell(
                        edit: {
                            editingMilestone = milestone
                        },
                        delete: {
                            requestDelete(milestone)
                        },
                        isEnabled: !isLockedOut,
                        selectTitle: isSelected ? "Deselect Milestone" : "Select Milestone",
                        selectImage: isSelected ? "xmark.circle" : "flag.fill",
                        select: {
                            if isSelected {
                                selectionActions.clearMilestone()
                            } else {
                                selectionActions.selectMilestone(milestone)
                            }
                        }
                    )
                }
                .environment(\.goalTrackerTableRowHeight, rowHeight)
                .background(GoalTrackerTheme.tableRowBackground(for: milestone.status))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                }
                .opacity(GoalTrackerFocusRowStyle.opacity(isLockedOut: isLockedOut))
            }
        }
    }

    private func rowHeight(for milestone: Milestone) -> CGFloat {
        TableMetrics.rowHeight(for: [
            (milestone.name, MilestoneColumns.name),
            (milestone.coreValueName, MilestoneColumns.coreValue),
            (milestone.goalName, MilestoneColumns.goal),
            (priorityText(for: milestone), MilestoneColumns.priority),
            (DateUtils.displayDate(milestone.startDate), MilestoneColumns.startDate),
            (DateUtils.displayDate(milestone.endDate), MilestoneColumns.endDate),
            (milestone.duration, MilestoneColumns.duration),
            (milestone.status.rawValue, MilestoneColumns.status)
        ])
    }

    private var tableContentHeight: CGFloat {
        TableMetrics.headerHeight + filteredMilestones.reduce(CGFloat(0)) { total, milestone in
            total + rowHeight(for: milestone)
        }
    }

    private var shouldShowFindAvailableButton: Bool {
        filteredMilestones.contains { filters.isLockedOut(milestone: $0) } &&
        filteredMilestones.contains { !filters.isLockedOut(milestone: $0) }
    }

    private var availableScrollTarget: TableScrollTarget? {
        availableScrollTargetID.map { TableScrollTarget(id: $0, nonce: availableScrollNonce) }
    }

    private func scrollToNextAvailableMilestoneSet() {
        let setStarts = availableMilestoneSetStartIDs()
        guard !setStarts.isEmpty else { return }
        if availableSetCursor >= setStarts.count {
            availableSetCursor = -1
        }
        availableSetCursor = (availableSetCursor + 1) % setStarts.count
        availableScrollNonce &+= 1
        availableScrollTargetID = setStarts[availableSetCursor]
    }

    private func requestDelete(_ milestone: Milestone) {
        if confirmBeforeDelete {
            deleteCandidate = milestone
        } else {
            deleteMilestone(milestone)
        }
    }

    private func deleteMilestone(_ milestone: Milestone) {
        RelationshipRefreshService.touchMilestoneCascade(milestone)
        managedObjectContext.delete(milestone)
        try? managedObjectContext.save()
        refreshMilestoneRows()
    }

    private func refreshMilestoneRows() {
        managedObjectContext.processPendingChanges()
        milestoneRefreshID &+= 1
    }

    private func priorityText(for milestone: Milestone) -> String {
        guard milestone.status != .completed, let goal = milestone.goal else { return "" }
        return (goalPriorities[goal.id] ?? GoalPriorityService.standalonePriority(for: goal)).displayName
    }

    private func availableMilestoneSetStartIDs() -> [UUID] {
        var result: [UUID] = []
        for (index, milestone) in filteredMilestones.enumerated() {
            guard !filters.isLockedOut(milestone: milestone) else { continue }
            if index == 0 || filters.isLockedOut(milestone: filteredMilestones[index - 1]) {
                result.append(milestone.id)
            }
        }
        return result
    }
}

private enum MilestoneColumns {
    static let name = TableMetrics.columnWidth("Milestone", min: 240)
    static let coreValue = TableMetrics.columnWidth("Core Values", min: 170)
    static let goal = TableMetrics.columnWidth("Goal", min: 220)
    static let priority = TableMetrics.columnWidth("Priority", min: 110)
    static let startDate = TableMetrics.columnWidth("Start Date", min: 100)
    static let endDate = TableMetrics.columnWidth("Due Date", min: 100)
    static let duration = TableMetrics.columnWidth("Duration", min: 110)
    static let progress = TableMetrics.columnWidth("Progress %", min: 140)
    static let status = TableMetrics.columnWidth("Status", min: 130)
    static let actions: CGFloat = TableMetrics.actionColumnWidth
}

private struct MilestoneEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>

    let milestone: Milestone?
    let onSave: () -> Void
    @State private var selectedGoalID: UUID?
    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var error: String?

    init(milestone: Milestone?, defaultGoalID: UUID? = nil, onSave: @escaping () -> Void = {}) {
        self.milestone = milestone
        self.onSave = onSave
        _selectedGoalID = State(initialValue: milestone?.goal?.id ?? defaultGoalID)
        _name = State(initialValue: milestone?.name ?? "")
        _startDate = State(initialValue: milestone?.startDate ?? Date())
        _endDate = State(initialValue: milestone?.endDate ?? (Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()))
    }

    private var selectedGoal: Goal? {
        goals.first { $0.id == selectedGoalID }
    }

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: Array(goals))
    }

    private var selectedGoalDateRange: ClosedRange<Date>? {
        guard let selectedGoal else { return nil }
        return DateUtils.startOfDay(selectedGoal.startDate)...DateUtils.startOfDay(selectedGoal.endDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(milestone == nil ? "Add Milestone" : "Edit Milestone")
                .font(.title2.weight(.bold))

            Picker("Goal", selection: $selectedGoalID) {
                Text("Select Goal").tag(nil as UUID?)
                ForEach(goals.sorted { GoalTrackerSort.goals($0, $1, priorities: goalPriorities) }) { goal in
                    Text("\(goal.name)  |  \(goal.primaryCoreValueName)")
                        .tag(goal.id as UUID?)
                }
            }

            ReadOnlyField(title: "Core Value", value: selectedGoal?.primaryCoreValueName ?? "Select a Goal")

            TextField("Milestone Name", text: $name)
                .textFieldStyle(.roundedBorder)

            milestoneDatePickers

            if let selectedGoal {
                ReadOnlyField(
                    title: "Goal Date Range",
                    value: "\(DateUtils.displayDate(selectedGoal.startDate)) - \(DateUtils.displayDate(selectedGoal.endDate))"
                )
            }

            if let milestone {
                ReadOnlyField(title: "Computed Progress", value: Formatters.percent(milestone.computedProgress))

                HStack {
                    ReadOnlyField(title: "Duration", value: DateUtils.humanDuration(from: startDate, to: endDate))
                    ReadOnlyField(title: "Computed Status", value: StatusCalculator.milestoneStatus(progress: milestone.computedProgress, startDate: startDate, endDate: endDate).rawValue)
                }
            } else {
                ReadOnlyField(title: "Duration", value: DateUtils.humanDuration(from: startDate, to: endDate))
            }

            FormErrorText(message: error)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 560)
        .onAppear(perform: clampMilestoneDatesToGoal)
        .onChange(of: selectedGoalID) { _, _ in
            clampMilestoneDatesToGoal()
        }
        .onChange(of: startDate) { _, _ in
            clampMilestoneDatesToGoal()
        }
        .onChange(of: endDate) { _, _ in
            clampMilestoneDatesToGoal()
        }
    }

    @ViewBuilder
    private var milestoneDatePickers: some View {
        if let selectedGoalDateRange {
            DatePicker("Start Date", selection: $startDate, in: selectedGoalDateRange, displayedComponents: .date)
            DatePicker("Due Date", selection: $endDate, in: selectedGoalDateRange, displayedComponents: .date)
        } else {
            DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
            DatePicker("Due Date", selection: $endDate, displayedComponents: .date)
        }
    }

    private func clampMilestoneDatesToGoal() {
        var nextStartDate = DateUtils.startOfDay(startDate)
        var nextEndDate = DateUtils.startOfDay(endDate)

        if let range = selectedGoalDateRange {
            nextStartDate = min(max(nextStartDate, range.lowerBound), range.upperBound)
            nextEndDate = min(max(nextEndDate, range.lowerBound), range.upperBound)
        }

        if nextEndDate < nextStartDate {
            nextEndDate = nextStartDate
        }

        if startDate != nextStartDate {
            startDate = nextStartDate
        }

        if endDate != nextEndDate {
            endDate = nextEndDate
        }
    }

    private func save() {
        if let validation = ValidationService.validateMilestone(
            name: name,
            goal: selectedGoal,
            startDate: startDate,
            dueDate: endDate,
            excluding: milestone
        ) {
            error = validation
            return
        }

        let target: Milestone
        let previousGoal = milestone?.goal
        if let milestone {
            target = milestone
        } else {
            target = Milestone(context: managedObjectContext, name: name)
        }

        let now = Date()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.goal = selectedGoal
        target.startDate = startDate
        target.endDate = endDate
        target.updatedAt = now
        RelationshipRefreshService.touchGoalCascade(previousGoal, now: now)
        RelationshipRefreshService.touchMilestoneCascade(target, now: now)

        do {
            try managedObjectContext.save()
            managedObjectContext.processPendingChanges()
            onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
