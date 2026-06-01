import AppKit
import SwiftUI

enum TableMetrics {
    static let fontSize: CGFloat = 14
    static let textInset: CGFloat = 14
    static let rowHeight: CGFloat = 64
    static let headerHeight: CGFloat = 40
    static let lineSpacing: CGFloat = fontSize * 0.2
    static let actionColumnWidth: CGFloat = 176
    static let focusPlaceholderHeight: CGFloat = 36

    static func columnWidth(_ title: String, min minimumWidth: CGFloat) -> CGFloat {
        let font = NSFont(name: "Helvetica Neue Bold", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return max(minimumWidth, ceil(textWidth + (textInset * 2) + 32))
    }

    static func rowHeight(for columns: [(text: String, width: CGFloat)]) -> CGFloat {
        let font = NSFont(name: "Helvetica Neue", size: fontSize) ?? .systemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let tallestText = columns.map { column in
            let text = column.text.isEmpty ? " " : column.text
            let availableWidth = max(12, column.width - (textInset * 2))
            let bounds = (text as NSString).boundingRect(
                with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: attributes
            )
            return ceil(bounds.height)
        }.max() ?? 0

        return max(rowHeight, ceil(tallestText + (textInset * 2) + 2))
    }
}

private struct GoalTrackerTableRowHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = TableMetrics.rowHeight
}

extension EnvironmentValues {
    var goalTrackerTableRowHeight: CGFloat {
        get { self[GoalTrackerTableRowHeightKey.self] }
        set { self[GoalTrackerTableRowHeightKey.self] = newValue }
    }
}

struct ModuleHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var actions: Actions

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Text(title)
                    .font(.custom("Helvetica Neue", size: 28).weight(.bold))
                    .multilineTextAlignment(.center)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.custom("Helvetica Neue", size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 720)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            actions
                .buttonStyle(GoalTrackerDimButtonStyle())
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 8)
    }
}

struct CenteredHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.custom("Helvetica Neue", size: 28).weight(.bold))
                .multilineTextAlignment(.center)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.custom("Helvetica Neue", size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 720)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 8)
    }
}

struct SheetHeaderSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.custom("Helvetica Neue", size: 13))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 9)
        .frame(width: 220, height: 30)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var iconColor: Color = .secondary

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

struct HeaderCell: View {
    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(.bold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .lineSpacing(TableMetrics.lineSpacing)
            .padding(TableMetrics.textInset)
            .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: TableMetrics.headerHeight, maxHeight: TableMetrics.headerHeight, alignment: .leading)
            .background(GoalTrackerTheme.headerFill)
    }
}

struct DataCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let text: String
    let width: CGFloat
    var bold: Bool = false
    var computed: Bool = false
    var dimmed: Bool = false
    var placeholder: Bool = false

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(bold ? .bold : .regular))
            .foregroundStyle(textColor.opacity(placeholder ? 0.38 : PriorityTextStyle.opacity(for: text)))
            .lineLimit(nil)
            .lineSpacing(TableMetrics.lineSpacing)
            .padding(TableMetrics.textInset)
            .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
            .background(Color.clear)
    }

    private var textColor: Color {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == ComputedPriority.highest.displayName
            ? GoalTrackerTheme.devotionalRed
            : Color.black
    }
}

struct NumberCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let text: String
    let width: CGFloat

    var body: some View {
        Text(text)
            .font(.custom("Helvetica Neue", size: TableMetrics.fontSize))
            .monospacedDigit()
            .foregroundStyle(Color.black)
            .lineLimit(nil)
            .lineSpacing(TableMetrics.lineSpacing)
            .padding(TableMetrics.textInset)
            .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
            .background(Color.clear)
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(fontWeight))
            .foregroundStyle(Color.black)
            .lineLimit(nil)
            .lineSpacing(TableMetrics.lineSpacing)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var fontWeight: Font.Weight {
        StatusTextStyle.usesBoldWeight(text) ? .bold : .regular
    }
}

struct StatusCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let text: String
    let color: Color
    let width: CGFloat

    var body: some View {
        HStack {
            StatusBadge(text: text, color: color)
            Spacer(minLength: 0)
        }
        .padding(TableMetrics.textInset)
        .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .background(Color.clear)
    }
}

struct ProgressCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let value: Double
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Formatters.percent(value))
                .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.black)
            ProgressView(value: min(max(value, 0), 100), total: 100)
                .progressViewStyle(.linear)
        }
        .padding(TableMetrics.textInset)
        .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .leading)
        .tint(GoalTrackerTheme.secondaryAccent)
    }
}

struct IconActionButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .black
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(GoalTrackerTableActionIconButtonStyle(tint: tint))
        .help(title)
    }
}

private struct GoalTrackerTableActionIconButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerTableActionIconButton(configuration: configuration, tint: tint)
    }

    private struct GoalTrackerTableActionIconButton: View {
        let configuration: ButtonStyle.Configuration
        let tint: Color
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(tint.opacity(foregroundOpacity))
                .frame(width: 28, height: 28)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.28)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var foregroundOpacity: Double {
            if configuration.isPressed { return 0.86 }
            if isHovering { return 0.72 }
            return 0.20
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.26)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.12)
            }
            return Color.clear
        }

        private var borderColor: Color {
            if configuration.isPressed || isHovering {
                return GoalTrackerTheme.secondaryAccent.opacity(0.26)
            }
            return Color.clear
        }
    }
}

struct TableActionsCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let edit: () -> Void
    let delete: () -> Void
    var isEnabled = true
    var selectTitle: String?
    var selectImage: String?
    var select: (() -> Void)?
    var extraTitle: String?
    var extraImage: String?
    var extra: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if let selectTitle, let selectImage, let select {
                IconActionButton(title: selectTitle, systemImage: selectImage, tint: GoalTrackerTheme.moduleIconRed, action: select)
            }
            IconActionButton(title: "Edit", systemImage: "pencil", action: edit)
            IconActionButton(title: "Delete", systemImage: "trash", tint: .red, action: delete)
            if let extraTitle, let extraImage, let extra {
                IconActionButton(title: extraTitle, systemImage: extraImage, action: extra)
            }
        }
        .padding(TableMetrics.textInset)
        .frame(
            minWidth: TableMetrics.actionColumnWidth,
            idealWidth: TableMetrics.actionColumnWidth,
            maxWidth: TableMetrics.actionColumnWidth,
            minHeight: rowHeight,
            maxHeight: rowHeight,
            alignment: .leading
        )
        .disabled(!isEnabled)
        .allowsHitTesting(isEnabled)
    }
}

struct TableScrollTarget: Equatable {
    let id: AnyHashable
    let nonce: Int
}

struct FixedFeatureTable<FixedHeader: View, FixedRows: View, ScrollHeader: View, ScrollRows: View>: View {
    @State private var horizontalOffset: CGFloat = 0

    var fixedColumnWidth: CGFloat = 240
    var contentHeight: CGFloat?
    var scrollTarget: TableScrollTarget? = nil
    @ViewBuilder let fixedHeader: FixedHeader
    @ViewBuilder let fixedRows: FixedRows
    @ViewBuilder let scrollHeader: ScrollHeader
    @ViewBuilder let scrollRows: ScrollRows

    var body: some View {
        GeometryReader { proxy in
            tableBody
                .frame(
                    width: proxy.size.width,
                    height: resolvedHeight(availableHeight: proxy.size.height),
                    alignment: .topLeading
                )
                .tableContainer()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var tableBody: some View {
        ZStack(alignment: .topLeading) {
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Color.clear
                                .frame(width: fixedColumnWidth, height: TableMetrics.headerHeight)
                            fixedRows
                        }
                        .frame(width: fixedColumnWidth, alignment: .leading)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(GoalTrackerTheme.tableBorder)
                                .frame(width: 1)
                        }
                        .zIndex(1)

                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 0) {
                                HorizontalScrollOffsetReader { offset in
                                    horizontalOffset = offset
                                }
                                .frame(width: 0, height: 0)

                                Color.clear
                                    .frame(height: TableMetrics.headerHeight)

                                scrollRows
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation(.easeOut(duration: 0.18)) {
                        scrollProxy.scrollTo(target.id, anchor: .top)
                    }
                }
            }

            HStack(spacing: 0) {
                fixedHeader
                    .frame(width: fixedColumnWidth, height: TableMetrics.headerHeight, alignment: .leading)
                    .background(GoalTrackerTheme.headerFill)
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(GoalTrackerTheme.tableBorder)
                            .frame(width: 1)
                    }
                    .zIndex(2)

                GeometryReader { _ in
                    scrollHeader
                        .offset(x: horizontalOffset)
                        .frame(height: TableMetrics.headerHeight, alignment: .leading)
                }
                .frame(height: TableMetrics.headerHeight)
                .background(GoalTrackerTheme.headerFill)
                .clipped()
            }
            .frame(height: TableMetrics.headerHeight, alignment: .topLeading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(GoalTrackerTheme.tableBorder)
                    .frame(height: 1)
            }
            .zIndex(3)
        }
    }

    private func resolvedHeight(availableHeight: CGFloat) -> CGFloat {
        guard let contentHeight else { return availableHeight }
        let minimumHeight = TableMetrics.headerHeight + TableMetrics.rowHeight
        return min(max(contentHeight, minimumHeight), availableHeight)
    }
}

private struct HorizontalScrollOffsetReader: NSViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> HorizontalOffsetTrackingView {
        let view = HorizontalOffsetTrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: HorizontalOffsetTrackingView, context: Context) {
        nsView.onChange = onChange
        nsView.attachToEnclosingScrollView()
    }

    static func dismantleNSView(_ nsView: HorizontalOffsetTrackingView, coordinator: ()) {
        nsView.stopTracking()
    }
}

private final class HorizontalOffsetTrackingView: NSView {
    var onChange: (CGFloat) -> Void = { _ in }

    private weak var trackedClipView: NSClipView?
    private var boundsObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.attachToEnclosingScrollView()
        }
    }

    func attachToEnclosingScrollView() {
        guard let clipView = enclosingScrollView?.contentView else { return }
        guard trackedClipView !== clipView else {
            publishOffset()
            return
        }

        stopTracking()
        trackedClipView = clipView
        clipView.postsBoundsChangedNotifications = true
        boundsObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.publishOffset()
        }
        publishOffset()
    }

    func stopTracking() {
        if let boundsObserver {
            NotificationCenter.default.removeObserver(boundsObserver)
        }
        boundsObserver = nil
        trackedClipView = nil
    }

    private func publishOffset() {
        onChange(-(trackedClipView?.bounds.origin.x ?? 0))
    }

    deinit {
        stopTracking()
    }
}

struct SessionStatusCircle: View {
    let status: SessionStatus
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.45), lineWidth: 1.5)

            switch status {
            case .notStarted:
                EmptyView()
            case .partial:
                Circle()
                    .fill(GoalTrackerTheme.active)
                    .frame(width: size, height: size)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: size / 2)
                            Spacer(minLength: 0)
                        }
                    )
            case .completed:
                Circle()
                    .fill(GoalTrackerTheme.completed)
                    .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(status.displayName)
    }
}

struct SessionStatusPicker: View {
    @Binding var status: SessionStatus

    var body: some View {
        Picker("Status", selection: $status) {
            ForEach(SessionStatus.allCases) { state in
                Text(state.displayName)
                    .tag(state)
            }
        }
        .pickerStyle(.segmented)
        .tint(GoalTrackerTheme.secondaryAccent)
    }
}

struct ReadOnlyField: View {
    let title: String
    let value: String
    var muted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? " " : value)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(GoalTrackerTheme.computedFill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(Color.primary.opacity(muted ? 0.42 : 1))
        }
    }
}

struct FormErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension GoalPriority {
    var sortRank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

extension TaskPriority {
    var sortRank: Int {
        switch self {
        case .highest: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }
}

extension GoalStatus {
    var focusRank: Int {
        switch self {
        case .inProgress: 0
        case .overdue: 1
        case .notStarted: 2
        case .notPlanned: 3
        case .completed: 4
        }
    }
}

extension MilestoneStatus {
    var focusRank: Int {
        switch self {
        case .inProgress: 0
        case .overdue: 1
        case .notStarted: 2
        case .completed: 3
        }
    }
}

extension TaskStatus {
    var focusRank: Int {
        switch self {
        case .active: 0
        case .partiallyCompleted: 1
        case .notStarted: 2
        case .completed: 3
        }
    }
}

extension SessionStatus {
    var focusRank: Int {
        switch self {
        case .partial: 0
        case .notStarted: 1
        case .completed: 2
        }
    }
}

enum GoalTrackerSort {
    static func goals(_ left: Goal, _ right: Goal) -> Bool {
        goals(left, right, priorities: [
            left.id: GoalPriorityService.standalonePriority(for: left),
            right.id: GoalPriorityService.standalonePriority(for: right)
        ])
    }

    static func goals(_ left: Goal, _ right: Goal, priorities: [UUID: ComputedPriority]) -> Bool {
        let leftPriority = priorities[left.id] ?? GoalPriorityService.standalonePriority(for: left)
        let rightPriority = priorities[right.id] ?? GoalPriorityService.standalonePriority(for: right)
        if leftPriority.sortRank != rightPriority.sortRank {
            return leftPriority.sortRank < rightPriority.sortRank
        }

        if leftPriority == .none && rightPriority == .none {
            let leftCompleted = left.status == .completed
            let rightCompleted = right.status == .completed
            if leftCompleted != rightCompleted {
                return !leftCompleted
            }
            if left.computedProgress != right.computedProgress {
                return left.computedProgress > right.computedProgress
            }
        }

        if left.status.focusRank != right.status.focusRank {
            return left.status.focusRank < right.status.focusRank
        }

        if left.startDate != right.startDate {
            return left.startDate < right.startDate
        }
        if left.endDate != right.endDate {
            return left.endDate < right.endDate
        }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    static func milestones(_ left: Milestone, _ right: Milestone) -> Bool {
        milestones(left, right, priorities: [:])
    }

    static func milestones(_ left: Milestone, _ right: Milestone, priorities: [UUID: ComputedPriority]) -> Bool {
        let leftGoal = left.goal
        let rightGoal = right.goal
        if leftGoal?.id != rightGoal?.id {
            return goalSheetContextPrecedes(leftGoal, rightGoal, priorities: priorities)
        }
        if left.startDate != right.startDate { return left.startDate < right.startDate }
        return false
    }

    static func tasks(_ left: TaskItem, _ right: TaskItem) -> Bool {
        tasks(left, right, goalPriorities: [:])
    }

    static func tasks(_ left: TaskItem, _ right: TaskItem, goalPriorities: [UUID: ComputedPriority]) -> Bool {
        let leftPriorityRank = taskPriorityRank(left, goalPriorities: goalPriorities)
        let rightPriorityRank = taskPriorityRank(right, goalPriorities: goalPriorities)
        if leftPriorityRank != rightPriorityRank {
            return leftPriorityRank < rightPriorityRank
        }

        let leftMilestone = left.milestone
        let rightMilestone = right.milestone
        if leftMilestone == nil || rightMilestone == nil {
            if leftMilestone == nil && rightMilestone == nil {
                if left.createdAt != right.createdAt { return left.createdAt > right.createdAt }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
            return leftMilestone == nil
        }

        let leftGoal = leftMilestone?.goal
        let rightGoal = rightMilestone?.goal
        if leftGoal?.id != rightGoal?.id {
            return goalSheetContextPrecedes(leftGoal, rightGoal, priorities: goalPriorities)
        }
        if leftMilestone?.id != rightMilestone?.id {
            return milestoneContextPrecedes(leftMilestone, rightMilestone)
        }
        if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    static func sessions(_ left: WorkSession, _ right: WorkSession) -> Bool {
        sessions(left, right, goalPriorities: [:])
    }

    static func sessions(_ left: WorkSession, _ right: WorkSession, goalPriorities: [UUID: ComputedPriority]) -> Bool {
        let leftTask = left.task
        let rightTask = right.task

        if leftTask?.id != rightTask?.id {
            guard let leftTask else { return false }
            guard let rightTask else { return true }
            return tasks(leftTask, rightTask, goalPriorities: goalPriorities)
        }

        if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
        return left.id.uuidString < right.id.uuidString
    }

    private static func goalContextPrecedes(_ left: Goal?, _ right: Goal?) -> Bool {
        guard let left else { return false }
        guard let right else { return true }
        if left.startDate != right.startDate { return left.startDate < right.startDate }
        if left.endDate != right.endDate { return left.endDate < right.endDate }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    private static func goalSheetContextPrecedes(_ left: Goal?, _ right: Goal?, priorities: [UUID: ComputedPriority]) -> Bool {
        guard let left else { return false }
        guard let right else { return true }
        return goals(left, right, priorities: priorities)
    }

    private static func milestoneContextPrecedes(_ left: Milestone?, _ right: Milestone?) -> Bool {
        guard let left else { return false }
        guard let right else { return true }
        if left.startDate != right.startDate { return left.startDate < right.startDate }
        if left.endDate != right.endDate { return left.endDate < right.endDate }
        return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
    }

    private static func goalPriorityRank(_ goal: Goal?, priorities: [UUID: ComputedPriority]) -> Int {
        guard let goal else { return ComputedPriority.none.sortRank }
        return (priorities[goal.id] ?? GoalPriorityService.standalonePriority(for: goal)).sortRank
    }

    private static func taskPriorityRank(_ task: TaskItem, goalPriorities: [UUID: ComputedPriority]) -> Int {
        GoalPriorityService.displayPriority(for: task, goalPriorities: goalPriorities).sortRank
    }
}
