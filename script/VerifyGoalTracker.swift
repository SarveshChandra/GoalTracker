import CoreData
import Foundation

@main
struct VerifyGoalTracker {
    @MainActor
    static func main() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        DemoDataService.seedIfEmpty(in: context)
        verify(controller.container.managedObjectModel.entitiesByName["AppSettings"] == nil, "UI settings should not be part of the Core Data model.")
        verify(NavigationSection.values.navigationTitle == "Values Sheet", "Values tab should be renamed to Values Sheet.")
        let values = try context.fetchAll(CoreValue.self)
        let goals = try context.fetchAll(Goal.self)
        let milestones = try context.fetchAll(Milestone.self)
        let tasks = try context.fetchAll(TaskItem.self)
        let sessions = try context.fetchAll(WorkSession.self)

        if DataMigrationService.backfillSessionLabels(in: context) {
            try context.save()
        }

        if DataMigrationService.backfillSessionEstimatedMinutes(in: context) {
            try context.save()
        }

        if ValidationService.clampMilestonesToGoalDateRanges(goals) {
            try context.save()
        }

        verify(values.count == 12, "Expected 12 core values.")
        verify(goals.count >= 15, "Expected large populated Dharmic goals.")
        verify(milestones.count >= 26, "Expected large populated milestones.")
        verify(tasks.count > 100, "Expected more than 100 populated tasks.")
        verify(sessions.count >= 100, "Expected broadly populated sessions.")
        verify(sessions.allSatisfy { !$0.sessionLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }, "Demo Sessions should have user-entered Session labels.")
        verify(sessions.contains { $0.estimatedMinutesValue > 0 }, "Sessions should own Estimated Minutes.")
        verify(Set(goals.map(\.status)).isSuperset(of: [.notPlanned, .notStarted, .completed, .inProgress, .overdue]), "Demo Goals should include all major computed statuses.")
        verify(Set(milestones.map(\.status)).isSuperset(of: [.notStarted, .completed, .inProgress, .overdue]), "Demo Milestones should include all computed statuses.")
        verify(Set(tasks.map(\.baseComputedStatus)).isSuperset(of: [.notStarted, .partiallyCompleted, .completed]), "Demo Tasks should include not started, partial, and completed states.")
        verify(Set(sessions.map(\.status)).isSuperset(of: [.notStarted, .partial, .completed]), "Demo Sessions should include all session statuses.")

        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentYearDate = calendar.date(from: DateComponents(year: currentYear, month: 6, day: 1)) ?? Date()
        let priorYearDate = calendar.date(from: DateComponents(year: currentYear - 1, month: 6, day: 1)) ?? Date()
        verify(!DateUtils.displayDate(currentYearDate).contains("\(currentYear)"), "Current-year dates should hide the year.")
        verify(DateUtils.displayDate(priorYearDate).contains("\(currentYear - 1)"), "Non-current-year dates should show the year.")

        let futureDueDate = calendar.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        let pastDueDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        verify(StatusCalculator.goalStatus(progress: 0, startDate: Date(), dueDate: futureDueDate, isPlanned: false) == .notPlanned, "Unplanned Goals should compute as Not Planned.")
        verify(StatusCalculator.goalStatus(progress: 0, startDate: Date(), dueDate: futureDueDate, isPlanned: true) == .notStarted, "Planned zero-progress Goals should compute as Not Started.")
        verify(StatusCalculator.goalStatus(progress: 50, startDate: Date(), dueDate: futureDueDate, isPlanned: true) == .inProgress, "Started planned Goals should compute as In Progress.")
        verify(StatusCalculator.goalStatus(progress: 50, startDate: Date(), dueDate: pastDueDate, isPlanned: true) == .overdue, "Incomplete planned Goals past Due Date should compute as Overdue.")
        verify(StatusCalculator.goalStatus(progress: 100, startDate: Date(), dueDate: pastDueDate, isPlanned: true) == .completed, "Complete planned Goals should compute as Completed.")
        let oldSessionDate = calendar.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let automaticSessionDate = SessionDatePolicy.resolvedDateForSave(
            previousStatus: .notStarted,
            newStatus: .completed,
            proposedDate: oldSessionDate,
            dateWasManuallyEdited: false
        )
        verify((automaticSessionDate ?? oldSessionDate) > oldSessionDate, "Session Date should refresh automatically when Session status changes to Completed.")
        let manualSessionDate = SessionDatePolicy.resolvedDateForSave(
            previousStatus: .partial,
            newStatus: .completed,
            proposedDate: oldSessionDate,
            dateWasManuallyEdited: true
        )
        verify(manualSessionDate == oldSessionDate, "A manually edited Session Date should be preserved on save.")

        let goalPriorities = GoalPriorityService.priorities(for: goals)
        let goalPrioritySet = Set(goalPriorities.values)
        verify(goalPrioritySet.isSubset(of: Set(ComputedPriority.allCases)), "Every Goal should use a computed priority value.")
        verify(goalPrioritySet.contains(.highest), "Expected computed priorities to include Highest priority goals.")
        verify(goalPrioritySet.contains(.medium), "Expected computed priorities to include Medium priority goals.")
        verify(goalPrioritySet.contains(.low), "Expected computed priorities to include Low priority goals.")
        verify(goalPrioritySet.contains(.none), "Expected computed priorities to include blank priority goals.")
        verify(goals.filter { $0.status == .overdue }.allSatisfy { goalPriorities[$0.id] == .highest }, "Overdue Goals should compute as Highest priority.")
        verify(goals.filter { $0.status == .completed || DateUtils.startOfDay($0.startDate) > DateUtils.startOfDay(Date()) }.allSatisfy { goalPriorities[$0.id] == ComputedPriority.none }, "Completed or future Goals should compute as blank priority.")
        verify(ComputedPriority.none.displayName.isEmpty, "No Priority should render as blank text.")
        verify(ComputedPriority.highest.displayName == "Highest", "Highest priority should display as Highest.")
        verify(PriorityTextStyle.usesBoldWeight("Highest"), "Highest priority should use bold text weight.")
        verify(PriorityTextStyle.usesBoldWeight("High"), "High priority should use bold text weight.")
        verify(!PriorityTextStyle.usesBoldWeight("Medium"), "Medium priority should use regular text weight.")
        verify(!PriorityTextStyle.usesBoldWeight("Low"), "Low priority should use regular text weight.")
        verify(PriorityTextStyle.opacity(for: "Low") < 1, "Low priority should be visually dimmed.")
        verify(TaskPriority.allCases.contains(.highest), "Standalone Task priority input should include Highest.")
        verify(ComputedPriority(taskPriority: .highest) == .highest, "Standalone Task Highest priority should display as Highest.")
        verify(SessionStatus.partial.displayName == "Partially Completed", "Partial Session status should display as Partially Completed.")
        verify(StatusTextStyle.usesBoldWeight(SessionStatus.partial.displayName), "Partially Completed Session status should use bold text weight.")

        let sortedGoals = goals.sorted { GoalTrackerSort.goals($0, $1, priorities: goalPriorities) }
        verify(zip(sortedGoals, sortedGoals.dropFirst()).allSatisfy {
            (goalPriorities[$0.id] ?? .none).sortRank <= (goalPriorities[$1.id] ?? .none).sortRank
        }, "Goals should sort by computed priority from Highest to blank.")
        let blankPriorityGoals = sortedGoals.filter { (goalPriorities[$0.id] ?? ComputedPriority.none) == ComputedPriority.none }
        verify(zip(blankPriorityGoals, blankPriorityGoals.dropFirst()).allSatisfy {
            if $0.status == .completed && $1.status != .completed { return false }
            if $0.status != .completed && $1.status == .completed { return true }
            return $0.computedProgress >= $1.computedProgress
        }, "Blank priority Goals should keep incomplete/not-started goals above completed goals, then sort by completion descending.")

        let intentionallyUnplannedGoalNames: Set<String> = ["Clarify next long-term seva direction"]
        for goal in goals where !goal.milestones.isEmpty {
            let expected = goal.milestones.reduce(0) { $0 + $1.computedProgress } / Double(goal.milestones.count)
            verify(abs(goal.computedProgress - expected) < 0.001, "Goal progress should average milestone progress for \(goal.name).")
            verify(!goal.hasOverlappingMilestones, "Milestones should not overlap inside Goal \(goal.name).")
            if intentionallyUnplannedGoalNames.contains(goal.name) {
                verify(!goal.hasMilestoneBoundaryCoverage, "Intentional Not Planned Goal should have a boundary mismatch: \(goal.name).")
                verify(!goal.isPlanned, "Intentional Not Planned Goal should remain unplanned: \(goal.name).")
                verify(goal.status == .notPlanned, "Intentional Not Planned Goal should compute as Not Planned: \(goal.name).")
            } else {
                verify(goal.hasMilestoneBoundaryCoverage, "Goal Start Date and Due Date should match its Milestone boundaries for \(goal.name).")
                verify(goal.isPlanned, "Demo Goal should be planned when boundaries match and Milestones do not overlap: \(goal.name).")
            }
        }

        for milestone in milestones where !milestone.tasks.isEmpty {
            let expected = milestone.tasks.reduce(0) { $0 + $1.sessionProgress } / Double(milestone.tasks.count)
            verify(abs(milestone.computedProgress - expected) < 0.001, "Milestone progress should average session-weighted task progress for \(milestone.name).")
        }

        for milestone in milestones {
            if let goal = milestone.goal {
                verify(DateUtils.startOfDay(milestone.startDate) >= DateUtils.startOfDay(goal.startDate), "Milestone Start Date should stay inside its Goal range for \(milestone.name).")
                verify(DateUtils.startOfDay(milestone.endDate) <= DateUtils.startOfDay(goal.endDate), "Milestone Due Date should stay inside its Goal range for \(milestone.name).")
            }
        }

        let overlapCheckGoal = sortedGoals.first { !$0.milestones.isEmpty }!
        let overlapCheckMilestone = overlapCheckGoal.milestones.sorted(by: GoalTrackerSort.milestones).first!
        let overlapValidation = ValidationService.validateMilestone(
            name: "Overlap Probe",
            goal: overlapCheckGoal,
            startDate: overlapCheckMilestone.startDate,
            dueDate: overlapCheckMilestone.endDate
        )
        verify(overlapValidation?.contains("overlaps") == true, "Milestone validation should reject date overlaps inside one Goal.")

        if let taskWithCompletedSessions = tasks.first(where: { !$0.sessions.isEmpty && $0.sessions.allSatisfy { $0.status == .completed } }) {
            verify(taskWithCompletedSessions.isCompleteForProgress, "A Task with only completed Sessions should count complete.")
            verify(SessionFocusService.firstIncompleteSession(for: taskWithCompletedSessions) == nil, "A Task with all Sessions completed should not have a selected incomplete Session.")
        }

        if let taskWithPartialSession = tasks.first(where: { $0.sessions.contains { $0.status == .partial } }) {
            verify(!taskWithPartialSession.isCompleteForProgress, "A Task with a Partial Session should not count complete.")
            verify(taskWithPartialSession.sessionProgress > 0 && taskWithPartialSession.sessionProgress < 100, "A Task with a Partial Session should have partial session-weighted progress.")
            let orderedSessions = SessionFocusService.orderedSessions(for: taskWithPartialSession)
            let selectedSession = SessionFocusService.firstIncompleteSession(for: taskWithPartialSession)
            verify(selectedSession?.status != .completed, "Selected Session should be incomplete.")
            if let selectedSession, let index = orderedSessions.firstIndex(where: { $0.id == selectedSession.id }) {
                verify(orderedSessions[..<index].allSatisfy { $0.status == .completed }, "Selected Session should be the first incomplete Session in working order.")
            } else {
                verify(false, "Expected a selected incomplete Session for a Task with partial work.")
            }
        }

        if let taskWithMixedSessions = tasks.first(where: {
            $0.sessions.contains { $0.status == .completed } &&
            $0.sessions.contains { $0.status != .completed }
        }) {
            verify(!taskWithMixedSessions.isCompleteForProgress, "A Task should complete only when all of its Sessions are Completed.")
            verify(taskWithMixedSessions.sessionProgress > 0 && taskWithMixedSessions.sessionProgress < 100, "Mixed Session statuses should produce partial Task progress.")
        }

        if let cascadeGoal = goals.first(where: { !$0.milestones.isEmpty }),
           let cascadeMilestone = cascadeGoal.milestones.first(where: { !$0.tasks.isEmpty }),
           let cascadeTask = cascadeMilestone.tasks.first(where: { !$0.sessions.isEmpty }),
           let cascadeSession = cascadeTask.sessions.first {
            let cascadeDate = Date(timeIntervalSince1970: 1_900_000_000)
            RelationshipRefreshService.touchGoalCascade(cascadeGoal, now: cascadeDate)
            verify(abs(cascadeMilestone.updatedAt.timeIntervalSince(cascadeDate)) < 0.001, "Goal edits should refresh dependent Milestones.")
            verify(abs(cascadeTask.updatedAt.timeIntervalSince(cascadeDate)) < 0.001, "Goal edits should refresh dependent Tasks.")
            verify(abs(cascadeSession.updatedAt.timeIntervalSince(cascadeDate)) < 0.001, "Goal edits should refresh dependent Sessions.")

            let sessionDate = Date(timeIntervalSince1970: 1_900_000_100)
            RelationshipRefreshService.touchSessionLineage(cascadeSession, now: sessionDate)
            verify(abs(cascadeTask.updatedAt.timeIntervalSince(sessionDate)) < 0.001, "Session edits should refresh the parent Task.")
            verify(abs(cascadeMilestone.updatedAt.timeIntervalSince(sessionDate)) < 0.001, "Session edits should refresh the parent Milestone.")
            verify(abs(cascadeGoal.updatedAt.timeIntervalSince(sessionDate)) < 0.001, "Session edits should refresh the parent Goal.")
        }

        let careerValue = values.first { $0.name == "Career Excellence" }
        verify(careerValue != nil, "Career Excellence value should exist.")
        verify(goals.contains { $0.coreValues.contains { $0.id == careerValue?.id } }, "Core value filter should have matching goals.")
        let goalOrder = Dictionary(uniqueKeysWithValues: sortedGoals.enumerated().map { ($0.element.id, $0.offset) })
        let sortedMilestones = milestones.sorted { GoalTrackerSort.milestones($0, $1, priorities: goalPriorities) }
        let milestonePriorityText: (Milestone) -> String = { milestone in
            guard milestone.status != .completed, let goal = milestone.goal else { return "" }
            return (goalPriorities[goal.id] ?? GoalPriorityService.standalonePriority(for: goal)).displayName
        }
        verify(sortedMilestones.filter { $0.status == .completed }.allSatisfy { milestonePriorityText($0).isEmpty }, "Completed Milestones should show blank priority.")
        verify(sortedMilestones.filter { $0.status != .completed && $0.goal != nil }.contains { !milestonePriorityText($0).isEmpty }, "Actionable linked Milestones should show linked Goal computed priority when available.")
        verify(zip(sortedMilestones, sortedMilestones.dropFirst()).allSatisfy { left, right in
            let leftGoalRank = left.goal.flatMap { goalOrder[$0.id] } ?? Int.max
            let rightGoalRank = right.goal.flatMap { goalOrder[$0.id] } ?? Int.max
            if leftGoalRank != rightGoalRank { return leftGoalRank <= rightGoalRank }
            return left.startDate <= right.startDate
        }, "Milestones should sort by Goals Sheet order, then milestone start date.")
        let sortedTasks = tasks.sorted { GoalTrackerSort.tasks($0, $1, goalPriorities: goalPriorities) }
        let standaloneTasks = tasks.filter { $0.isStandalone }
        verify(standaloneTasks.count >= 20, "Expected standalone tasks in demo data.")
        verify(standaloneTasks.filter { $0.baseComputedStatus == .completed }.allSatisfy {
            GoalPriorityService.displayPriority(for: $0, goalPriorities: goalPriorities) == .none
        }, "Completed standalone Tasks should display blank priority.")
        verify(zip(sortedTasks, sortedTasks.dropFirst()).allSatisfy { left, right in
            let leftPriorityRank = GoalPriorityService.displayPriority(for: left, goalPriorities: goalPriorities).sortRank
            let rightPriorityRank = GoalPriorityService.displayPriority(for: right, goalPriorities: goalPriorities).sortRank
            if leftPriorityRank != rightPriorityRank { return leftPriorityRank <= rightPriorityRank }
            if left.isStandalone != right.isStandalone { return left.isStandalone }
            if left.isStandalone && right.isStandalone {
                return left.createdAt >= right.createdAt
            }

            let leftGoalRank = left.milestone?.goal.flatMap { goalOrder[$0.id] } ?? Int.max
            let rightGoalRank = right.milestone?.goal.flatMap { goalOrder[$0.id] } ?? Int.max
            if leftGoalRank != rightGoalRank { return leftGoalRank <= rightGoalRank }

            let leftMilestoneStart = left.milestone?.startDate ?? .distantFuture
            let rightMilestoneStart = right.milestone?.startDate ?? .distantFuture
            return leftMilestoneStart <= rightMilestoneStart
        }, "Tasks should sort by priority, standalone before linked tasks in the same priority, Goals Sheet order, then Milestone start date.")
        verify(standaloneTasks.allSatisfy { $0.goalName.isEmpty && $0.milestoneName.isEmpty }, "Standalone tasks should show empty Goal and Milestone context.")
        verify(sessions.contains { $0.task?.isStandalone == true }, "Expected standalone task sessions.")
        verify(sessions.compactMap(\.task).allSatisfy {
            ComputedPriority.allCases.contains(GoalPriorityService.displayPriority(for: $0, goalPriorities: goalPriorities))
        }, "Session priority should resolve through the linked Task priority source.")
        verify(sessions.filter { $0.task?.isStandalone == true && $0.task?.baseComputedStatus == .completed }.allSatisfy {
            guard let task = $0.task else { return false }
            return GoalPriorityService.displayPriority(for: task, goalPriorities: goalPriorities) == .none
        }, "Sessions linked to completed standalone Tasks should show blank priority.")
        let taskOrder = Dictionary(uniqueKeysWithValues: sortedTasks.enumerated().map { ($0.element.id, $0.offset) })
        let sortedSessions = sessions.sorted { GoalTrackerSort.sessions($0, $1, goalPriorities: goalPriorities) }
        verify(zip(sortedSessions, sortedSessions.dropFirst()).allSatisfy { left, right in
            let leftTaskRank = left.task.flatMap { taskOrder[$0.id] } ?? Int.max
            let rightTaskRank = right.task.flatMap { taskOrder[$0.id] } ?? Int.max
            if leftTaskRank != rightTaskRank { return leftTaskRank <= rightTaskRank }
            return left.createdAt <= right.createdAt
        }, "Sessions should sort by Tasks Sheet order, then ascending Session creation inside the same Task.")

        let topGoal = sortedGoals.first!
        let topGoalFilter = GoalTrackerGlobalFilters(goalID: topGoal.id, milestoneID: nil, taskID: nil)
        verify(goals.filter(topGoalFilter.includes(goal:)).allSatisfy { $0.id == topGoal.id }, "Goal filter should narrow Goals.")
        verify(milestones.filter(topGoalFilter.includes(milestone:)).allSatisfy { $0.goal?.id == topGoal.id }, "Goal filter should narrow Milestones.")
        verify(tasks.filter(topGoalFilter.includes(task:)).allSatisfy { $0.milestone?.goal?.id == topGoal.id }, "Goal filter should narrow Tasks.")
        verify(sessions.filter(topGoalFilter.includes(session:)).allSatisfy { $0.task?.milestone?.goal?.id == topGoal.id }, "Goal filter should narrow Sessions.")
        if let otherGoal = sortedGoals.first(where: { $0.id != topGoal.id }) {
            verify(!topGoalFilter.isLockedOut(goal: topGoal), "Selected Goal row should remain enabled.")
            verify(topGoalFilter.isLockedOut(goal: otherGoal), "Non-selected Goal rows should lock when a Goal is selected.")
        }

        let selectedMilestone = sortedMilestones.first!
        let milestoneFilter = GoalTrackerGlobalFilters(goalID: nil, milestoneID: selectedMilestone.id, taskID: nil)
        verify(milestones.filter(milestoneFilter.includes(milestone:)).allSatisfy { $0.id == selectedMilestone.id }, "Milestone filter should narrow Milestones.")
        verify(tasks.filter(milestoneFilter.includes(task:)).allSatisfy { $0.milestone?.id == selectedMilestone.id }, "Milestone filter should narrow Tasks.")
        verify(sessions.filter(milestoneFilter.includes(session:)).allSatisfy { $0.task?.milestone?.id == selectedMilestone.id }, "Milestone filter should narrow Sessions.")
        if let otherMilestone = milestones.first(where: { $0.id != selectedMilestone.id }) {
            verify(!milestoneFilter.isLockedOut(milestone: selectedMilestone), "Selected Milestone row should remain enabled.")
            verify(milestoneFilter.isLockedOut(milestone: otherMilestone), "Non-selected Milestone rows should lock when a Milestone is selected.")
        }

        let selectedTask = tasks.sorted { GoalTrackerSort.tasks($0, $1, goalPriorities: goalPriorities) }.first!
        let taskFilter = GoalTrackerGlobalFilters(goalID: nil, milestoneID: nil, taskID: selectedTask.id)
        verify(tasks.filter(taskFilter.includes(task:)).allSatisfy { $0.id == selectedTask.id }, "Task filter should narrow Tasks.")
        verify(sessions.filter(taskFilter.includes(session:)).allSatisfy { $0.task?.id == selectedTask.id }, "Task filter should narrow Sessions.")
        if let otherTask = tasks.first(where: { $0.id != selectedTask.id }) {
            verify(!taskFilter.isLockedOut(task: selectedTask), "Selected Task row should remain enabled.")
            verify(taskFilter.isLockedOut(task: otherTask), "Non-selected Task rows should lock when a Task is selected.")
        }

        let backupFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTrackerVerifyBackups-\(UUID().uuidString)", isDirectory: true)
        let mirroredBackupFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTrackerVerifyBackupsMirror-\(UUID().uuidString)", isDirectory: true)
        let backup = try BackupService.writeBackup(
            from: context,
            to: [backupFolder, mirroredBackupFolder],
            kind: .manual
        )
        let backupRoots = try BackupService.backupRootFolders()
        verify(backupRoots.count == 2, "Backup service should expose two iCloud backup roots.")
        verify(backupRoots[0].path.contains("Goal Tracker/Backups"), "Primary iCloud backup root should use Goal Tracker/Backups.")
        verify(backupRoots[1].path.contains("Vault/Backups/Goal Tracker"), "Secondary iCloud backup root should use Vault/Backups/Goal Tracker.")
        verify(FileManager.default.fileExists(atPath: backup.url.path), "Primary manual JSON backup file should be written.")
        verify(FileManager.default.fileExists(atPath: backup.mirroredURLs[0].path), "Mirrored manual JSON backup file should be written.")
        verify(backup.url.lastPathComponent == backup.mirroredURLs[0].lastPathComponent, "Mirrored backups should use the same filename.")
        let backupData = try Data(contentsOf: backup.url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedBackup = try decoder.decode(GoalTrackerExport.self, from: backupData)
        let verifiedBackup = try ImportExportService.verifyJSONFile(at: backup.url)
        verify(verifiedBackup.schemaVersion == GoalTrackerExport.currentSchemaVersion, "JSON backup should include current schema version.")
        verify(!verifiedBackup.appVersion.isEmpty, "JSON backup should include app version.")
        verify(verifiedBackup.myValues.count == MyValueStore.currentValues().count, "JSON backup should include My Values.")
        verify(decodedBackup.values.count == values.count, "JSON backup should include values.")
        verify(decodedBackup.goals.count == goals.count, "JSON backup should include goals.")
        try? FileManager.default.removeItem(at: backupFolder)
        try? FileManager.default.removeItem(at: mirroredBackupFolder)

        let retentionFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTrackerRetentionVerify-\(UUID().uuidString)", isDirectory: true)
        let mirroredRetentionFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GoalTrackerRetentionVerifyMirror-\(UUID().uuidString)", isDirectory: true)
        let manualRetentionRuns = BackupService.manualBackupLimit + 3
        let automaticRetentionRuns = BackupService.automaticBackupLimit + 3

        for _ in 0..<manualRetentionRuns {
            _ = try BackupService.writeBackup(from: context, to: [retentionFolder, mirroredRetentionFolder], kind: .manual)
        }

        let manualFiles = try FileManager.default.contentsOfDirectory(
            at: retentionFolder,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("GoalTracker-Manual-") && $0.pathExtension == "json" }
        verify(manualFiles.count == BackupService.manualBackupLimit, "Manual backups should keep only the latest retained files.")

        for _ in 0..<automaticRetentionRuns {
            _ = try BackupService.writeBackup(from: context, to: [retentionFolder, mirroredRetentionFolder], kind: .automatic)
        }

        let automaticFiles = try FileManager.default.contentsOfDirectory(
            at: mirroredRetentionFolder,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.lastPathComponent.hasPrefix("GoalTracker-Auto-") && $0.pathExtension == "json" }
        verify(automaticFiles.count == BackupService.automaticBackupLimit, "Automatic backups should keep only the latest retained files.")
        try? FileManager.default.removeItem(at: retentionFolder)
        try? FileManager.default.removeItem(at: mirroredRetentionFolder)

        let health = try DataHealthService.run(in: context)
        verify(health.valuesCount == values.count, "Data Health should count values.")
        verify(health.goalsCount == goals.count, "Data Health should count goals.")
        verify(health.milestonesCount == milestones.count, "Data Health should count milestones.")
        verify(health.tasksCount == tasks.count, "Data Health should count tasks.")
        verify(health.sessionsCount == sessions.count, "Data Health should count sessions.")
        verify(health.isHealthy, "Demo data should pass Data Health checks: \(health.issues.joined(separator: "; "))")

        print("Goal Tracker verification passed: values=\(values.count), goals=\(goals.count), milestones=\(milestones.count), tasks=\(tasks.count), sessions=\(sessions.count).")
    }

    private static func verify(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fatalError(message)
        }
    }
}
