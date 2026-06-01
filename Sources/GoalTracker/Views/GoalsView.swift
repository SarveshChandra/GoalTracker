import CoreData
import SwiftUI

struct GoalsView: View {
    let filters: GoalTrackerGlobalFilters
    let selectionActions: GoalTrackerSelectionActions

    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingGoal: Goal?
    @State private var deleteCandidate: Goal?
    @State private var goalRefreshID = 0

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: Array(goals))
    }

    private var filteredGoals: [Goal] {
        let priorities = goalPriorities
        return goals
            .filter(goalMatchesSearch)
            .sorted { GoalTrackerSort.goals($0, $1, priorities: priorities) }
    }

    private func goalMatchesSearch(_ goal: Goal) -> Bool {
        searchText.isEmpty ||
        goal.name.localizedCaseInsensitiveContains(searchText) ||
        goal.coreValueNames.localizedCaseInsensitiveContains(searchText) ||
        goal.antiGoal.localizedCaseInsensitiveContains(searchText) ||
        goal.sacrifice.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Goals Sheet",
                subtitle: ""
            ) {
                HStack(spacing: 8) {
                    SheetHeaderSearchField(text: $searchText, prompt: "Search Goals")

                    Button {
                        editingGoal = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(GoalTrackerDimIconButtonStyle())
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Add Goal")
                }
            }

            if filteredGoals.isEmpty {
                EmptyStateView(
                    systemImage: "scope",
                    title: "No Goals yet.",
                    message: "Add a Goal. Priority is computed from dates, pace, progress, and completion risk.",
                    iconColor: GoalTrackerTheme.moduleIconRed.opacity(0.52)
                )
            } else {
                goalTable
                    .id(goalRefreshID)
            }
        }
        .padding(24)
        .sheet(isPresented: $showEditor) {
            GoalEditor(goal: nil, onSave: refreshGoalRows)
        }
        .sheet(item: $editingGoal) { goal in
            GoalEditor(goal: goal, onSave: refreshGoalRows)
        }
        .confirmationDialog("Delete Goal?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleteCandidate {
                    deleteGoal(deleteCandidate)
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("This also deletes related Milestones, Tasks, and Sessions.")
        }
    }

    private var goalTable: some View {
        FixedFeatureTable(fixedColumnWidth: GoalColumns.name, contentHeight: tableContentHeight) {
            HeaderCell(text: "Goal", width: GoalColumns.name)
        } fixedRows: {
            ForEach(filteredGoals) { goal in
                let rowHeight = rowHeight(for: goal)
                let isLockedOut = filters.isLockedOut(goal: goal)
                DataCell(text: goal.name, width: GoalColumns.name, bold: true)
                    .environment(\.goalTrackerTableRowHeight, rowHeight)
                    .background(GoalTrackerTheme.tableRowBackground(for: goal.status))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                    }
                    .opacity(GoalTrackerFocusRowStyle.opacity(isLockedOut: isLockedOut))
            }
        } scrollHeader: {
            HStack(spacing: 0) {
                HeaderCell(text: "Core Values", width: GoalColumns.coreValues)
                HeaderCell(text: "Priority", width: GoalColumns.priority)
                HeaderCell(text: "Start Date", width: GoalColumns.startDate)
                HeaderCell(text: "Due Date", width: GoalColumns.endDate)
                HeaderCell(text: "Time Horizon", width: GoalColumns.timeHorizon)
                HeaderCell(text: "Progress %", width: GoalColumns.progress)
                HeaderCell(text: "Status", width: GoalColumns.status)
                HeaderCell(text: "Anti-Goal", width: GoalColumns.antiGoal)
                HeaderCell(text: "Sacrifice", width: GoalColumns.sacrifice)
                HeaderCell(text: "", width: GoalColumns.actions)
            }
        } scrollRows: {
            ForEach(filteredGoals) { goal in
                let rowHeight = rowHeight(for: goal)
                let isLockedOut = filters.isLockedOut(goal: goal)
                HStack(spacing: 0) {
                    let priority = priority(for: goal)
                    DataCell(text: goal.coreValueNames, width: GoalColumns.coreValues)
                    DataCell(
                        text: priority.displayName,
                        width: GoalColumns.priority,
                        bold: PriorityTextStyle.usesBoldWeight(priority.displayName),
                        computed: true
                    )
                    DataCell(text: DateUtils.displayDate(goal.startDate), width: GoalColumns.startDate)
                    DataCell(text: DateUtils.displayDate(goal.endDate), width: GoalColumns.endDate)
                    NumberCell(text: goal.timeHorizon, width: GoalColumns.timeHorizon)
                    ProgressCell(value: goal.computedProgress, width: GoalColumns.progress)
                    StatusCell(text: goal.status.rawValue, color: GoalTrackerTheme.background(for: goal.status), width: GoalColumns.status)
                    DataCell(text: goal.antiGoal, width: GoalColumns.antiGoal)
                    DataCell(text: goal.sacrifice, width: GoalColumns.sacrifice)
                    let isSelected = filters.goalID == goal.id
                    TableActionsCell(
                        edit: {
                            editingGoal = goal
                        },
                        delete: {
                            requestDelete(goal)
                        },
                        isEnabled: !isLockedOut,
                        selectTitle: isSelected ? "Deselect Goal" : "Select Goal",
                        selectImage: isSelected ? "xmark.circle" : "target",
                        select: {
                            if isSelected {
                                selectionActions.clearGoal()
                            } else {
                                selectionActions.selectGoal(goal)
                            }
                        }
                    )
                }
                .environment(\.goalTrackerTableRowHeight, rowHeight)
                .background(GoalTrackerTheme.tableRowBackground(for: goal.status))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                }
                .opacity(GoalTrackerFocusRowStyle.opacity(isLockedOut: isLockedOut))
            }
        }
    }

    private func rowHeight(for goal: Goal) -> CGFloat {
        let priority = priority(for: goal)
        return TableMetrics.rowHeight(for: [
            (goal.name, GoalColumns.name),
            (goal.coreValueNames, GoalColumns.coreValues),
            (priority.displayName, GoalColumns.priority),
            (DateUtils.displayDate(goal.startDate), GoalColumns.startDate),
            (DateUtils.displayDate(goal.endDate), GoalColumns.endDate),
            (goal.timeHorizon, GoalColumns.timeHorizon),
            (goal.status.rawValue, GoalColumns.status),
            (goal.antiGoal, GoalColumns.antiGoal),
            (goal.sacrifice, GoalColumns.sacrifice)
        ])
    }

    private func priority(for goal: Goal) -> ComputedPriority {
        goalPriorities[goal.id] ?? GoalPriorityService.standalonePriority(for: goal)
    }

    private var tableContentHeight: CGFloat {
        TableMetrics.headerHeight + filteredGoals.reduce(CGFloat(0)) { total, goal in
            total + rowHeight(for: goal)
        }
    }

    private func requestDelete(_ goal: Goal) {
        if confirmBeforeDelete {
            deleteCandidate = goal
        } else {
            deleteGoal(goal)
        }
    }

    private func deleteGoal(_ goal: Goal) {
        RelationshipRefreshService.touchGoalCascade(goal)
        managedObjectContext.delete(goal)
        try? managedObjectContext.save()
        refreshGoalRows()
    }

    private func refreshGoalRows() {
        managedObjectContext.processPendingChanges()
        goalRefreshID &+= 1
    }
}

private enum GoalColumns {
    static let name = TableMetrics.columnWidth("Goal", min: 240)
    static let coreValues = TableMetrics.columnWidth("Core Values", min: 190)
    static let priority = TableMetrics.columnWidth("Priority", min: 100)
    static let startDate = TableMetrics.columnWidth("Start Date", min: 100)
    static let endDate = TableMetrics.columnWidth("Due Date", min: 100)
    static let timeHorizon = TableMetrics.columnWidth("Time Horizon", min: 120)
    static let progress = TableMetrics.columnWidth("Progress %", min: 140)
    static let status = TableMetrics.columnWidth("Status", min: 130)
    static let antiGoal = TableMetrics.columnWidth("Anti-Goal", min: 220)
    static let sacrifice = TableMetrics.columnWidth("Sacrifice", min: 220)
    static let actions: CGFloat = TableMetrics.actionColumnWidth
}

private struct GoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var values: FetchedResults<CoreValue>

    let goal: Goal?
    let onSave: () -> Void
    @State private var name: String
    @State private var selectedValueIDs: Set<UUID>
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var antiGoal: String
    @State private var sacrifice: String
    @State private var error: String?

    init(goal: Goal?, onSave: @escaping () -> Void = {}) {
        self.goal = goal
        self.onSave = onSave
        _name = State(initialValue: goal?.name ?? "")
        _selectedValueIDs = State(initialValue: Set(goal?.coreValues.map(\.id) ?? []))
        _startDate = State(initialValue: goal?.startDate ?? Date())
        _endDate = State(initialValue: goal?.endDate ?? (Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()))
        _antiGoal = State(initialValue: goal?.antiGoal ?? "")
        _sacrifice = State(initialValue: goal?.sacrifice ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(goal == nil ? "Add Goal" : "Edit Goal")
                .font(.title2.weight(.bold))

            TextField("Goal Name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("Due Date", selection: $endDate, displayedComponents: .date)
                    ReadOnlyField(title: "Time Horizon", value: DateUtils.humanDuration(from: startDate, to: endDate))
                }
                .frame(width: 260)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Core Value / Core Values")
                        .foregroundStyle(.secondary)
                    List(values.sorted { $0.name < $1.name }) { value in
                        Toggle(value.name, isOn: Binding(
                            get: { selectedValueIDs.contains(value.id) },
                            set: { isOn in
                                if isOn {
                                    selectedValueIDs.insert(value.id)
                                } else {
                                    selectedValueIDs.remove(value.id)
                                }
                            }
                        ))
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
            }

            GoalLongTextBox(title: "Anti-Goal", text: $antiGoal)
            GoalLongTextBox(title: "Sacrifice", text: $sacrifice)

            FormErrorText(message: error)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 660)
    }

    private func save() {
        if let validation = ValidationService.validateGoal(name: name, startDate: startDate, dueDate: endDate) {
            error = validation
            return
        }

        let selectedValues = values.filter { selectedValueIDs.contains($0.id) }
        let target: Goal
        let previousValues = goal?.coreValues ?? []
        if let goal {
            target = goal
        } else {
            target = Goal(context: managedObjectContext, name: name)
        }

        let now = Date()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.startDate = startDate
        target.endDate = endDate
        target.antiGoal = antiGoal
        target.sacrifice = sacrifice
        target.coreValues = Set(selectedValues)
        target.updatedAt = now
        (previousValues.union(Set(selectedValues))).forEach { $0.updatedAt = now }

        ValidationService.clampMilestonesToGoalDateRange(target)
        RelationshipRefreshService.touchGoalCascade(target, now: now)
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

private struct GoalLongTextBox: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Helvetica Neue", size: 12).weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.72))

            TextEditor(text: $text)
                .font(.custom("Helvetica Neue", size: 13))
                .foregroundStyle(Color.black)
                .lineSpacing(3)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 92)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
