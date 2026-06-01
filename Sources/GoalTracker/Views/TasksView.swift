import CoreData
import AppKit
import SwiftUI

struct TasksView: View {
    let filters: GoalTrackerGlobalFilters
    let selectionActions: GoalTrackerSelectionActions

    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage("GoalTracker.tasksStandaloneOnly") private var standaloneOnly = false
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingTask: TaskItem?
    @State private var deleteCandidate: TaskItem?
    @State private var rowHeightCache = TaskRowHeightCache()
    @State private var taskRefreshID = 0
    @State private var findAvailableRequest = 0

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: Array(goals))
    }

    private var taskRows: [TaskRowSnapshot] {
        let priorities = goalPriorities
        let rows = tasks
            .filter(taskMatchesSearch)
            .map { makeRowSnapshot(for: $0, goalPriorities: priorities) }
        return rows.sorted(by: TaskRowSnapshot.sortPrecedes)
    }

    private func taskMatchesSearch(_ task: TaskItem) -> Bool {
        searchText.isEmpty ||
        task.name.localizedCaseInsensitiveContains(searchText) ||
        task.goalName.localizedCaseInsensitiveContains(searchText) ||
        task.milestoneName.localizedCaseInsensitiveContains(searchText) ||
        task.coreValueName.localizedCaseInsensitiveContains(searchText) ||
        task.taskDescription.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        content(rows: taskRows)
            .padding(24)
            .sheet(isPresented: $showEditor) {
                TaskEditor(task: nil, defaultMilestoneID: filters.milestoneID, selectedTaskID: filters.taskID, onSave: refreshTaskRows)
            }
            .sheet(item: $editingTask) { task in
                TaskEditor(task: task, selectedTaskID: filters.taskID, onSave: refreshTaskRows)
            }
            .confirmationDialog("Delete Task?", isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let deleteCandidate {
                        deleteTask(deleteCandidate)
                    }
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("This permanently deletes the Task.")
            }
    }

    private func content(rows: [TaskRowSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Tasks Sheet",
                subtitle: ""
            ) {
                HStack(spacing: 8) {
                    SheetHeaderSearchField(text: $searchText, prompt: "Search Tasks")

                    Button {
                        standaloneOnly.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: standaloneOnly ? "checkmark.square.fill" : "square")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Standalone Only")
                                .font(.custom("Helvetica Neue", size: 12).weight(.medium))
                        }
                    }
                    .buttonStyle(GoalTrackerStandaloneToggleButtonStyle(isOn: standaloneOnly))
                    .help("Keep standalone tasks active and lock other task rows")

                    if shouldShowFindAvailableButton(rows: rows) {
                        GoalTrackerFindAvailableButton {
                            findAvailableRequest &+= 1
                        }
                    }

                    Button {
                        editingTask = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(GoalTrackerDimIconButtonStyle())
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Add Task")
                }
            }

            if rows.isEmpty {
                EmptyStateView(
                    systemImage: "checklist",
                    title: "No active tasks.",
                    message: "Select a Task to make it Active.",
                    iconColor: GoalTrackerTheme.moduleIconRed.opacity(0.52)
                )
            } else {
                taskTable(rows: rows)
                    .id(taskRefreshID)
            }
        }
    }

    private func taskTable(rows: [TaskRowSnapshot]) -> some View {
        GeometryReader { proxy in
            TaskAppKitTable(
                rows: rows,
                findAvailableRequest: findAvailableRequest,
                edit: { task in
                    editingTask = task
                },
                delete: { task in
                    requestDelete(task)
                },
                select: { row in
                    if row.isSelected {
                        selectionActions.clearTask()
                    } else {
                        selectionActions.selectTask(row.task)
                    }
                }
            )
            .frame(
                width: proxy.size.width,
                height: resolvedTableHeight(for: rows, availableHeight: proxy.size.height),
                alignment: .topLeading
            )
            .tableContainer()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func resolvedTableHeight(for rows: [TaskRowSnapshot], availableHeight: CGFloat) -> CGFloat {
        let contentHeight = TableMetrics.headerHeight + rows.reduce(CGFloat(0)) { total, row in
            total + row.height
        }
        let minimumHeight = TableMetrics.headerHeight + TableMetrics.rowHeight
        return min(max(contentHeight, minimumHeight), availableHeight)
    }

    private func makeRowSnapshot(for task: TaskItem, goalPriorities: [UUID: ComputedPriority]) -> TaskRowSnapshot {
        TaskRowSnapshot(
            task: task,
            selectedTaskID: filters.taskID,
            isLockedOut: filters.isLockedOut(task: task) || (standaloneOnly && !task.isStandalone),
            goalPriorities: goalPriorities,
            heightCache: rowHeightCache
        )
    }

    private func shouldShowFindAvailableButton(rows: [TaskRowSnapshot]) -> Bool {
        rows.contains { $0.isLockedOut } && rows.contains { !$0.isLockedOut }
    }

    private func requestDelete(_ task: TaskItem) {
        if confirmBeforeDelete {
            deleteCandidate = task
        } else {
            deleteTask(task)
        }
    }

    private func deleteTask(_ task: TaskItem) {
        let now = Date()
        RelationshipRefreshService.touchTaskCascade(task, now: now)
        managedObjectContext.delete(task)
        try? managedObjectContext.save()
        refreshTaskRows()
    }

    private func refreshTaskRows() {
        managedObjectContext.processPendingChanges()
        rowHeightCache.removeAll()
        taskRefreshID &+= 1
    }
}

private enum TaskColumns {
    static let name = TableMetrics.columnWidth("Task", min: 240)
    static let coreValue = TableMetrics.columnWidth("Core Values", min: 170)
    static let goal = TableMetrics.columnWidth("Goal", min: 220)
    static let milestone = TableMetrics.columnWidth("Milestone", min: 220)
    static let priority = TableMetrics.columnWidth("Priority", min: 100)
    static let status = TableMetrics.columnWidth("Partially Completed", min: 220)
    static let taskType = TableMetrics.columnWidth("Task Type", min: 110)
    static let description = TableMetrics.columnWidth("Task Description", min: 320)
    static let actions: CGFloat = TableMetrics.actionColumnWidth
}

private struct TaskAppKitTable: NSViewRepresentable {
    let rows: [TaskRowSnapshot]
    let findAvailableRequest: Int
    let edit: (TaskItem) -> Void
    let delete: (TaskItem) -> Void
    let select: (TaskRowSnapshot) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, edit: edit, delete: delete, select: select)
    }

    func makeNSView(context: Context) -> TaskSplitTableHost {
        let view = TaskSplitTableHost()
        context.coordinator.attach(to: view)
        view.reloadTables(rowCount: rows.count)
        return view
    }

    func updateNSView(_ nsView: TaskSplitTableHost, context: Context) {
        context.coordinator.update(rows: rows, edit: edit, delete: delete, select: select)
        nsView.reloadTables(rowCount: rows.count)
        if let rowIndex = context.coordinator.nextAvailableSetRowIndex(findAvailableRequest, rows: rows) {
            nsView.scrollToRow(rowIndex)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private var rows: [TaskRowSnapshot]
        private var edit: (TaskItem) -> Void
        private var delete: (TaskItem) -> Void
        private var select: (TaskRowSnapshot) -> Void
        private weak var host: TaskSplitTableHost?
        private var lastFindAvailableRequest = 0
        private var availableSetPointer = -1

        init(
            rows: [TaskRowSnapshot],
            edit: @escaping (TaskItem) -> Void,
            delete: @escaping (TaskItem) -> Void,
            select: @escaping (TaskRowSnapshot) -> Void
        ) {
            self.rows = rows
            self.edit = edit
            self.delete = delete
            self.select = select
        }

        func nextAvailableSetRowIndex(_ request: Int, rows: [TaskRowSnapshot]) -> Int? {
            guard request > 0, request != lastFindAvailableRequest else { return nil }
            lastFindAvailableRequest = request
            let starts = availableSetStartRowIndices(rows: rows)
            guard !starts.isEmpty else { return nil }
            if availableSetPointer >= starts.count {
                availableSetPointer = -1
            }
            availableSetPointer = (availableSetPointer + 1) % starts.count
            return starts[availableSetPointer]
        }

        private func availableSetStartRowIndices(rows: [TaskRowSnapshot]) -> [Int] {
            var result: [Int] = []
            for (index, row) in rows.enumerated() {
                guard !row.isLockedOut else { continue }
                if index == 0 || rows[index - 1].isLockedOut {
                    result.append(index)
                }
            }
            return result
        }

        func attach(to host: TaskSplitTableHost) {
            self.host = host
            host.fixedTableView.delegate = self
            host.fixedTableView.dataSource = self
            host.mainTableView.delegate = self
            host.mainTableView.dataSource = self
        }

        func update(
            rows: [TaskRowSnapshot],
            edit: @escaping (TaskItem) -> Void,
            delete: @escaping (TaskItem) -> Void,
            select: @escaping (TaskRowSnapshot) -> Void
        ) {
            self.rows = rows
            self.edit = edit
            self.delete = delete
            self.select = select
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            guard rows.indices.contains(row) else { return TableMetrics.rowHeight }
            return rows[row].height
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            false
        }

        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            guard rows.indices.contains(row) else { return nil }
            let rowView = TaskAppKitRowView()
            rowView.fillColor = rows[row].isLockedOut ? rows[row].status.taskRowNSColor.dimmedForFocusLock : rows[row].status.taskRowNSColor
            rowView.borderAlpha = rows[row].isLockedOut ? 0.42 : 1
            return rowView
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row), let identifier = tableColumn?.identifier.rawValue else { return nil }
            let rowSnapshot = rows[row]

            switch identifier {
            case TaskAppKitColumn.name.id:
                return textCell(
                    in: tableView,
                    text: rowSnapshot.name,
                    bold: true,
                    placeholder: false,
                    isLockedOut: rowSnapshot.isLockedOut
                )
            case TaskAppKitColumn.coreValue.id:
                return textCell(in: tableView, text: rowSnapshot.coreValueName, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.goal.id:
                return textCell(in: tableView, text: rowSnapshot.goalName, placeholder: rowSnapshot.isStandalone, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.milestone.id:
                return textCell(in: tableView, text: rowSnapshot.milestoneName, placeholder: rowSnapshot.isStandalone, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.priority.id:
                return textCell(
                    in: tableView,
                    text: rowSnapshot.priority,
                    bold: PriorityTextStyle.usesBoldWeight(rowSnapshot.priority),
                    isLockedOut: rowSnapshot.isLockedOut
                )
            case TaskAppKitColumn.status.id:
                return statusCell(in: tableView, status: rowSnapshot.status, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.taskType.id:
                return textCell(in: tableView, text: rowSnapshot.taskType, bold: rowSnapshot.taskType == TaskType.deep.rawValue, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.description.id:
                return textCell(in: tableView, text: rowSnapshot.taskDescription, isLockedOut: rowSnapshot.isLockedOut)
            case TaskAppKitColumn.actions.id:
                return actionsCell(in: tableView, row: rowSnapshot)
            default:
                return nil
            }
        }

        private func textCell(
            in tableView: NSTableView,
            text: String,
            bold: Bool = false,
            placeholder: Bool = false,
            isLockedOut: Bool
        ) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("TaskTextCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TaskTextTableCellView ?? TaskTextTableCellView()
            cell.identifier = identifier
            cell.configure(text: text, bold: bold, placeholder: placeholder, isLockedOut: isLockedOut)
            return cell
        }

        private func statusCell(in tableView: NSTableView, status: TaskStatus, isLockedOut: Bool) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("TaskStatusCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TaskStatusTableCellView ?? TaskStatusTableCellView()
            cell.identifier = identifier
            cell.configure(status: status, isLockedOut: isLockedOut)
            return cell
        }

        private func actionsCell(in tableView: NSTableView, row: TaskRowSnapshot) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("TaskActionsCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TaskActionsTableCellView ?? TaskActionsTableCellView()
            cell.identifier = identifier
            cell.configure(
                isSelected: row.isSelected,
                target: self,
                selectAction: #selector(selectTask(_:)),
                editAction: #selector(editTask(_:)),
                deleteAction: #selector(deleteTask(_:)),
                isEnabled: !row.isLockedOut
            )
            return cell
        }

        @objc private func selectTask(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            select(row)
        }

        @objc private func editTask(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            edit(row.task)
        }

        @objc private func deleteTask(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            delete(row.task)
        }

        private func rowSnapshot(for sender: NSView) -> TaskRowSnapshot? {
            guard let tableView = sender.enclosingTableView else { return nil }
            let rowIndex = tableView.row(for: sender)
            guard rows.indices.contains(rowIndex) else { return nil }
            return rows[rowIndex]
        }
    }
}

private final class TaskSplitTableHost: NSView {
    let fixedTableView = NSTableView()
    let mainTableView = NSTableView()

    private let fixedHeaderView = TaskHeaderRowView(columns: [.name])
    private let mainHeaderScrollView = NSScrollView()
    private let mainHeaderView = TaskHeaderRowView(columns: TaskAppKitColumn.mainColumns)
    private let fixedScrollView = NSScrollView()
    private let mainScrollView = NSScrollView()
    private let fixedSeparator = NSView()
    private let headerBottomBorder = NSView()
    private var fixedBoundsObserver: NSObjectProtocol?
    private var mainBoundsObserver: NSObjectProtocol?
    private var isSynchronizingScroll = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        configure(tableView: fixedTableView)
        configure(tableView: mainTableView)
        configureHeaderScrollView()
        configure(scrollView: fixedScrollView, tableView: fixedTableView, verticalScroller: false, horizontalScroller: false)
        configure(scrollView: mainScrollView, tableView: mainTableView, verticalScroller: true, horizontalScroller: true)
        configureColumns()
        configureLayout()
        installScrollSync()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func reloadTables(rowCount: Int) {
        let verticalOffset = mainScrollView.contentView.bounds.origin.y
        fixedTableView.reloadData()
        mainTableView.reloadData()

        let changedRows = IndexSet(integersIn: 0..<rowCount)
        fixedTableView.noteHeightOfRows(withIndexesChanged: changedRows)
        mainTableView.noteHeightOfRows(withIndexesChanged: changedRows)
        restoreVerticalOffset(verticalOffset)
    }

    func scrollToRow(_ row: Int) {
        fixedTableView.scrollRowToVisible(row)
        mainTableView.scrollRowToVisible(row)
        syncVerticalOffset(from: mainScrollView, to: fixedScrollView)
    }

    private func configure(tableView: NSTableView) {
        tableView.style = .plain
        tableView.backgroundColor = .white
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = false
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.gridStyleMask = []
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.rowHeight = TableMetrics.rowHeight
        tableView.headerView = nil
    }

    private func configureHeaderScrollView() {
        fixedHeaderView.translatesAutoresizingMaskIntoConstraints = false
        mainHeaderScrollView.documentView = mainHeaderView
        mainHeaderScrollView.hasVerticalScroller = false
        mainHeaderScrollView.hasHorizontalScroller = false
        mainHeaderScrollView.autohidesScrollers = true
        mainHeaderScrollView.borderType = .noBorder
        mainHeaderScrollView.drawsBackground = true
        mainHeaderScrollView.backgroundColor = TaskAppKitColors.headerFill
        mainHeaderScrollView.contentView.drawsBackground = true
        mainHeaderScrollView.contentView.backgroundColor = TaskAppKitColors.headerFill
        mainHeaderScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainHeaderView.frame = NSRect(
            x: 0,
            y: 0,
            width: TaskAppKitColumn.mainColumns.reduce(CGFloat(0)) { $0 + $1.width },
            height: TableMetrics.headerHeight
        )
    }

    private func configure(
        scrollView: NSScrollView,
        tableView: NSTableView,
        verticalScroller: Bool,
        horizontalScroller: Bool
    ) {
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = verticalScroller
        scrollView.hasHorizontalScroller = horizontalScroller
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white
        scrollView.contentView.drawsBackground = true
        scrollView.contentView.backgroundColor = .white
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureColumns() {
        fixedTableView.addTableColumn(TaskAppKitColumn.name.tableColumn)
        TaskAppKitColumn.mainColumns.forEach { mainTableView.addTableColumn($0.tableColumn) }
        mainTableView.frame.size.width = TaskAppKitColumn.mainColumns.reduce(CGFloat(0)) { $0 + $1.width }
        fixedTableView.frame.size.width = TaskColumns.name
    }

    private func configureLayout() {
        addSubview(fixedHeaderView)
        addSubview(mainHeaderScrollView)
        addSubview(fixedScrollView)
        addSubview(fixedSeparator)
        addSubview(mainScrollView)
        addSubview(headerBottomBorder)
        fixedSeparator.translatesAutoresizingMaskIntoConstraints = false
        fixedSeparator.wantsLayer = true
        fixedSeparator.layer?.backgroundColor = TaskAppKitColors.tableBorder.cgColor
        headerBottomBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBottomBorder.wantsLayer = true
        headerBottomBorder.layer?.backgroundColor = TaskAppKitColors.tableBorder.cgColor

        NSLayoutConstraint.activate([
            fixedHeaderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fixedHeaderView.topAnchor.constraint(equalTo: topAnchor),
            fixedHeaderView.widthAnchor.constraint(equalToConstant: TaskColumns.name),
            fixedHeaderView.heightAnchor.constraint(equalToConstant: TableMetrics.headerHeight),

            mainHeaderScrollView.leadingAnchor.constraint(equalTo: fixedSeparator.trailingAnchor),
            mainHeaderScrollView.topAnchor.constraint(equalTo: topAnchor),
            mainHeaderScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainHeaderScrollView.heightAnchor.constraint(equalToConstant: TableMetrics.headerHeight),

            fixedScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fixedScrollView.topAnchor.constraint(equalTo: fixedHeaderView.bottomAnchor),
            fixedScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fixedScrollView.widthAnchor.constraint(equalToConstant: TaskColumns.name),

            fixedSeparator.leadingAnchor.constraint(equalTo: fixedScrollView.trailingAnchor),
            fixedSeparator.topAnchor.constraint(equalTo: topAnchor),
            fixedSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            fixedSeparator.widthAnchor.constraint(equalToConstant: 1),

            mainScrollView.leadingAnchor.constraint(equalTo: fixedSeparator.trailingAnchor),
            mainScrollView.topAnchor.constraint(equalTo: mainHeaderScrollView.bottomAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            headerBottomBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerBottomBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerBottomBorder.topAnchor.constraint(equalTo: fixedHeaderView.bottomAnchor),
            headerBottomBorder.heightAnchor.constraint(equalToConstant: 1)
        ])
    }

    private func installScrollSync() {
        fixedScrollView.contentView.postsBoundsChangedNotifications = true
        mainScrollView.contentView.postsBoundsChangedNotifications = true

        fixedBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: fixedScrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.syncVerticalOffset(from: self.fixedScrollView, to: self.mainScrollView)
        }

        mainBoundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: mainScrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.syncVerticalOffset(from: self.mainScrollView, to: self.fixedScrollView)
            self.syncHeaderHorizontalOffset()
        }
    }

    private func syncVerticalOffset(from source: NSScrollView, to target: NSScrollView) {
        guard !isSynchronizingScroll else { return }
        isSynchronizingScroll = true
        var targetBounds = target.contentView.bounds
        targetBounds.origin.y = source.contentView.bounds.origin.y
        target.contentView.bounds = targetBounds
        target.reflectScrolledClipView(target.contentView)
        isSynchronizingScroll = false
    }

    private func restoreVerticalOffset(_ yOffset: CGFloat) {
        var bounds = mainScrollView.contentView.bounds
        bounds.origin.y = max(0, yOffset)
        mainScrollView.contentView.bounds = bounds
        mainScrollView.reflectScrolledClipView(mainScrollView.contentView)
        syncVerticalOffset(from: mainScrollView, to: fixedScrollView)
        syncHeaderHorizontalOffset()
    }

    private func syncHeaderHorizontalOffset() {
        var headerBounds = mainHeaderScrollView.contentView.bounds
        headerBounds.origin.x = mainScrollView.contentView.bounds.origin.x
        mainHeaderScrollView.contentView.bounds = headerBounds
        mainHeaderScrollView.reflectScrolledClipView(mainHeaderScrollView.contentView)
    }

    deinit {
        if let fixedBoundsObserver {
            NotificationCenter.default.removeObserver(fixedBoundsObserver)
        }
        if let mainBoundsObserver {
            NotificationCenter.default.removeObserver(mainBoundsObserver)
        }
    }
}

private struct TaskAppKitColumn {
    let id: String
    let title: String
    let width: CGFloat

    var tableColumn: NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        column.minWidth = width
        column.maxWidth = width
        column.headerCell = TaskHeaderCell(textCell: title)
        column.resizingMask = []
        return column
    }

    static let name = TaskAppKitColumn(id: "name", title: "Task", width: TaskColumns.name)
    static let coreValue = TaskAppKitColumn(id: "coreValue", title: "Core Values", width: TaskColumns.coreValue)
    static let goal = TaskAppKitColumn(id: "goal", title: "Goal", width: TaskColumns.goal)
    static let milestone = TaskAppKitColumn(id: "milestone", title: "Milestone", width: TaskColumns.milestone)
    static let priority = TaskAppKitColumn(id: "priority", title: "Priority", width: TaskColumns.priority)
    static let status = TaskAppKitColumn(id: "status", title: "Status", width: TaskColumns.status)
    static let taskType = TaskAppKitColumn(id: "taskType", title: "Task Type", width: TaskColumns.taskType)
    static let description = TaskAppKitColumn(id: "description", title: "Task Description", width: TaskColumns.description)
    static let actions = TaskAppKitColumn(id: "actions", title: "", width: TaskColumns.actions)

    static let mainColumns: [TaskAppKitColumn] = [
        coreValue,
        goal,
        milestone,
        priority,
        status,
        taskType,
        description,
        actions
    ]
}

private final class TaskHeaderRowView: NSView {
    private let columns: [TaskAppKitColumn]

    override var isFlipped: Bool { true }

    init(columns: [TaskAppKitColumn]) {
        self.columns = columns
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = TaskAppKitColors.headerFill.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        TaskAppKitColors.headerFill.setFill()
        bounds.fill()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Helvetica Neue Bold", size: TableMetrics.fontSize) ?? .boldSystemFont(ofSize: TableMetrics.fontSize),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraphStyle
        ]

        var xOffset: CGFloat = 0
        for column in columns {
            let textRect = NSRect(
                x: xOffset + TableMetrics.textInset,
                y: 0,
                width: max(0, column.width - (TableMetrics.textInset * 2)),
                height: TableMetrics.headerHeight
            )
            (column.title as NSString).draw(
                in: textRect.insetBy(dx: 0, dy: (TableMetrics.headerHeight - TableMetrics.fontSize - 4) / 2),
                withAttributes: attributes
            )
            xOffset += column.width
        }

    }
}

private final class TaskHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        TaskAppKitColors.headerFill.setFill()
        cellFrame.fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Helvetica Neue Bold", size: TableMetrics.fontSize) ?? .boldSystemFont(ofSize: TableMetrics.fontSize),
            .foregroundColor: NSColor.black
        ]
        let titleSize = stringValue.size(withAttributes: attributes)
        let textRect = NSRect(
            x: cellFrame.minX + TableMetrics.textInset,
            y: cellFrame.midY - (titleSize.height / 2),
            width: max(0, cellFrame.width - (TableMetrics.textInset * 2)),
            height: titleSize.height
        )
        stringValue.draw(in: textRect, withAttributes: attributes)

        TaskAppKitColors.tableBorder.setFill()
        NSRect(x: cellFrame.minX, y: cellFrame.maxY - 1, width: cellFrame.width, height: 1).fill()
    }
}

private final class TaskAppKitRowView: NSTableRowView {
    var fillColor: NSColor = .white
    var borderAlpha: CGFloat = 1

    override func drawBackground(in dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()

        TaskAppKitColors.tableBorder.withAlphaComponent(borderAlpha).setFill()
        NSRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}

private final class TaskTextTableCellView: NSTableCellView {
    private let label = NSTextField(wrappingLabelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        label.cell?.usesSingleLineMode = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TableMetrics.textInset),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -TableMetrics.textInset),
            label.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: TableMetrics.textInset),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -TableMetrics.textInset),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, bold: Bool, placeholder: Bool, isLockedOut: Bool) {
        label.stringValue = text.isEmpty ? " " : text
        label.font = NSFont(
            name: bold ? "Helvetica Neue Bold" : "Helvetica Neue",
            size: TableMetrics.fontSize
        ) ?? (bold ? .boldSystemFont(ofSize: TableMetrics.fontSize) : .systemFont(ofSize: TableMetrics.fontSize))
        let baseAlpha: CGFloat = placeholder ? 0.38 : PriorityTextStyle.opacity(for: text)
        let color = text.trimmingCharacters(in: .whitespacesAndNewlines) == ComputedPriority.highest.displayName
            ? TaskAppKitColors.devotionalRed
            : NSColor.black
        label.textColor = color.withAlphaComponent(isLockedOut ? 0.16 : baseAlpha)
    }
}

private final class TaskStatusTableCellView: NSTableCellView {
    private let badge = TaskStatusBadgeView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)

        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TableMetrics.textInset),
            badge.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -TableMetrics.textInset),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.heightAnchor.constraint(greaterThanOrEqualToConstant: 26)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(status: TaskStatus, isLockedOut: Bool) {
        badge.configure(text: status.rawValue, color: status.taskBadgeNSColor, isLockedOut: isLockedOut)
    }
}

private final class TaskStatusBadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 13
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont(name: "Helvetica Neue Bold", size: TableMetrics.fontSize) ?? .boldSystemFont(ofSize: TableMetrics.fontSize)
        label.textColor = .black
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, color: NSColor, isLockedOut: Bool) {
        label.stringValue = text
        let isBold = StatusTextStyle.usesBoldWeight(text)
        label.font = NSFont(
            name: isBold ? "Helvetica Neue Bold" : "Helvetica Neue",
            size: TableMetrics.fontSize
        ) ?? (isBold ? .boldSystemFont(ofSize: TableMetrics.fontSize) : .systemFont(ofSize: TableMetrics.fontSize))
        label.textColor = NSColor.black.withAlphaComponent(isLockedOut ? 0.16 : 1)
        layer?.backgroundColor = (isLockedOut ? color.dimmedForFocusLock : color).cgColor
        layer?.borderColor = NSColor.black.withAlphaComponent(isLockedOut ? 0.03 : 0.08).cgColor
    }
}

private final class TaskActionsTableCellView: NSTableCellView {
    private let selectButton = TaskActionButton(symbolName: "checkmark.circle.fill")
    private let editButton = TaskActionButton(symbolName: "pencil")
    private let deleteButton = TaskActionButton(symbolName: "trash")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let stack = NSStackView(views: [selectButton, editButton, deleteButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TableMetrics.textInset),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -TableMetrics.textInset)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        isSelected: Bool,
        target: AnyObject,
        selectAction: Selector,
        editAction: Selector,
        deleteAction: Selector,
        isEnabled: Bool
    ) {
        selectButton.update(
            symbolName: isSelected ? "xmark.circle" : "checkmark.circle.fill",
            tint: TaskAppKitColors.moduleIconRed,
            toolTip: isSelected ? "Deselect Task" : "Select Task",
            target: isEnabled ? target : nil,
            action: isEnabled ? selectAction : nil,
            isEnabled: isEnabled
        )
        editButton.update(
            symbolName: "pencil",
            tint: .black,
            toolTip: "Edit",
            target: isEnabled ? target : nil,
            action: isEnabled ? editAction : nil,
            isEnabled: isEnabled
        )
        deleteButton.update(
            symbolName: "trash",
            tint: TaskAppKitColors.deleteAccent,
            toolTip: "Delete",
            target: isEnabled ? target : nil,
            action: isEnabled ? deleteAction : nil,
            isEnabled: isEnabled
        )
    }
}

private final class TaskActionButton: NSButton {
    private var trackingAreaReference: NSTrackingArea?
    private var tint: NSColor = .black

    init(symbolName: String) {
        super.init(frame: .zero)
        isBordered = false
        imagePosition = .imageOnly
        focusRingType = .none
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 28).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
        update(symbolName: symbolName, tint: .black, toolTip: nil, target: nil, action: nil, isEnabled: true)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func update(symbolName: String, tint: NSColor, toolTip: String?, target: AnyObject?, action: Selector?, isEnabled: Bool) {
        self.tint = tint
        image = NSImage(systemSymbolName: symbolName, accessibilityDescription: toolTip)
        contentTintColor = tint
        self.toolTip = toolTip
        self.target = target
        self.action = action
        self.isEnabled = isEnabled
        alphaValue = isEnabled ? 0.22 : 0.08
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseEntered(with event: NSEvent) {
        guard isEnabled else { return }
        alphaValue = 0.76
    }

    override func mouseExited(with event: NSEvent) {
        guard isEnabled else { return }
        alphaValue = 0.22
    }
}

private enum TaskAppKitColors {
    static let headerFill = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.94, alpha: 1)
    static let tableBorder = NSColor(calibratedWhite: 0.82, alpha: 1)
    static let active = NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.34, alpha: 1)
    static let completed = NSColor(calibratedRed: 0.77, green: 0.92, blue: 0.80, alpha: 1)
    static let creamWork = NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.91, alpha: 1)
    static let rowCompleted = NSColor(calibratedRed: 0.86, green: 0.96, blue: 0.88, alpha: 1)
    static let moduleIconRed = NSColor.systemRed
    static let deleteAccent = NSColor(calibratedRed: 0.78, green: 0.08, blue: 0.08, alpha: 1)
    static let devotionalRed = NSColor(calibratedRed: 0.48, green: 0.05, blue: 0.04, alpha: 1)
}

private extension TaskStatus {
    var taskBadgeNSColor: NSColor {
        switch self {
        case .completed:
            return TaskAppKitColors.completed
        case .active, .partiallyCompleted:
            return TaskAppKitColors.active
        case .notStarted:
            return .white
        }
    }

    var taskRowNSColor: NSColor {
        switch self {
        case .completed:
            return TaskAppKitColors.rowCompleted
        case .active, .partiallyCompleted:
            return TaskAppKitColors.creamWork
        case .notStarted:
            return .white
        }
    }
}

private extension NSColor {
    var dimmedForFocusLock: NSColor {
        blended(withFraction: 0.82, of: .white) ?? withAlphaComponent(0.18)
    }
}

private extension NSView {
    var enclosingTableView: NSTableView? {
        var candidate: NSView? = self
        while let view = candidate {
            if let tableView = view as? NSTableView {
                return tableView
            }
            candidate = view.superview
        }
        return nil
    }
}

private struct TaskRowSnapshot: Identifiable {
    let id: UUID
    let task: TaskItem
    let sortKey: TaskRowSortKey
    let name: String
    let coreValueName: String
    let goalName: String
    let milestoneName: String
    let priority: String
    let status: TaskStatus
    let taskType: String
    let taskDescription: String
    let isStandalone: Bool
    let isSelected: Bool
    let isLockedOut: Bool
    let hasComputedPriority: Bool
    let height: CGFloat

    init(
        task: TaskItem,
        selectedTaskID: UUID?,
        isLockedOut: Bool,
        goalPriorities: [UUID: ComputedPriority],
        heightCache: TaskRowHeightCache
    ) {
        let status = TaskSheetStatus.status(for: task, selectedTaskID: selectedTaskID)
        let goalName = task.displayGoalName
        let milestoneName = task.displayMilestoneName
        let priority = GoalPriorityService.displayPriority(for: task, goalPriorities: goalPriorities).displayName
        let taskType = task.taskType.rawValue
        let heightKey = TaskRowHeightKey(
            id: task.id,
            name: task.name,
            coreValueName: task.coreValueName,
            goalName: goalName,
            milestoneName: milestoneName,
            priority: priority,
            status: status.rawValue,
            taskType: taskType,
            taskDescription: task.taskDescription
        )

        self.id = task.id
        self.task = task
        self.sortKey = TaskRowSortKey(task: task, status: status, goalPriorities: goalPriorities)
        self.name = task.name
        self.coreValueName = task.coreValueName
        self.goalName = goalName
        self.milestoneName = milestoneName
        self.priority = priority
        self.status = status
        self.taskType = taskType
        self.taskDescription = task.taskDescription
        self.isStandalone = task.isStandalone
        self.isSelected = selectedTaskID == task.id
        self.isLockedOut = isLockedOut
        self.hasComputedPriority = task.milestone != nil
        self.height = heightCache.height(for: heightKey, columns: [
            (task.name, TaskColumns.name),
            (task.coreValueName, TaskColumns.coreValue),
            (goalName, TaskColumns.goal),
            (milestoneName, TaskColumns.milestone),
            (priority, TaskColumns.priority),
            (status.rawValue, TaskColumns.status),
            (taskType, TaskColumns.taskType),
            (task.taskDescription, TaskColumns.description)
        ])
    }

    static func sortPrecedes(_ left: TaskRowSnapshot, _ right: TaskRowSnapshot) -> Bool {
        left.sortKey.precedes(right.sortKey)
    }

    var statusColor: Color {
        GoalTrackerTheme.background(for: status)
    }

    var rowBackground: Color {
        GoalTrackerTheme.tableRowBackground(for: status)
    }
}

private final class TaskRowHeightCache {
    private var heights: [TaskRowHeightKey: CGFloat] = [:]

    func removeAll() {
        heights.removeAll(keepingCapacity: true)
    }

    func height(for key: TaskRowHeightKey, columns: [(text: String, width: CGFloat)]) -> CGFloat {
        if let cachedHeight = heights[key] {
            return cachedHeight
        }

        if heights.count > 1_500 {
            heights.removeAll(keepingCapacity: true)
        }

        let height = TableMetrics.rowHeight(for: columns)
        heights[key] = height
        return height
    }
}

private struct TaskRowHeightKey: Hashable {
    let id: UUID
    let name: String
    let coreValueName: String
    let goalName: String
    let milestoneName: String
    let priority: String
    let status: String
    let taskType: String
    let taskDescription: String
}

private struct TaskRowSortKey {
    let priorityRank: Int
    let isStandalone: Bool
    let createdAt: Date
    let name: String
    let goalID: UUID?
    let goalRank: Int
    let goalIsCompleted: Bool
    let goalProgress: Double
    let goalStatusRank: Int
    let goalStartDate: Date?
    let goalEndDate: Date?
    let goalName: String
    let milestoneID: UUID?
    let milestoneStartDate: Date?
    let milestoneEndDate: Date?
    let milestoneName: String

    init(task: TaskItem, status: TaskStatus, goalPriorities: [UUID: ComputedPriority]) {
        let milestone = task.milestone
        let goal = milestone?.goal
        let goalPriority = goal.map { goalPriorities[$0.id] ?? GoalPriorityService.standalonePriority(for: $0) } ?? ComputedPriority.none
        self.priorityRank = GoalPriorityService.displayPriority(for: task, goalPriorities: goalPriorities).sortRank
        self.isStandalone = milestone == nil
        self.createdAt = task.createdAt
        self.name = task.name
        self.goalID = goal?.id
        self.goalRank = goalPriority.sortRank
        self.goalIsCompleted = goal?.status == .completed
        self.goalProgress = goal?.computedProgress ?? 0
        self.goalStatusRank = goal?.status.focusRank ?? Int.max
        self.goalStartDate = goal?.startDate
        self.goalEndDate = goal?.endDate
        self.goalName = goal?.name ?? ""
        self.milestoneID = milestone?.id
        self.milestoneStartDate = milestone?.startDate
        self.milestoneEndDate = milestone?.endDate
        self.milestoneName = milestone?.name ?? ""
    }

    func precedes(_ other: TaskRowSortKey) -> Bool {
        if priorityRank != other.priorityRank {
            return priorityRank < other.priorityRank
        }
        if isStandalone || other.isStandalone {
            if isStandalone && other.isStandalone {
                if createdAt != other.createdAt { return createdAt > other.createdAt }
                return name.localizedCaseInsensitiveCompare(other.name) == .orderedAscending
            }
            return isStandalone
        }

        if goalRank != other.goalRank { return goalRank < other.goalRank }
        if goalID != other.goalID {
            return goalContextPrecedes(other)
        }
        if milestoneID != other.milestoneID {
            return milestoneContextPrecedes(other)
        }
        if createdAt != other.createdAt { return createdAt < other.createdAt }
        return name.localizedCaseInsensitiveCompare(other.name) == .orderedAscending
    }

    private func goalContextPrecedes(_ other: TaskRowSortKey) -> Bool {
        guard goalID != nil else { return false }
        guard other.goalID != nil else { return true }
        if goalRank != other.goalRank {
            return goalRank < other.goalRank
        }
        if goalRank == ComputedPriority.none.sortRank {
            if goalIsCompleted != other.goalIsCompleted {
                return !goalIsCompleted
            }
            if goalProgress != other.goalProgress {
                return goalProgress > other.goalProgress
            }
        }
        if goalStatusRank != other.goalStatusRank {
            return goalStatusRank < other.goalStatusRank
        }
        if goalStartDate != other.goalStartDate {
            return (goalStartDate ?? .distantFuture) < (other.goalStartDate ?? .distantFuture)
        }
        if goalEndDate != other.goalEndDate {
            return (goalEndDate ?? .distantFuture) < (other.goalEndDate ?? .distantFuture)
        }
        return goalName.localizedCaseInsensitiveCompare(other.goalName) == .orderedAscending
    }

    private func milestoneContextPrecedes(_ other: TaskRowSortKey) -> Bool {
        guard milestoneID != nil else { return false }
        guard other.milestoneID != nil else { return true }
        if milestoneStartDate != other.milestoneStartDate {
            return (milestoneStartDate ?? .distantFuture) < (other.milestoneStartDate ?? .distantFuture)
        }
        if milestoneEndDate != other.milestoneEndDate {
            return (milestoneEndDate ?? .distantFuture) < (other.milestoneEndDate ?? .distantFuture)
        }
        return milestoneName.localizedCaseInsensitiveCompare(other.milestoneName) == .orderedAscending
    }
}

private enum TaskSheetStatus {
    static func status(for task: TaskItem, selectedTaskID: UUID?) -> TaskStatus {
        if selectedTaskID == task.id {
            return .active
        }

        return task.status == .active ? .notStarted : task.status
    }
}

private enum TaskScope: String, CaseIterable, Identifiable {
    case standalone = "Standalone"
    case milestone = "Goal / Milestone"

    var id: String { rawValue }
}

private struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var milestones: FetchedResults<Milestone>
    @FetchRequest(sortDescriptors: []) private var coreValues: FetchedResults<CoreValue>

    let task: TaskItem?
    let selectedTaskID: UUID?
    let onSave: () -> Void
    @State private var taskScope: TaskScope
    @State private var selectedMilestoneID: UUID?
    @State private var selectedCoreValueID: UUID?
    @State private var name: String
    @State private var priority: TaskPriority
    @State private var taskType: TaskType
    @State private var taskDescription: String
    @State private var error: String?

    init(
        task: TaskItem?,
        defaultMilestoneID: UUID? = nil,
        selectedTaskID: UUID? = nil,
        onSave: @escaping () -> Void = {}
    ) {
        self.task = task
        self.selectedTaskID = selectedTaskID
        self.onSave = onSave
        let initialMilestoneID = task?.milestone?.id ?? defaultMilestoneID
        _taskScope = State(initialValue: initialMilestoneID == nil ? .standalone : .milestone)
        _selectedMilestoneID = State(initialValue: initialMilestoneID)
        _selectedCoreValueID = State(initialValue: task?.coreValue?.id)
        _name = State(initialValue: task?.name ?? "")
        _priority = State(initialValue: task?.priority ?? .medium)
        _taskType = State(initialValue: task?.taskType ?? .deep)
        _taskDescription = State(initialValue: task?.taskDescription ?? "")
    }

    private var selectedMilestone: Milestone? {
        milestones.first { $0.id == selectedMilestoneID }
    }

    private var selectedCoreValue: CoreValue? {
        coreValues.first { $0.id == selectedCoreValueID }
    }

    private var linkedPriority: ComputedPriority {
        guard let goal = selectedMilestone?.goal else {
            return .none
        }
        return GoalPriorityService.priority(for: goal, among: milestones.compactMap(\.goal))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task == nil ? "Add Task" : "Edit Task")
                .font(.title2.weight(.bold))

            Picker("Task Context", selection: $taskScope) {
                ForEach(TaskScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if taskScope == .standalone {
                HStack {
                    Picker("Core Value", selection: $selectedCoreValueID) {
                        Text("No Core Value").tag(nil as UUID?)
                        ForEach(coreValues.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { value in
                            Text(value.name).tag(value.id as UUID?)
                        }
                    }

                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                HStack {
                    ReadOnlyField(title: "Goal", value: "No Goal", muted: true)
                    ReadOnlyField(title: "Milestone", value: "No Milestone", muted: true)
                }
            } else {
                Picker("Milestone", selection: $selectedMilestoneID) {
                    Text("Select Milestone").tag(nil as UUID?)
                    let priorities = GoalPriorityService.priorities(for: milestones.compactMap(\.goal))
                    ForEach(milestones.sorted { GoalTrackerSort.milestones($0, $1, priorities: priorities) }) { milestone in
                        Text("\(milestone.name)  |  \(milestone.goalName)")
                            .tag(milestone.id as UUID?)
                    }
                }

                HStack {
                    ReadOnlyField(title: "Core Value", value: selectedMilestone?.coreValueName ?? "")
                    ReadOnlyField(title: "Goal", value: selectedMilestone?.goalName ?? "")
                    ReadOnlyField(title: "Priority", value: linkedPriority.displayName)
                }
            }

            TextField("Task Name", text: $name)
                .textFieldStyle(.roundedBorder)

            if task == nil {
                Picker("Task Type", selection: $taskType) {
                    ForEach(TaskType.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
            } else {
                HStack {
                    ReadOnlyField(title: "Status", value: computedTaskStatus.rawValue)
                    Picker("Task Type", selection: $taskType) {
                        ForEach(TaskType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Task Description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $taskDescription)
                    .font(.custom("Helvetica Neue", size: 14))
                    .frame(minHeight: 110)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(Rectangle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
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
        .frame(width: 680)
        .onChange(of: taskScope) { _, newScope in
            if newScope == .standalone {
                selectedMilestoneID = nil
            } else {
                selectedCoreValueID = nil
            }
        }
    }

    private func save() {
        let selectedMilestoneForSave = taskScope == .milestone ? selectedMilestone : nil
        let selectedCoreValueForSave = taskScope == .standalone ? selectedCoreValue : nil

        if taskScope == .milestone && selectedMilestoneForSave == nil {
            error = "Select a Milestone or choose Standalone."
            return
        }

        if let validation = ValidationService.validateTask(name: name, milestone: selectedMilestoneForSave) {
            error = validation
            return
        }

        let target: TaskItem
        let previousMilestone = task?.milestone
        let previousCoreValue = task?.coreValue
        if let task {
            target = task
        } else {
            target = TaskItem(context: managedObjectContext, name: name)
        }

        let now = Date()
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.coreValue = selectedCoreValueForSave
        target.milestone = selectedMilestoneForSave
        target.priority = priority
        if task == nil {
            target.status = .notStarted
        }
        target.taskType = taskType
        target.taskDescription = taskDescription
        target.updatedAt = now
        previousCoreValue.map { RelationshipRefreshService.touchValueCascade($0, now: now) }
        previousMilestone.map { RelationshipRefreshService.touchMilestoneCascade($0, now: now) }
        selectedCoreValueForSave.map { RelationshipRefreshService.touchValueCascade($0, now: now) }
        RelationshipRefreshService.touchTaskCascade(target, now: now)

        do {
            try managedObjectContext.save()
            managedObjectContext.processPendingChanges()
            onSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var computedTaskStatus: TaskStatus {
        task.map { TaskSheetStatus.status(for: $0, selectedTaskID: selectedTaskID) } ?? .notStarted
    }
}
