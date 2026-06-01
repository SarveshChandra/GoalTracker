import AppKit
import Foundation
import CoreData

struct GoalTrackerExport: Codable {
    static let currentSchemaVersion = 6
    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var myValues: [MyValue]
    var values: [CoreValueDTO]
    var goals: [GoalDTO]
    var milestones: [MilestoneDTO]
    var tasks: [TaskDTO]
    var sessions: [SessionDTO]

    init(
        schemaVersion: Int = GoalTrackerExport.currentSchemaVersion,
        appVersion: String = GoalTrackerExport.currentAppVersion,
        exportedAt: Date,
        myValues: [MyValue],
        values: [CoreValueDTO],
        goals: [GoalDTO],
        milestones: [MilestoneDTO],
        tasks: [TaskDTO],
        sessions: [SessionDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.myValues = myValues
        self.values = values
        self.goals = goals
        self.milestones = milestones
        self.tasks = tasks
        self.sessions = sessions
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case appVersion
        case exportedAt
        case myValues
        case values
        case goals
        case milestones
        case tasks
        case sessions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        appVersion = try container.decodeIfPresent(String.self, forKey: .appVersion) ?? "Unversioned"
        exportedAt = try container.decode(Date.self, forKey: .exportedAt)
        myValues = try container.decodeIfPresent([MyValue].self, forKey: .myValues) ?? []
        values = try container.decode([CoreValueDTO].self, forKey: .values)
        goals = try container.decode([GoalDTO].self, forKey: .goals)
        milestones = try container.decode([MilestoneDTO].self, forKey: .milestones)
        tasks = try container.decode([TaskDTO].self, forKey: .tasks)
        sessions = try container.decode([SessionDTO].self, forKey: .sessions)
    }
}

enum ImportExportError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case jsonVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            "This backup uses schema version \(version), but this app supports up to version \(GoalTrackerExport.currentSchemaVersion)."
        case .jsonVerificationFailed(let reason):
            "JSON backup verification failed: \(reason)"
        }
    }
}

struct CoreValueDTO: Codable {
    var id: UUID
    var name: String
    var valueDescription: String
}

struct GoalDTO: Codable {
    var id: UUID
    var name: String
    var priority: GoalPriority
    var computedPriority: ComputedPriority?
    var startDate: Date
    var endDate: Date
    var progress: Double
    var antiGoal: String
    var sacrifice: String
    var coreValueIDs: [UUID]
}

struct MilestoneDTO: Codable {
    var id: UUID
    var name: String
    var goalID: UUID?
    var startDate: Date
    var endDate: Date
    var progress: Double
}

struct TaskDTO: Codable {
    var id: UUID
    var name: String
    var coreValueID: UUID?
    var milestoneID: UUID?
    var priority: TaskPriority
    var status: TaskStatus
    var taskType: TaskType
    var taskDescription: String
    var resultNotes: String
}

struct SessionDTO: Codable {
    var id: UUID
    var sessionLabel: String
    var taskID: UUID?
    var estimatedMinutes: Int
    var actualMinutes: Int
    var expectedResult: String
    var whatText: String
    var whenText: String
    var whyText: String
    var howText: String
    var howMuchText: String
    var status: SessionStatus
    var sessionDate: Date?
    var sessionNotes: String

    enum CodingKeys: String, CodingKey {
        case id
        case sessionLabel
        case taskID
        case estimatedMinutes
        case actualMinutes
        case expectedResult
        case whatText
        case whenText
        case whyText
        case howText
        case howMuchText
        case status
        case sessionDate
        case sessionNotes
    }

    init(
        id: UUID,
        sessionLabel: String,
        taskID: UUID?,
        estimatedMinutes: Int,
        actualMinutes: Int,
        expectedResult: String,
        whatText: String,
        whenText: String,
        whyText: String,
        howText: String,
        howMuchText: String,
        status: SessionStatus,
        sessionDate: Date?,
        sessionNotes: String
    ) {
        self.id = id
        self.sessionLabel = sessionLabel
        self.taskID = taskID
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = actualMinutes
        self.expectedResult = expectedResult
        self.whatText = whatText
        self.whenText = whenText
        self.whyText = whyText
        self.howText = howText
        self.howMuchText = howMuchText
        self.status = status
        self.sessionDate = sessionDate
        self.sessionNotes = sessionNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sessionLabel = try container.decodeIfPresent(String.self, forKey: .sessionLabel) ?? ""
        taskID = try container.decodeIfPresent(UUID.self, forKey: .taskID)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes) ?? 0
        actualMinutes = try container.decode(Int.self, forKey: .actualMinutes)
        expectedResult = try container.decode(String.self, forKey: .expectedResult)
        whatText = try container.decode(String.self, forKey: .whatText)
        whenText = try container.decode(String.self, forKey: .whenText)
        whyText = try container.decode(String.self, forKey: .whyText)
        howText = try container.decode(String.self, forKey: .howText)
        howMuchText = try container.decode(String.self, forKey: .howMuchText)
        status = try container.decode(SessionStatus.self, forKey: .status)
        sessionDate = try container.decodeIfPresent(Date.self, forKey: .sessionDate)
        sessionNotes = try container.decode(String.self, forKey: .sessionNotes)
    }
}

@MainActor
enum ImportExportService {
    static func exportJSON(from context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Goal Tracker JSON"
        panel.nameFieldStringValue = "GoalTrackerExport.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try writeJSONSnapshot(from: context, to: url, userDefaults: userDefaults)
        return url
    }

    static func importJSON(into context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> URL? {
        guard let url = try chooseJSONFile(title: "Import Goal Tracker JSON") else { return nil }
        try restoreJSON(from: url, into: context, userDefaults: userDefaults)
        return url
    }

    static func chooseJSONFile(title: String) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    static func writeJSONSnapshot(from context: NSManagedObjectContext, to url: URL, userDefaults: UserDefaults = .standard) throws {
        let snapshot = try snapshot(from: context, userDefaults: userDefaults)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        _ = try verifyJSONFile(at: url, expected: snapshot)
    }

    static func restoreJSON(from url: URL, into context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws {
        let snapshot = try verifyJSONFile(at: url)
        try replaceData(with: snapshot, in: context, userDefaults: userDefaults)
    }

    static func exportCSV(from context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder for Goal Tracker CSV Export"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let folder = panel.url else { return nil }
        let snapshot = try snapshot(from: context, userDefaults: userDefaults)
        try writeCSV(snapshot, to: folder)
        return folder
    }

    static func snapshot(from context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> GoalTrackerExport {
        let values = try context.fetchAll(CoreValue.self)
        let goals = try context.fetchAll(Goal.self)
        let milestones = try context.fetchAll(Milestone.self)
        let tasks = try context.fetchAll(TaskItem.self)
        let sessions = try context.fetchAll(WorkSession.self)
        let goalPriorities = GoalPriorityService.priorities(for: goals)

        return GoalTrackerExport(
            exportedAt: Date(),
            myValues: MyValueStore.currentValues(in: userDefaults),
            values: values.map {
                CoreValueDTO(id: $0.id, name: $0.name, valueDescription: $0.valueDescription)
            },
            goals: goals.map {
                GoalDTO(
                    id: $0.id,
                    name: $0.name,
                    priority: $0.priority,
                    computedPriority: goalPriorities[$0.id] ?? GoalPriorityService.standalonePriority(for: $0),
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    progress: $0.computedProgress,
                    antiGoal: $0.antiGoal,
                    sacrifice: $0.sacrifice,
                    coreValueIDs: $0.coreValues.map(\.id)
                )
            },
            milestones: milestones.map {
                MilestoneDTO(
                    id: $0.id,
                    name: $0.name,
                    goalID: $0.goal?.id,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    progress: $0.computedProgress
                )
            },
            tasks: tasks.map {
                TaskDTO(
                    id: $0.id,
                    name: $0.name,
                    coreValueID: $0.coreValue?.id,
                    milestoneID: $0.milestone?.id,
                    priority: $0.effectivePriority,
                    status: $0.baseComputedStatus,
                    taskType: $0.taskType,
                    taskDescription: $0.taskDescription,
                    resultNotes: $0.resultNotes
                )
            },
            sessions: sessions.map {
                SessionDTO(
                    id: $0.id,
                    sessionLabel: $0.sessionLabel,
                    taskID: $0.task?.id,
                    estimatedMinutes: $0.estimatedMinutesValue,
                    actualMinutes: $0.actualMinutesValue,
                    expectedResult: $0.expectedResult,
                    whatText: $0.whatText,
                    whenText: $0.whenText,
                    whyText: $0.whyText,
                    howText: $0.howText,
                    howMuchText: $0.howMuchText,
                    status: $0.status,
                    sessionDate: $0.sessionDate,
                    sessionNotes: $0.sessionNotes
                )
            }
        )
    }

    static func verifyJSONFile(at url: URL, expected: GoalTrackerExport? = nil) throws -> GoalTrackerExport {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(GoalTrackerExport.self, from: data)
        try validate(snapshot: snapshot, expected: expected)
        return snapshot
    }

    static func validate(snapshot: GoalTrackerExport, expected: GoalTrackerExport? = nil) throws {
        guard snapshot.schemaVersion <= GoalTrackerExport.currentSchemaVersion else {
            throw ImportExportError.unsupportedSchemaVersion(snapshot.schemaVersion)
        }

        guard snapshot.schemaVersion >= 0 else {
            throw ImportExportError.jsonVerificationFailed("Schema version is invalid.")
        }

        guard !snapshot.appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportExportError.jsonVerificationFailed("App version is missing.")
        }

        if let expected {
            let expectedCounts = entityCounts(for: expected)
            let decodedCounts = entityCounts(for: snapshot)
            guard expectedCounts == decodedCounts else {
                throw ImportExportError.jsonVerificationFailed("Decoded entity counts do not match the written snapshot.")
            }
        }
    }

    private static func entityCounts(for snapshot: GoalTrackerExport) -> [Int] {
        [
            snapshot.myValues.count,
            snapshot.values.count,
            snapshot.goals.count,
            snapshot.milestones.count,
            snapshot.tasks.count,
            snapshot.sessions.count
        ]
    }

    static func replaceData(with snapshot: GoalTrackerExport, in context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws {
        DemoDataService.clearAllData(in: context)
        MyValueStore.save(snapshot.myValues, in: userDefaults)

        var valueMap: [UUID: CoreValue] = [:]
        for dto in snapshot.values {
            let value = CoreValue(context: context, id: dto.id, name: dto.name, valueDescription: dto.valueDescription)
            valueMap[dto.id] = value
        }

        var goalMap: [UUID: Goal] = [:]
        for dto in snapshot.goals {
            let goal = Goal(
                context: context,
                id: dto.id,
                name: dto.name,
                priority: dto.priority,
                startDate: dto.startDate,
                endDate: dto.endDate,
                progress: dto.progress,
                antiGoal: dto.antiGoal,
                sacrifice: dto.sacrifice,
                coreValues: dto.coreValueIDs.compactMap { valueMap[$0] }
            )
            goalMap[dto.id] = goal
        }

        var milestoneMap: [UUID: Milestone] = [:]
        for dto in snapshot.milestones {
            let milestone = Milestone(
                context: context,
                id: dto.id,
                name: dto.name,
                goal: dto.goalID.flatMap { goalMap[$0] },
                startDate: dto.startDate,
                endDate: dto.endDate,
                progress: dto.progress
            )
            milestoneMap[dto.id] = milestone
        }

        var taskMap: [UUID: TaskItem] = [:]
        for dto in snapshot.tasks {
            let task = TaskItem(
                context: context,
                id: dto.id,
                name: dto.name,
                coreValue: dto.coreValueID.flatMap { valueMap[$0] },
                milestone: dto.milestoneID.flatMap { milestoneMap[$0] },
                priority: dto.priority,
                status: dto.status,
                taskType: dto.taskType,
                taskDescription: dto.taskDescription,
                resultNotes: dto.resultNotes
            )
            taskMap[dto.id] = task
        }

        for dto in snapshot.sessions {
            _ = WorkSession(
                context: context,
                id: dto.id,
                task: dto.taskID.flatMap { taskMap[$0] },
                sessionLabel: dto.sessionLabel,
                estimatedMinutes: dto.estimatedMinutes > 0 ? dto.estimatedMinutes : dto.taskID.flatMap { taskMap[$0] }?.estimatedMinutesValue ?? 0,
                actualMinutes: dto.actualMinutes,
                expectedResult: dto.expectedResult,
                whatText: dto.whatText,
                whenText: dto.whenText,
                whyText: dto.whyText,
                howText: dto.howText,
                howMuchText: dto.howMuchText,
                status: dto.status,
                sessionDate: dto.sessionDate,
                sessionNotes: dto.sessionNotes
            )
        }

        _ = TaskStatusService.refreshAllStoredStatuses(in: context)
        try context.save()
    }

    private static func writeCSV(_ snapshot: GoalTrackerExport, to folder: URL) throws {
        try write(
            rows: [["Value Statement", "Description", "Linked Goals Count", "Linked Tasks Count"]] + snapshot.values.map { value in
                let count = snapshot.goals.filter { $0.coreValueIDs.contains(value.id) }.count
                let goalIDs = Set(snapshot.goals.filter { $0.coreValueIDs.contains(value.id) }.map(\.id))
                let milestoneIDs = Set(snapshot.milestones.filter { milestone in
                    guard let goalID = milestone.goalID else { return false }
                    return goalIDs.contains(goalID)
                }.map(\.id))
                let linkedTasksCount = snapshot.tasks.filter { task in
                    task.coreValueID == value.id || task.milestoneID.map { milestoneIDs.contains($0) } == true
                }.count
                return [value.name, value.valueDescription, "\(count)", "\(linkedTasksCount)"]
            },
            named: "values.csv",
            to: folder
        )

        try write(
            rows: [["Goal", "Core Values", "Priority", "Start Date", "Due Date", "Progress %", "Anti-Goal", "Sacrifice"]] + snapshot.goals.map { goal in
                let valueNames = goal.coreValueIDs.compactMap { id in snapshot.values.first { $0.id == id }?.name }.joined(separator: "; ")
                return [goal.name, valueNames, (goal.computedPriority ?? .none).displayName, "\(goal.startDate)", "\(goal.endDate)", "\(goal.progress)", goal.antiGoal, goal.sacrifice]
            },
            named: "goals.csv",
            to: folder
        )

        try write(
            rows: [["Goal", "Milestone", "Start Date", "Due Date", "Progress %"]] + snapshot.milestones.map { milestone in
                let goalName = milestone.goalID.flatMap { id in snapshot.goals.first { $0.id == id }?.name } ?? ""
                return [goalName, milestone.name, "\(milestone.startDate)", "\(milestone.endDate)", "\(milestone.progress)"]
            },
            named: "milestones.csv",
            to: folder
        )

        try write(
            rows: [["Core Values", "Goal", "Milestone", "Task", "Priority", "Status", "Task Type", "Task Description", "Result Notes"]] + snapshot.tasks.map { task in
                let milestone = task.milestoneID.flatMap { id in snapshot.milestones.first { $0.id == id } }
                let goalName = milestone?.goalID.flatMap { id in snapshot.goals.first { $0.id == id }?.name } ?? ""
                let coreValueName = task.coreValueID.flatMap { id in snapshot.values.first { $0.id == id }?.name } ?? milestone?.goalID.flatMap { goalID in
                    snapshot.goals.first { $0.id == goalID }?.coreValueIDs.first.flatMap { valueID in
                        snapshot.values.first { $0.id == valueID }?.name
                    }
                } ?? ""
                return [coreValueName, goalName, milestone?.name ?? "", task.name, task.priority.rawValue, task.status.rawValue, task.taskType.rawValue, task.taskDescription, task.resultNotes]
            },
            named: "tasks.csv",
            to: folder
        )

        try write(
            rows: [["Session", "Core Values", "Goal", "Milestone", "Task", "Status", "Session Date", "Task Type", "Expected Result", "What", "When", "Why", "How", "How Much", "Estimated Minutes", "Actual Minutes", "Session Notes", "Linked Anti-Goal", "Linked Sacrifice"]] + snapshot.sessions.map { session in
                let task = session.taskID.flatMap { id in snapshot.tasks.first { $0.id == id } }
                let milestone = task?.milestoneID.flatMap { id in snapshot.milestones.first { $0.id == id } }
                let goal = milestone?.goalID.flatMap { id in snapshot.goals.first { $0.id == id } }
                let coreValueName = task?.coreValueID.flatMap { id in snapshot.values.first { $0.id == id }?.name } ?? goal?.coreValueIDs.first.flatMap { valueID in
                    snapshot.values.first { $0.id == valueID }?.name
                } ?? ""
                return [
                    session.sessionLabel,
                    coreValueName,
                    goal?.name ?? "",
                    milestone?.name ?? "",
                    task?.name ?? "",
                    session.status.displayName,
                    session.sessionDate.map { "\($0)" } ?? "",
                    task?.taskType.rawValue ?? "",
                    session.expectedResult,
                    session.whatText,
                    session.whenText,
                    session.whyText,
                    session.howText,
                    session.howMuchText,
                    "\(session.estimatedMinutes)",
                    "\(session.actualMinutes)",
                    session.sessionNotes,
                    goal?.antiGoal ?? "",
                    goal?.sacrifice ?? ""
                ]
            },
            named: "sessions.csv",
            to: folder
        )
    }

    private static func write(rows: [[String]], named fileName: String, to folder: URL) throws {
        let content = rows
            .map { row in row.map(Formatters.csvEscape).joined(separator: ",") }
            .joined(separator: "\n")
        try content.write(to: folder.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
    }
}
