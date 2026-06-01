import CoreData
import AppKit
import SwiftUI

struct SessionsView: View {
    let filters: GoalTrackerGlobalFilters
    let selectionActions: GoalTrackerSelectionActions

    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var sessions: FetchedResults<WorkSession>
    @FetchRequest(sortDescriptors: []) private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage("GoalTracker.tasksStandaloneOnly") private var standaloneOnly = false
    @State private var searchText = ""
    @State private var showEditor = false
    @State private var editingSession: WorkSession?
    @State private var deleteCandidate: WorkSession?
    @State private var sessionTask: TaskItem?
    @State private var sessionRefreshID = 0
    @State private var rowHeightCache = SessionRowHeightCache()
    @State private var findAvailableRequest = 0

    private var goalPriorities: [UUID: ComputedPriority] {
        GoalPriorityService.priorities(for: Array(goals))
    }

    private var filteredSessions: [WorkSession] {
        let priorities = goalPriorities
        return sessions
            .filter(sessionMatchesSearch)
            .sorted { GoalTrackerSort.sessions($0, $1, goalPriorities: priorities) }
    }

    private var sessionRows: [SessionTableRow] {
        SessionTableRow.rows(
            from: filteredSessions,
            selectedTaskID: filters.taskID,
            goalPriorities: goalPriorities,
            isLockedOut: { filters.isLockedOut(session: $0) || (standaloneOnly && $0.task?.isStandalone != true) },
            heightCache: rowHeightCache
        )
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

    private func sessionMatchesSearch(_ session: WorkSession) -> Bool {
        searchText.isEmpty ||
        session.displayLabel.localizedCaseInsensitiveContains(searchText) ||
        session.taskName.localizedCaseInsensitiveContains(searchText) ||
        session.goalName.localizedCaseInsensitiveContains(searchText) ||
        session.milestoneName.localizedCaseInsensitiveContains(searchText) ||
        session.coreValueName.localizedCaseInsensitiveContains(searchText) ||
        session.expectedResult.localizedCaseInsensitiveContains(searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Sessions Sheet",
                subtitle: ""
            ) {
                HStack(spacing: 8) {
                    SheetHeaderSearchField(text: $searchText, prompt: "Search Sessions")

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
                    .help("Keep standalone-task sessions active and lock other session rows")

                    if shouldShowFindAvailableButton {
                        GoalTrackerFindAvailableButton {
                            findAvailableRequest &+= 1
                        }
                    }

                    Button {
                        editingSession = nil
                        sessionTask = selectedTask
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(GoalTrackerDimIconButtonStyle())
                    .keyboardShortcut("n", modifiers: [.command])
                    .help("Add Session")
                }
            }

            if let selectedTask {
                ScrollView {
                    SelectedTaskSessionStudySection(
                        task: selectedTask,
                        sessions: selectedTaskSessions,
                        addSession: {
                            editingSession = nil
                            sessionTask = selectedTask
                            showEditor = true
                        },
                        editSession: { session in
                            editingSession = session
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                    .id(sessionRefreshID)
                }
            } else if filteredSessions.isEmpty {
                EmptyStateView(
                    systemImage: "circle.dotted",
                    title: "No sessions for this view.",
                    message: "Create a Session from an Active Task, then mark it Partial or Completed to begin your streak.",
                    iconColor: GoalTrackerTheme.moduleIconRed.opacity(0.52)
                )
            } else {
                sessionTable
                    .id(sessionRefreshID)
            }
        }
        .padding(24)
        .sheet(isPresented: $showEditor) {
            SessionEditor(session: nil, defaultTask: sessionTask ?? selectedTask, onSave: refreshSessionRows)
        }
        .sheet(item: $editingSession) { session in
            SessionEditor(session: session, defaultTask: nil, onSave: refreshSessionRows)
        }
        .confirmationDialog("Delete Session?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleteCandidate {
                    deleteSession(deleteCandidate)
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("This removes the focused work block from metrics and Daily Streak.")
        }
    }

    private var sessionTable: some View {
        GeometryReader { proxy in
            SessionAppKitTable(
                rows: sessionRows,
                findAvailableRequest: findAvailableRequest,
                edit: { session in
                    editingSession = session
                },
                delete: { session in
                    requestDelete(session)
                },
                selectTask: { row in
                    if row.isTaskSelected {
                        selectionActions.clearTask()
                    } else if let task = row.session.task {
                        selectionActions.selectTask(task)
                    }
                }
            )
            .frame(
                width: proxy.size.width,
                height: resolvedTableHeight(for: sessionRows, availableHeight: proxy.size.height),
                alignment: .topLeading
            )
            .tableContainer()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func resolvedTableHeight(for rows: [SessionTableRow], availableHeight: CGFloat) -> CGFloat {
        let contentHeight = TableMetrics.headerHeight + rows.reduce(CGFloat(0)) { total, row in
            total + row.height
        }
        let minimumHeight = TableMetrics.headerHeight + TableMetrics.rowHeight
        return min(max(contentHeight, minimumHeight), availableHeight)
    }

    private var shouldShowFindAvailableButton: Bool {
        guard selectedTask == nil else { return false }
        return sessionRows.contains { $0.isLockedOut } && sessionRows.contains { !$0.isLockedOut }
    }

    private func requestDelete(_ session: WorkSession) {
        if confirmBeforeDelete {
            deleteCandidate = session
        } else {
            deleteSession(session)
        }
    }

    private func deleteSession(_ session: WorkSession) {
        let task = session.task
        RelationshipRefreshService.touchSessionLineage(session)
        managedObjectContext.delete(session)
        TaskStatusService.refreshStoredStatus(for: task)
        try? managedObjectContext.save()
        refreshSessionRows()
    }

    private func refreshSessionRows() {
        managedObjectContext.processPendingChanges()
        rowHeightCache.removeAll()
        sessionRefreshID &+= 1
    }
}

private enum SessionColumns {
    static let session = TableMetrics.columnWidth("Session", min: 240)
    static let task = TableMetrics.columnWidth("Task", min: 240)
    static let coreValue = TableMetrics.columnWidth("Core Values", min: 170)
    static let goal = TableMetrics.columnWidth("Goal", min: 220)
    static let milestone = TableMetrics.columnWidth("Milestone", min: 220)
    static let priority = TableMetrics.columnWidth("Priority", min: 110)
    static let taskType = TableMetrics.columnWidth("Task Type", min: 110)
    static let estimatedMinutes = TableMetrics.columnWidth("Estimated Minutes", min: 150)
    static let actualMinutes = TableMetrics.columnWidth("Actual Minutes", min: 145)
    static let expectedResult = TableMetrics.columnWidth("Expected Result", min: 240)
    static let what = TableMetrics.columnWidth("What", min: 180)
    static let when = TableMetrics.columnWidth("When", min: 180)
    static let why = TableMetrics.columnWidth("Why", min: 220)
    static let how = TableMetrics.columnWidth("How", min: 220)
    static let howMuch = TableMetrics.columnWidth("How Much", min: 160)
    static let status = TableMetrics.columnWidth("Partially Completed", min: 220)
    static let sessionDate = TableMetrics.columnWidth("Session Date", min: 135)
    static let sessionNotes = TableMetrics.columnWidth("Session Notes", min: 240)
    static let linkedAntiGoal = TableMetrics.columnWidth("Linked Anti-Goal", min: 220)
    static let linkedSacrifice = TableMetrics.columnWidth("Linked Sacrifice", min: 220)
    static let actions: CGFloat = TableMetrics.actionColumnWidth
}

private struct SessionAppKitTable: NSViewRepresentable {
    let rows: [SessionTableRow]
    let findAvailableRequest: Int
    let edit: (WorkSession) -> Void
    let delete: (WorkSession) -> Void
    let selectTask: (SessionTableRow) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(rows: rows, edit: edit, delete: delete, selectTask: selectTask)
    }

    func makeNSView(context: Context) -> SessionSplitTableHost {
        let view = SessionSplitTableHost()
        context.coordinator.attach(to: view)
        view.reloadTables(rowCount: rows.count)
        return view
    }

    func updateNSView(_ nsView: SessionSplitTableHost, context: Context) {
        context.coordinator.update(rows: rows, edit: edit, delete: delete, selectTask: selectTask)
        nsView.reloadTables(rowCount: rows.count)
        if let rowIndex = context.coordinator.nextAvailableSetRowIndex(findAvailableRequest, rows: rows) {
            nsView.scrollToRow(rowIndex)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private var rows: [SessionTableRow]
        private var edit: (WorkSession) -> Void
        private var delete: (WorkSession) -> Void
        private var selectTask: (SessionTableRow) -> Void
        private weak var host: SessionSplitTableHost?
        private var lastFindAvailableRequest = 0
        private var availableSetPointer = -1

        init(
            rows: [SessionTableRow],
            edit: @escaping (WorkSession) -> Void,
            delete: @escaping (WorkSession) -> Void,
            selectTask: @escaping (SessionTableRow) -> Void
        ) {
            self.rows = rows
            self.edit = edit
            self.delete = delete
            self.selectTask = selectTask
        }

        func nextAvailableSetRowIndex(_ request: Int, rows: [SessionTableRow]) -> Int? {
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

        private func availableSetStartRowIndices(rows: [SessionTableRow]) -> [Int] {
            var result: [Int] = []
            for (index, row) in rows.enumerated() {
                guard !row.isLockedOut else { continue }
                if index == 0 || rows[index - 1].isLockedOut {
                    result.append(index)
                }
            }
            return result
        }

        func attach(to host: SessionSplitTableHost) {
            self.host = host
            host.fixedTableView.delegate = self
            host.fixedTableView.dataSource = self
            host.mainTableView.delegate = self
            host.mainTableView.dataSource = self
        }

        func update(
            rows: [SessionTableRow],
            edit: @escaping (WorkSession) -> Void,
            delete: @escaping (WorkSession) -> Void,
            selectTask: @escaping (SessionTableRow) -> Void
        ) {
            self.rows = rows
            self.edit = edit
            self.delete = delete
            self.selectTask = selectTask
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
            let rowView = SessionAppKitRowView()
            rowView.fillColor = rows[row].isLockedOut ? rows[row].status.sessionRowNSColor.dimmedForSessionFocusLock : rows[row].status.sessionRowNSColor
            rowView.borderAlpha = rows[row].isLockedOut ? 0.42 : 1
            return rowView
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard rows.indices.contains(row), let identifier = tableColumn?.identifier.rawValue else { return nil }
            let rowSnapshot = rows[row]

            switch identifier {
            case SessionAppKitColumn.session.id:
                return textCell(in: tableView, text: rowSnapshot.label, bold: true, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.coreValue.id:
                return textCell(in: tableView, text: rowSnapshot.coreValueName, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.goal.id:
                return textCell(in: tableView, text: rowSnapshot.goalText, placeholder: rowSnapshot.isStandaloneTask, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.milestone.id:
                return textCell(in: tableView, text: rowSnapshot.milestoneText, placeholder: rowSnapshot.isStandaloneTask, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.task.id:
                return textCell(in: tableView, text: rowSnapshot.taskName, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.priority.id:
                return textCell(
                    in: tableView,
                    text: rowSnapshot.priority,
                    bold: PriorityTextStyle.usesBoldWeight(rowSnapshot.priority),
                    isLockedOut: rowSnapshot.isLockedOut
                )
            case SessionAppKitColumn.status.id:
                return statusCell(in: tableView, status: rowSnapshot.status, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.sessionDate.id:
                return textCell(in: tableView, text: rowSnapshot.sessionDateText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.taskType.id:
                return textCell(in: tableView, text: rowSnapshot.taskTypeText, bold: rowSnapshot.taskTypeText == TaskType.deep.rawValue, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.what.id:
                return textCell(in: tableView, text: rowSnapshot.whatText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.when.id:
                return textCell(in: tableView, text: rowSnapshot.whenText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.why.id:
                return textCell(in: tableView, text: rowSnapshot.whyText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.how.id:
                return textCell(in: tableView, text: rowSnapshot.howText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.howMuch.id:
                return textCell(in: tableView, text: rowSnapshot.howMuchText, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.expectedResult.id:
                return textCell(in: tableView, text: rowSnapshot.expectedResult, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.estimatedMinutes.id:
                return textCell(in: tableView, text: rowSnapshot.estimatedMinutesText, alignment: .right, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.actualMinutes.id:
                return textCell(in: tableView, text: rowSnapshot.actualMinutesText, alignment: .right, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.sessionNotes.id:
                return textCell(in: tableView, text: rowSnapshot.sessionNotes, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.linkedAntiGoal.id:
                return textCell(in: tableView, text: rowSnapshot.linkedAntiGoal, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.linkedSacrifice.id:
                return textCell(in: tableView, text: rowSnapshot.linkedSacrifice, isLockedOut: rowSnapshot.isLockedOut)
            case SessionAppKitColumn.actions.id:
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
            alignment: NSTextAlignment = .left,
            isLockedOut: Bool
        ) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("SessionTextCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? SessionTextTableCellView ?? SessionTextTableCellView()
            cell.identifier = identifier
            cell.configure(text: text, bold: bold, placeholder: placeholder, alignment: alignment, isLockedOut: isLockedOut)
            return cell
        }

        private func statusCell(in tableView: NSTableView, status: SessionStatus, isLockedOut: Bool) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("SessionStatusCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? SessionStatusTableCellView ?? SessionStatusTableCellView()
            cell.identifier = identifier
            cell.configure(status: status, isLockedOut: isLockedOut)
            return cell
        }

        private func actionsCell(in tableView: NSTableView, row: SessionTableRow) -> NSView {
            let identifier = NSUserInterfaceItemIdentifier("SessionActionsCell")
            let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? SessionActionsTableCellView ?? SessionActionsTableCellView()
            cell.identifier = identifier
            cell.configure(
                isSelected: row.isTaskSelected,
                target: self,
                selectAction: #selector(selectSessionTask(_:)),
                editAction: #selector(editSession(_:)),
                deleteAction: #selector(deleteSession(_:)),
                isEnabled: !row.isLockedOut
            )
            return cell
        }

        @objc private func selectSessionTask(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            selectTask(row)
        }

        @objc private func editSession(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            edit(row.session)
        }

        @objc private func deleteSession(_ sender: NSButton) {
            guard let row = rowSnapshot(for: sender) else { return }
            delete(row.session)
        }

        private func rowSnapshot(for sender: NSView) -> SessionTableRow? {
            guard let tableView = enclosingSessionTableView(for: sender) else { return nil }
            let rowIndex = tableView.row(for: sender)
            guard rows.indices.contains(rowIndex) else { return nil }
            return rows[rowIndex]
        }
    }
}

private final class SessionSplitTableHost: NSView {
    let fixedTableView = NSTableView()
    let mainTableView = NSTableView()

    private let fixedHeaderView = SessionHeaderRowView(columns: [.session])
    private let mainHeaderScrollView = NSScrollView()
    private let mainHeaderView = SessionHeaderRowView(columns: SessionAppKitColumn.mainColumns)
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
        mainHeaderScrollView.backgroundColor = SessionAppKitColors.headerFill
        mainHeaderScrollView.contentView.drawsBackground = true
        mainHeaderScrollView.contentView.backgroundColor = SessionAppKitColors.headerFill
        mainHeaderScrollView.translatesAutoresizingMaskIntoConstraints = false
        mainHeaderView.frame = NSRect(
            x: 0,
            y: 0,
            width: SessionAppKitColumn.mainColumns.reduce(CGFloat(0)) { $0 + $1.width },
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
        fixedTableView.addTableColumn(SessionAppKitColumn.session.tableColumn)
        SessionAppKitColumn.mainColumns.forEach { mainTableView.addTableColumn($0.tableColumn) }
        mainTableView.frame.size.width = SessionAppKitColumn.mainColumns.reduce(CGFloat(0)) { $0 + $1.width }
        fixedTableView.frame.size.width = SessionColumns.session
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
        fixedSeparator.layer?.backgroundColor = SessionAppKitColors.tableBorder.cgColor
        headerBottomBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBottomBorder.wantsLayer = true
        headerBottomBorder.layer?.backgroundColor = SessionAppKitColors.tableBorder.cgColor

        NSLayoutConstraint.activate([
            fixedHeaderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fixedHeaderView.topAnchor.constraint(equalTo: topAnchor),
            fixedHeaderView.widthAnchor.constraint(equalToConstant: SessionColumns.session),
            fixedHeaderView.heightAnchor.constraint(equalToConstant: TableMetrics.headerHeight),

            mainHeaderScrollView.leadingAnchor.constraint(equalTo: fixedSeparator.trailingAnchor),
            mainHeaderScrollView.topAnchor.constraint(equalTo: topAnchor),
            mainHeaderScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainHeaderScrollView.heightAnchor.constraint(equalToConstant: TableMetrics.headerHeight),

            fixedScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fixedScrollView.topAnchor.constraint(equalTo: fixedHeaderView.bottomAnchor),
            fixedScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            fixedScrollView.widthAnchor.constraint(equalToConstant: SessionColumns.session),

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

private struct SessionAppKitColumn {
    let id: String
    let title: String
    let width: CGFloat

    var tableColumn: NSTableColumn {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
        column.title = title
        column.width = width
        column.minWidth = width
        column.maxWidth = width
        column.headerCell = SessionHeaderCell(textCell: title)
        column.resizingMask = []
        return column
    }

    static let session = SessionAppKitColumn(id: "session", title: "Session", width: SessionColumns.session)
    static let coreValue = SessionAppKitColumn(id: "coreValue", title: "Core Values", width: SessionColumns.coreValue)
    static let goal = SessionAppKitColumn(id: "goal", title: "Goal", width: SessionColumns.goal)
    static let milestone = SessionAppKitColumn(id: "milestone", title: "Milestone", width: SessionColumns.milestone)
    static let task = SessionAppKitColumn(id: "task", title: "Task", width: SessionColumns.task)
    static let priority = SessionAppKitColumn(id: "priority", title: "Priority", width: SessionColumns.priority)
    static let status = SessionAppKitColumn(id: "status", title: "Status", width: SessionColumns.status)
    static let sessionDate = SessionAppKitColumn(id: "sessionDate", title: "Session Date", width: SessionColumns.sessionDate)
    static let taskType = SessionAppKitColumn(id: "taskType", title: "Task Type", width: SessionColumns.taskType)
    static let what = SessionAppKitColumn(id: "what", title: "What", width: SessionColumns.what)
    static let when = SessionAppKitColumn(id: "when", title: "When", width: SessionColumns.when)
    static let why = SessionAppKitColumn(id: "why", title: "Why", width: SessionColumns.why)
    static let how = SessionAppKitColumn(id: "how", title: "How", width: SessionColumns.how)
    static let howMuch = SessionAppKitColumn(id: "howMuch", title: "How Much", width: SessionColumns.howMuch)
    static let expectedResult = SessionAppKitColumn(id: "expectedResult", title: "Expected Result", width: SessionColumns.expectedResult)
    static let estimatedMinutes = SessionAppKitColumn(id: "estimatedMinutes", title: "Estimated Minutes", width: SessionColumns.estimatedMinutes)
    static let actualMinutes = SessionAppKitColumn(id: "actualMinutes", title: "Actual Minutes", width: SessionColumns.actualMinutes)
    static let sessionNotes = SessionAppKitColumn(id: "sessionNotes", title: "Session Notes", width: SessionColumns.sessionNotes)
    static let linkedAntiGoal = SessionAppKitColumn(id: "linkedAntiGoal", title: "Linked Anti-Goal", width: SessionColumns.linkedAntiGoal)
    static let linkedSacrifice = SessionAppKitColumn(id: "linkedSacrifice", title: "Linked Sacrifice", width: SessionColumns.linkedSacrifice)
    static let actions = SessionAppKitColumn(id: "actions", title: "", width: SessionColumns.actions)

    static let mainColumns: [SessionAppKitColumn] = [
        coreValue,
        goal,
        milestone,
        task,
        priority,
        status,
        sessionDate,
        taskType,
        what,
        when,
        why,
        how,
        howMuch,
        expectedResult,
        estimatedMinutes,
        actualMinutes,
        sessionNotes,
        linkedAntiGoal,
        linkedSacrifice,
        actions
    ]
}

private final class SessionHeaderRowView: NSView {
    private let columns: [SessionAppKitColumn]

    override var isFlipped: Bool { true }

    init(columns: [SessionAppKitColumn]) {
        self.columns = columns
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = SessionAppKitColors.headerFill.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        SessionAppKitColors.headerFill.setFill()
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

private final class SessionHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        SessionAppKitColors.headerFill.setFill()
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

        SessionAppKitColors.tableBorder.setFill()
        NSRect(x: cellFrame.minX, y: cellFrame.maxY - 1, width: cellFrame.width, height: 1).fill()
    }
}

private final class SessionAppKitRowView: NSTableRowView {
    var fillColor: NSColor = .white
    var borderAlpha: CGFloat = 1

    override func drawBackground(in dirtyRect: NSRect) {
        fillColor.setFill()
        dirtyRect.fill()

        SessionAppKitColors.tableBorder.withAlphaComponent(borderAlpha).setFill()
        NSRect(x: bounds.minX, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}

private final class SessionTextTableCellView: NSTableCellView {
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

    func configure(text: String, bold: Bool, placeholder: Bool, alignment: NSTextAlignment, isLockedOut: Bool) {
        label.stringValue = text.isEmpty ? " " : text
        label.alignment = alignment
        label.font = NSFont(
            name: bold ? "Helvetica Neue Bold" : "Helvetica Neue",
            size: TableMetrics.fontSize
        ) ?? (bold ? .boldSystemFont(ofSize: TableMetrics.fontSize) : .systemFont(ofSize: TableMetrics.fontSize))
        let baseAlpha: CGFloat = placeholder ? 0.38 : PriorityTextStyle.opacity(for: text)
        let color = text.trimmingCharacters(in: .whitespacesAndNewlines) == ComputedPriority.highest.displayName
            ? SessionAppKitColors.devotionalRed
            : NSColor.black
        label.textColor = color.withAlphaComponent(isLockedOut ? 0.16 : baseAlpha)
    }
}

private final class SessionStatusTableCellView: NSTableCellView {
    private let circle = SessionStatusCircleAppKitView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        circle.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .black
        label.lineBreakMode = .byTruncatingTail

        let stack = NSStackView(views: [circle, label])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        addSubview(stack)

        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 18),
            circle.heightAnchor.constraint(equalToConstant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: TableMetrics.textInset),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -TableMetrics.textInset),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(status: SessionStatus, isLockedOut: Bool) {
        circle.status = status
        circle.alphaValue = isLockedOut ? 0.16 : 1
        label.stringValue = status.displayName
        let isBold = StatusTextStyle.usesBoldWeight(status.displayName)
        label.font = NSFont(
            name: isBold ? "Helvetica Neue Bold" : "Helvetica Neue",
            size: TableMetrics.fontSize
        ) ?? (isBold ? .boldSystemFont(ofSize: TableMetrics.fontSize) : .systemFont(ofSize: TableMetrics.fontSize))
        label.textColor = NSColor.black.withAlphaComponent(isLockedOut ? 0.16 : 1)
    }
}

private final class SessionStatusCircleAppKitView: NSView {
    var status: SessionStatus = .notStarted {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let circleRect = bounds.insetBy(dx: 2, dy: 2)
        let circlePath = NSBezierPath(ovalIn: circleRect)

        switch status {
        case .completed:
            SessionAppKitColors.completed.setFill()
            circlePath.fill()
        case .partial:
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: circleRect.minX, y: circleRect.minY, width: circleRect.width / 2, height: circleRect.height)).addClip()
            SessionAppKitColors.active.setFill()
            circlePath.fill()
            NSGraphicsContext.restoreGraphicsState()
        case .notStarted:
            break
        }

        NSColor.black.withAlphaComponent(0.45).setStroke()
        circlePath.lineWidth = 1.4
        circlePath.stroke()
    }
}

private final class SessionActionsTableCellView: NSTableCellView {
    private let selectButton = SessionActionButton(symbolName: "checkmark.circle.fill")
    private let editButton = SessionActionButton(symbolName: "pencil")
    private let deleteButton = SessionActionButton(symbolName: "trash")

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
            tint: SessionAppKitColors.moduleIconRed,
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
            tint: SessionAppKitColors.deleteAccent,
            toolTip: "Delete",
            target: isEnabled ? target : nil,
            action: isEnabled ? deleteAction : nil,
            isEnabled: isEnabled
        )
    }
}

private final class SessionActionButton: NSButton {
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

private enum SessionAppKitColors {
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

private extension SessionStatus {
    var sessionRowNSColor: NSColor {
        switch self {
        case .completed:
            return SessionAppKitColors.rowCompleted
        case .partial:
            return SessionAppKitColors.creamWork
        case .notStarted:
            return .white
        }
    }
}

private extension NSColor {
    var dimmedForSessionFocusLock: NSColor {
        blended(withFraction: 0.82, of: .white) ?? withAlphaComponent(0.18)
    }
}

private func enclosingSessionTableView(for view: NSView) -> NSTableView? {
    var candidate: NSView? = view
    while let current = candidate {
        if let tableView = current as? NSTableView {
            return tableView
        }
        candidate = current.superview
    }
    return nil
}

private struct SessionTableRow: Identifiable {
    let id: UUID
    let session: WorkSession
    let label: String
    let taskID: UUID?
    let coreValueName: String
    let goalText: String
    let milestoneText: String
    let taskName: String
    let priority: String
    let status: SessionStatus
    let sessionDateText: String
    let taskTypeText: String
    let expectedResult: String
    let whatText: String
    let whenText: String
    let whyText: String
    let howText: String
    let howMuchText: String
    let estimatedMinutesText: String
    let actualMinutesText: String
    let sessionNotes: String
    let linkedAntiGoal: String
    let linkedSacrifice: String
    let isStandaloneTask: Bool
    let isTaskSelected: Bool
    let isLockedOut: Bool
    let height: CGFloat

    init(
        session: WorkSession,
        selectedTaskID: UUID?,
        goalPriorities: [UUID: ComputedPriority],
        isLockedOut: Bool,
        heightCache: SessionRowHeightCache
    ) {
        let label = session.displayLabel
        let task = session.task
        let taskID = task?.id
        let coreValueName = session.coreValueName
        let goalText = task?.displayGoalName ?? session.goalName
        let milestoneText = task?.displayMilestoneName ?? session.milestoneName
        let taskName = session.taskName
        let priority = task.map { GoalPriorityService.displayPriority(for: $0, goalPriorities: goalPriorities).displayName } ?? ""
        let status = session.status
        let sessionDateText = session.sessionDate.map { DateUtils.displayDate($0) } ?? ""
        let taskTypeText = session.taskType.rawValue
        let expectedResult = session.expectedResult
        let whatText = session.whatText
        let whenText = session.whenText
        let whyText = session.whyText
        let howText = session.howText
        let howMuchText = session.howMuchText
        let estimatedMinutesText = Formatters.minutes(session.estimatedMinutesValue)
        let actualMinutesText = Formatters.minutes(session.actualMinutesValue)
        let sessionNotes = session.sessionNotes
        let linkedAntiGoal = session.linkedAntiGoal
        let linkedSacrifice = session.linkedSacrifice
        let isStandaloneTask = task?.isStandalone == true
        let heightKey = SessionRowHeightKey(
            id: session.id,
            label: label,
            taskName: taskName,
            coreValueName: coreValueName,
            goalText: goalText,
            milestoneText: milestoneText,
            priority: priority,
            status: status.displayName,
            sessionDateText: sessionDateText,
            taskTypeText: taskTypeText,
            expectedResult: expectedResult,
            whatText: whatText,
            whenText: whenText,
            whyText: whyText,
            howText: howText,
            howMuchText: howMuchText,
            estimatedMinutesText: estimatedMinutesText,
            actualMinutesText: actualMinutesText,
            sessionNotes: sessionNotes,
            linkedAntiGoal: linkedAntiGoal,
            linkedSacrifice: linkedSacrifice
        )

        self.id = session.id
        self.session = session
        self.label = label
        self.taskID = taskID
        self.coreValueName = coreValueName
        self.goalText = goalText
        self.milestoneText = milestoneText
        self.taskName = taskName
        self.priority = priority
        self.status = status
        self.sessionDateText = sessionDateText
        self.taskTypeText = taskTypeText
        self.expectedResult = expectedResult
        self.whatText = whatText
        self.whenText = whenText
        self.whyText = whyText
        self.howText = howText
        self.howMuchText = howMuchText
        self.estimatedMinutesText = estimatedMinutesText
        self.actualMinutesText = actualMinutesText
        self.sessionNotes = sessionNotes
        self.linkedAntiGoal = linkedAntiGoal
        self.linkedSacrifice = linkedSacrifice
        self.isStandaloneTask = isStandaloneTask
        self.isTaskSelected = taskID.map { selectedTaskID == $0 } ?? false
        self.isLockedOut = isLockedOut
        self.height = heightCache.height(for: heightKey, columns: [
            (label, SessionColumns.session),
            (taskName, SessionColumns.task),
            (coreValueName, SessionColumns.coreValue),
            (goalText, SessionColumns.goal),
            (milestoneText, SessionColumns.milestone),
            (priority, SessionColumns.priority),
            (status.displayName, SessionColumns.status),
            (sessionDateText, SessionColumns.sessionDate),
            (taskTypeText, SessionColumns.taskType),
            (whatText, SessionColumns.what),
            (whenText, SessionColumns.when),
            (whyText, SessionColumns.why),
            (howText, SessionColumns.how),
            (howMuchText, SessionColumns.howMuch),
            (expectedResult, SessionColumns.expectedResult),
            (estimatedMinutesText, SessionColumns.estimatedMinutes),
            (actualMinutesText, SessionColumns.actualMinutes),
            (sessionNotes, SessionColumns.sessionNotes),
            (linkedAntiGoal, SessionColumns.linkedAntiGoal),
            (linkedSacrifice, SessionColumns.linkedSacrifice)
        ])
    }

    static func rows(
        from sessions: [WorkSession],
        selectedTaskID: UUID?,
        goalPriorities: [UUID: ComputedPriority],
        isLockedOut: (WorkSession) -> Bool,
        heightCache: SessionRowHeightCache
    ) -> [SessionTableRow] {
        return sessions.map { session in
            return SessionTableRow(
                session: session,
                selectedTaskID: selectedTaskID,
                goalPriorities: goalPriorities,
                isLockedOut: isLockedOut(session),
                heightCache: heightCache
            )
        }
    }
}

private final class SessionRowHeightCache {
    private var heights: [SessionRowHeightKey: CGFloat] = [:]

    func removeAll() {
        heights.removeAll(keepingCapacity: true)
    }

    func height(for key: SessionRowHeightKey, columns: [(text: String, width: CGFloat)]) -> CGFloat {
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

private struct SessionRowHeightKey: Hashable {
    let id: UUID
    let label: String
    let taskName: String
    let coreValueName: String
    let goalText: String
    let milestoneText: String
    let priority: String
    let status: String
    let sessionDateText: String
    let taskTypeText: String
    let expectedResult: String
    let whatText: String
    let whenText: String
    let whyText: String
    let howText: String
    let howMuchText: String
    let estimatedMinutesText: String
    let actualMinutesText: String
    let sessionNotes: String
    let linkedAntiGoal: String
    let linkedSacrifice: String
}

private struct SessionStatusCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let status: SessionStatus
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            SessionStatusCircle(status: status, size: 18)
            Text(status.displayName)
                .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(fontWeight))
                .foregroundStyle(Color.black)
        }
        .padding(TableMetrics.textInset)
        .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .background(Color.clear)
    }

    private var fontWeight: Font.Weight {
        StatusTextStyle.usesBoldWeight(status.displayName) ? .bold : .regular
    }
}

struct SessionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var tasks: FetchedResults<TaskItem>
    @FetchRequest(sortDescriptors: []) private var goals: FetchedResults<Goal>
    @AppStorage("GoalTracker.confirmSessionDateClear") private var confirmSessionDateClear = true

    let session: WorkSession?
    let defaultTask: TaskItem?
    let onSave: () -> Void

    @State private var sessionLabel: String
    @State private var selectedTaskID: UUID?
    @State private var estimatedMinutes: Int
    @State private var actualMinutes: Int
    @State private var expectedResult: String
    @State private var whatText: String
    @State private var whenText: String
    @State private var whyText: String
    @State private var howText: String
    @State private var howMuchText: String
    @State private var status: SessionStatus
    @State private var sessionDate: Date?
    @State private var sessionNotes: String
    @State private var error: String?
    @State private var askClearDate = false
    @State private var sessionDateEditedManually = false

    init(session: WorkSession?, defaultTask: TaskItem?, onSave: @escaping () -> Void = {}) {
        self.session = session
        self.defaultTask = defaultTask
        self.onSave = onSave
        _sessionLabel = State(initialValue: session?.sessionLabel ?? "")
        _selectedTaskID = State(initialValue: session?.task?.id ?? defaultTask?.id)
        _estimatedMinutes = State(initialValue: session?.estimatedMinutesValue ?? defaultTask?.estimatedMinutesValue ?? 0)
        _actualMinutes = State(initialValue: session?.actualMinutesValue ?? 0)
        _expectedResult = State(initialValue: session?.expectedResult ?? "")
        _whatText = State(initialValue: session?.whatText ?? "")
        _whenText = State(initialValue: session?.whenText ?? "")
        _whyText = State(initialValue: session?.whyText ?? "")
        _howText = State(initialValue: session?.howText ?? "")
        _howMuchText = State(initialValue: session?.howMuchText ?? "")
        _status = State(initialValue: session?.status ?? .notStarted)
        _sessionDate = State(initialValue: session?.sessionDate)
        _sessionNotes = State(initialValue: session?.sessionNotes ?? "")
    }

    private var selectedTask: TaskItem? {
        tasks.first { $0.id == selectedTaskID } ?? defaultTask
    }

    private var sortedTasks: [TaskItem] {
        let priorities = GoalPriorityService.priorities(for: Array(goals))
        return tasks.sorted { left, right in
            if left.baseComputedStatus.focusRank != right.baseComputedStatus.focusRank {
                return left.baseComputedStatus.focusRank < right.baseComputedStatus.focusRank
            }
            return GoalTrackerSort.tasks(left, right, goalPriorities: priorities)
        }
    }

    private var isAdding: Bool {
        session == nil
    }

    private var previousSessionsForSelectedTask: [WorkSession] {
        guard isAdding else { return [] }
        return SessionFocusService.orderedSessions(for: selectedTask)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(isAdding ? "Add Session" : "Edit Session")
                    .font(.title2.weight(.bold))

                Picker("Task", selection: $selectedTaskID) {
                    Text("Select Task").tag(nil as UUID?)
                    ForEach(sortedTasks) { task in
                        Text("\(task.name)  |  \(task.pickerSummary)")
                            .tag(task.id as UUID?)
                    }
                }

                if isAdding, selectedTask != nil {
                    PreviousSessionsPreview(sessions: previousSessionsForSelectedTask)
                }

                TextField("Session", text: $sessionLabel)
                    .textFieldStyle(.roundedBorder)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ReadOnlyField(title: "Core Value", value: selectedTask?.coreValueName ?? "")
                    ReadOnlyField(title: "Goal", value: selectedTask?.displayGoalName ?? "", muted: selectedTask?.isStandalone == true)
                    ReadOnlyField(title: "Milestone", value: selectedTask?.displayMilestoneName ?? "", muted: selectedTask?.isStandalone == true)
                    ReadOnlyField(title: "Task Type", value: selectedTask?.taskType.rawValue ?? "Select a Task")
                    if !isAdding {
                        ReadOnlyField(title: "Status", value: status.displayName)
                    }
                }

                Stepper("Estimated Minutes: \(estimatedMinutes)", value: $estimatedMinutes, in: 0...10_000, step: 5)

                SessionEditorTextBox(title: "Expected Result", text: $expectedResult, minHeight: 90)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    SessionEditorTextBox(title: "What", text: $whatText)
                    SessionEditorTextBox(title: "When", text: $whenText)
                    SessionEditorTextBox(title: "Why", text: $whyText)
                    SessionEditorTextBox(title: "How", text: $howText)
                    SessionEditorTextBox(title: "How Much", text: $howMuchText)
                }

                if !isAdding {
                    Stepper("Actual Minutes: \(actualMinutes)", value: $actualMinutes, in: 0...10_000, step: 5)

                    SessionStatusPicker(status: $status)
                        .onChange(of: status) { _, newValue in
                            if newValue.usesAutomaticSessionDate {
                                sessionDate = SessionDatePolicy.dateAfterStatusChange(to: newValue, currentDate: sessionDate)
                                sessionDateEditedManually = false
                            } else if newValue == .notStarted && sessionDate != nil {
                                if confirmSessionDateClear {
                                    askClearDate = true
                                } else {
                                    sessionDate = nil
                                    sessionDateEditedManually = false
                                }
                            }
                        }

                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Session Date")
                                .foregroundStyle(.secondary)
                            if sessionDate != nil {
                                DatePicker(
                                    "Session Date",
                                    selection: Binding(
                                        get: { sessionDate ?? Date() },
                                        set: {
                                            sessionDate = $0
                                            sessionDateEditedManually = true
                                        }
                                    ),
                                    displayedComponents: .date
                                )
                                Button("Clear Date") {
                                    sessionDate = nil
                                    sessionDateEditedManually = true
                                }
                                    .buttonStyle(.link)
                            } else {
                                Button("Set Today") {
                                    sessionDate = Date()
                                    sessionDateEditedManually = true
                                }
                            }
                        }
                        .frame(width: 220, alignment: .leading)

                        SessionEditorTextBox(title: "Session Notes", text: $sessionNotes, minHeight: 86)
                    }

                    HStack {
                        ReadOnlyField(title: "Linked Anti-Goal", value: selectedTask?.milestone?.goal?.antiGoal ?? "")
                        ReadOnlyField(title: "Linked Sacrifice", value: selectedTask?.milestone?.goal?.sacrifice ?? "")
                    }
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
        }
        .frame(width: 860)
        .frame(maxHeight: 780)
        .confirmationDialog("Clear Session Date?", isPresented: $askClearDate) {
            Button("Clear Date", role: .destructive) {
                sessionDate = nil
                sessionDateEditedManually = false
            }
            Button("Keep Date", role: .cancel) { }
        } message: {
            Text("Status is now Not Started. You can clear the Session Date or keep it for record-keeping.")
        }
    }

    private func save() {
        let cleanedSessionLabel = sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validation = ValidationService.validateSession(
            sessionLabel: cleanedSessionLabel,
            task: selectedTask,
            estimatedMinutes: estimatedMinutes,
            actualMinutes: actualMinutes
        ) {
            error = validation
            return
        }

        let previousTask = session?.task
        let target: WorkSession
        if let session {
            target = session
        } else {
            target = WorkSession(context: managedObjectContext, task: selectedTask)
        }

        target.task = selectedTask
        target.sessionLabel = cleanedSessionLabel
        target.estimatedMinutesValue = ValidationService.clampMinutes(estimatedMinutes)
        target.actualMinutesValue = ValidationService.clampMinutes(actualMinutes)
        target.expectedResult = expectedResult
        target.whatText = whatText
        target.whenText = whenText
        target.whyText = whyText
        target.howText = howText
        target.howMuchText = howMuchText
        let previousStatus = session?.status
        target.status = status
        target.sessionDate = SessionDatePolicy.resolvedDateForSave(
            previousStatus: previousStatus,
            newStatus: status,
            proposedDate: sessionDate,
            dateWasManuallyEdited: sessionDateEditedManually
        )
        target.sessionNotes = sessionNotes
        let now = Date()
        target.updatedAt = now
        TaskStatusService.refreshStoredStatus(for: previousTask, now: now)
        TaskStatusService.refreshStoredStatus(for: selectedTask, now: now)
        RelationshipRefreshService.touchTaskLineage(previousTask, now: now)
        RelationshipRefreshService.touchSessionLineage(target, now: now)

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

private struct SessionEditorTextBox: View {
    let title: String
    @Binding var text: String
    var minHeight: CGFloat = 82

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
                .frame(minHeight: minHeight)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        }
    }
}

private struct PreviousSessionsPreview: View {
    let sessions: [WorkSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Previous Sessions")
                    .font(.custom("Helvetica Neue", size: 13).weight(.bold))
                    .foregroundStyle(Color.black)
                Text("\(sessions.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.black.opacity(0.62))
                Spacer()
            }

            if sessions.isEmpty {
                Text("No previous sessions for this task.")
                    .font(.custom("Helvetica Neue", size: 12))
                    .foregroundStyle(Color.black.opacity(0.58))
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.black.opacity(0.5))
                                    .frame(width: 24, alignment: .trailing)

                                SessionStatusCircle(status: session.status, size: 14)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.displayLabel)
                                        .font(.custom("Helvetica Neue", size: 12).weight(.semibold))
                                        .foregroundStyle(Color.black)
                                        .lineLimit(1)
                                    Text(session.expectedResult.isEmpty ? "No expected result" : session.expectedResult)
                                        .font(.custom("Helvetica Neue", size: 11))
                                        .foregroundStyle(Color.black.opacity(0.58))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(session.status.displayName)
                                    .font(.custom("Helvetica Neue", size: 11).weight(StatusTextStyle.usesBoldWeight(session.status.displayName) ? .bold : .regular))
                                    .foregroundStyle(Color.black.opacity(0.78))

                                Text(session.sessionDate.map { DateUtils.displayDate($0) } ?? "No date")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(Color.black.opacity(0.5))
                                    .frame(width: 70, alignment: .trailing)
                            }
                            .padding(.vertical, 7)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(GoalTrackerTheme.tableBorder.opacity(0.55)).frame(height: 1)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(12)
        .background(GoalTrackerTheme.creamWork.opacity(0.58))
        .overlay(
            Rectangle().stroke(GoalTrackerTheme.appYellow.opacity(0.26), lineWidth: 1)
        )
    }
}
