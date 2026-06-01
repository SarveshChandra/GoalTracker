import CoreData
import SwiftUI

struct ValuesView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest(sortDescriptors: []) private var values: FetchedResults<CoreValue>
    @AppStorage("GoalTracker.myValues") private var myValuesRaw = ""
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @State private var showAddValueEditor = false
    @State private var editingValue: CoreValue?
    @State private var deleteCandidate: CoreValue?
    @State private var showAddMyValueEditor = false
    @State private var editingMyValue: MyValue?
    @State private var valuesRefreshID = 0

    private var filteredValues: [CoreValue] {
        values
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var myValues: [MyValue] {
        MyValueStore.decode(myValuesRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Values Sheet",
                subtitle: ""
            ) {
                EmptyView()
            }
            .padding(.top, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    myValuesSection
                    coreValuesSection
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 24)
            }
        }
        .padding(24)
        .sheet(isPresented: $showAddValueEditor) {
            ValueEditor(value: nil, onSave: refreshValueRows)
        }
        .sheet(item: $editingValue) { value in
            ValueEditor(value: value, onSave: refreshValueRows)
        }
        .sheet(isPresented: $showAddMyValueEditor) {
            MyValueEditor(value: nil) { savedValue in
                saveMyValue(savedValue)
            }
        }
        .sheet(item: $editingMyValue) { value in
            MyValueEditor(value: value) { savedValue in
                saveMyValue(savedValue)
            }
        }
        .confirmationDialog("Delete Value?", isPresented: Binding(
            get: { deleteCandidate != nil },
            set: { if !$0 { deleteCandidate = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let deleteCandidate {
                    deleteValue(deleteCandidate)
                }
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                deleteCandidate = nil
            }
        } message: {
            Text("This removes the Value statement. Linked Goals remain, but lose this Value link.")
        }
    }

    private var myValuesSection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Spacer()
                Button {
                    showAddMyValueEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(GoalTrackerDimIconButtonStyle())
                .keyboardShortcut("n", modifiers: [.command])
                .help("Add My Values")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            if myValues.isEmpty {
                VStack(spacing: 0) {
                    Text("No personal values yet.")
                        .font(.custom("Helvetica Neue", size: 18).weight(.bold))
                        .foregroundStyle(GoalTrackerTheme.devotionalRed)
                        .padding(TableMetrics.textInset)
                        .frame(maxWidth: .infinity, minHeight: TableMetrics.rowHeight, alignment: .center)
                        .background(GoalTrackerTheme.lightYellow)
                }
                .valuesTableContainer(width: ValuesColumns.tableWidth)
            } else {
                VStack(spacing: 0) {
                    ForEach(myValues) { value in
                        MyValueTableCell(
                            value: value,
                            edit: {
                                editingMyValue = value
                            },
                            delete: {
                                deleteMyValue(value)
                            }
                        )
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                        }
                    }
                }
                .valuesTableContainer(width: ValuesColumns.tableWidth)
            }
        }
        .frame(width: ValuesColumns.tableWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 10)
        .padding(.bottom, 24)
    }

    private var coreValuesSection: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Text("Core Values")
                    .font(.custom("Helvetica Neue", size: 16).weight(.bold))
                    .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    showAddValueEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(GoalTrackerDimIconButtonStyle())
                .help("Add Core Value")
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if filteredValues.isEmpty {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "No Core Values yet.",
                    message: "Add your first Core Value to create the foundation for Goals."
                )
                .frame(minHeight: 220)
            } else {
                CoreValuesTable(
                    values: filteredValues,
                    edit: { value in
                        editingValue = value
                    },
                    delete: { value in
                        requestDelete(value)
                    }
                )
                .id(valuesRefreshID)
            }
        }
        .frame(width: ValuesColumns.tableWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func requestDelete(_ value: CoreValue) {
        if confirmBeforeDelete {
            deleteCandidate = value
        } else {
            deleteValue(value)
        }
    }

    private func deleteValue(_ value: CoreValue) {
        RelationshipRefreshService.touchValueCascade(value)
        managedObjectContext.delete(value)
        try? managedObjectContext.save()
        refreshValueRows()
    }

    private func saveMyValue(_ value: MyValue) {
        var values = myValues
        if let index = values.firstIndex(where: { $0.id == value.id }) {
            values[index] = value
        } else {
            values.append(value)
        }
        myValuesRaw = MyValueStore.encode(values)
        refreshValueRows()
    }

    private func deleteMyValue(_ value: MyValue) {
        myValuesRaw = MyValueStore.encode(myValues.filter { $0.id != value.id })
        refreshValueRows()
    }

    private func refreshValueRows() {
        managedObjectContext.processPendingChanges()
        valuesRefreshID &+= 1
    }
}

private struct MyValueTableCell: View {
    let value: MyValue
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        ZStack(alignment: .trailing) {
            Text(value.text)
                .font(.custom("Helvetica Neue", size: 18).weight(.bold))
                .foregroundStyle(GoalTrackerTheme.devotionalRed)
                .lineLimit(nil)
                .lineSpacing(TableMetrics.lineSpacing)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 72)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 6) {
                ValueDimIconButton(title: "Edit", systemImage: "pencil", action: edit)
                ValueDimIconButton(title: "Delete", systemImage: "trash", action: delete)
            }
        }
        .padding(TableMetrics.textInset)
        .frame(maxWidth: .infinity, minHeight: TableMetrics.rowHeight, alignment: .center)
        .background(GoalTrackerTheme.lightYellow)
    }
}

private struct CoreValuesTable: View {
    let values: [CoreValue]
    let edit: (CoreValue) -> Void
    let delete: (CoreValue) -> Void

    var body: some View {
        FixedFeatureTable(fixedColumnWidth: ValuesColumns.coreValue, contentHeight: tableContentHeight) {
            HeaderCell(text: "Core Values", width: ValuesColumns.coreValue)
        } fixedRows: {
            ForEach(values) { value in
                let rowHeight = rowHeight(for: value)
                CoreValueNameCell(value: value, width: ValuesColumns.coreValue, edit: { edit(value) }, delete: { delete(value) })
                .environment(\.goalTrackerTableRowHeight, rowHeight)
                .background(Color.white)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                }
            }
        } scrollHeader: {
            HStack(spacing: 0) {
                HeaderCell(text: "Description", width: ValuesColumns.description)
                HeaderCell(text: "Linked Goals", width: ValuesColumns.linkedGoals)
                HeaderCell(text: "Linked Tasks", width: ValuesColumns.linkedTasks)
            }
        } scrollRows: {
            ForEach(values) { value in
                let rowHeight = rowHeight(for: value)
                HStack(spacing: 0) {
                    DataCell(text: value.valueDescription, width: ValuesColumns.description)
                    NumberCell(text: "\(value.linkedGoalsCount)", width: ValuesColumns.linkedGoals)
                    NumberCell(text: "\(value.linkedTasksCount)", width: ValuesColumns.linkedTasks)
                }
                .environment(\.goalTrackerTableRowHeight, rowHeight)
                .background(Color.white)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(GoalTrackerTheme.tableBorder).frame(height: 1)
                }
            }
        }
        .frame(width: ValuesColumns.tableWidth, height: min(tableContentHeight, 520))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func rowHeight(for value: CoreValue) -> CGFloat {
        TableMetrics.rowHeight(for: [
            (value.name, ValuesColumns.coreValue),
            (value.valueDescription, ValuesColumns.description),
            ("\(value.linkedGoalsCount)", ValuesColumns.linkedGoals),
            ("\(value.linkedTasksCount)", ValuesColumns.linkedTasks)
        ])
    }

    private var tableContentHeight: CGFloat {
        TableMetrics.headerHeight + values.reduce(CGFloat(0)) { total, value in
            total + rowHeight(for: value)
        }
    }
}

private struct CoreValueNameCell: View {
    @Environment(\.goalTrackerTableRowHeight) private var rowHeight

    let value: CoreValue
    let width: CGFloat
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(value.name)
                .font(.custom("Helvetica Neue", size: TableMetrics.fontSize).weight(.bold))
                .foregroundStyle(Color.black)
                .lineLimit(nil)
                .lineSpacing(TableMetrics.lineSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                ValueDimIconButton(title: "Edit", systemImage: "pencil", action: edit)
                ValueDimIconButton(title: "Delete", systemImage: "trash", action: delete)
            }
        }
        .padding(TableMetrics.textInset)
        .frame(minWidth: width, idealWidth: width, maxWidth: width, minHeight: rowHeight, maxHeight: rowHeight, alignment: .center)
        .background(Color.clear)
    }
}

private struct ValueDimIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
        }
        .buttonStyle(GoalTrackerDimIconButtonStyle())
        .opacity(0.42)
        .help(title)
    }
}

private enum ValuesColumns {
    static let coreValue = TableMetrics.columnWidth("Core Values", min: 260)
    static let description = TableMetrics.columnWidth("Description", min: 520)
    static let linkedGoals = TableMetrics.columnWidth("Linked Goals", min: 140)
    static let linkedTasks = TableMetrics.columnWidth("Linked Tasks", min: 140)
    static let tableWidth = coreValue + description + linkedGoals + linkedTasks
}

private extension View {
    func valuesTableContainer(width: CGFloat) -> some View {
        frame(width: width, alignment: .topLeading)
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(GoalTrackerTheme.tableBorder, lineWidth: 1.2))
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct MyValueEditor: View {
    @Environment(\.dismiss) private var dismiss

    let value: MyValue?
    let save: (MyValue) -> Void
    @State private var text: String
    @State private var error: String?

    init(value: MyValue?, save: @escaping (MyValue) -> Void) {
        self.value = value
        self.save = save
        _text = State(initialValue: value?.text ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(value == nil ? "Add My Values" : "Edit My Values")
                .font(.title2.weight(.bold))

            TextEditor(text: $text)
                .frame(height: 120)
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            FormErrorText(message: error)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") { saveValue() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }

    private func saveValue() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "My Values text is required."
            return
        }

        save(MyValue(id: value?.id ?? UUID(), text: trimmed))
        dismiss()
    }
}

private struct ValueEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var managedObjectContext

    let value: CoreValue?
    let onSave: () -> Void
    @State private var name: String
    @State private var valueDescription: String
    @State private var error: String?

    init(value: CoreValue?, onSave: @escaping () -> Void = {}) {
        self.value = value
        self.onSave = onSave
        _name = State(initialValue: value?.name ?? "")
        _valueDescription = State(initialValue: value?.valueDescription ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(value == nil ? "Add Value" : "Edit Value")
                .font(.title2.weight(.bold))

            TextField("Name / Value Statement", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                    .foregroundStyle(.secondary)
                TextEditor(text: $valueDescription)
                    .frame(height: 130)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        .frame(width: 520)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Value Statement is required."
            return
        }

        let now = Date()
        if let value {
            value.name = trimmed
            value.valueDescription = valueDescription
            RelationshipRefreshService.touchValueCascade(value, now: now)
        } else {
            _ = CoreValue(context: managedObjectContext, name: trimmed, valueDescription: valueDescription)
        }

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
