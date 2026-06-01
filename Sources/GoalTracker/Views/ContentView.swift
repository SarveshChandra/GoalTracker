import CoreData
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("GoalTracker.selectedSection") private var selectedSectionRaw = NavigationSection.dashboard.rawValue
    @AppStorage("GoalTracker.globalGoalFilter") private var selectedGoalIDRaw = ""
    @AppStorage("GoalTracker.globalMilestoneFilter") private var selectedMilestoneIDRaw = ""
    @AppStorage("GoalTracker.globalTaskFilter") private var selectedTaskIDRaw = ""
    @AppStorage("GoalTracker.themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("GoalTracker.autoICloudBackupsEnabled") private var autoICloudBackupsEnabled = true
    @AppStorage("GoalTracker.lastAutomaticBackupAt") private var lastAutomaticBackupAt = 0.0
    @AppStorage("GoalTracker.lastBackupPath") private var lastBackupPath = ""
    @AppStorage("GoalTracker.lastBackupError") private var lastBackupError = ""
    @AppStorage("GoalTracker.defaultDashboardStartScreen") private var defaultDashboardStartScreen = true

    private var selectedSection: Binding<NavigationSection> {
        Binding(
            get: { NavigationSection(rawValue: selectedSectionRaw) ?? .dashboard },
            set: { selectedSectionRaw = $0.rawValue }
        )
    }

    private var globalFilters: GoalTrackerGlobalFilters {
        GoalTrackerGlobalFilters(
            goalID: UUID(uuidString: selectedGoalIDRaw),
            milestoneID: UUID(uuidString: selectedMilestoneIDRaw),
            taskID: UUID(uuidString: selectedTaskIDRaw)
        )
    }

    private var selectionActions: GoalTrackerSelectionActions {
        GoalTrackerSelectionActions(
            selectGoal: { goal in
                selectedGoalIDRaw = goal.id.uuidString
                selectedMilestoneIDRaw = ""
                selectedTaskIDRaw = ""
            },
            selectMilestone: { milestone in
                selectedGoalIDRaw = milestone.goal?.id.uuidString ?? ""
                selectedMilestoneIDRaw = milestone.id.uuidString
                selectedTaskIDRaw = ""
            },
            selectTask: { task in
                selectedGoalIDRaw = task.milestone?.goal?.id.uuidString ?? ""
                selectedMilestoneIDRaw = task.milestone?.id.uuidString ?? ""
                selectedTaskIDRaw = task.id.uuidString
            },
            clearGoal: {
                selectedGoalIDRaw = ""
                selectedMilestoneIDRaw = ""
                selectedTaskIDRaw = ""
            },
            clearMilestone: {
                selectedMilestoneIDRaw = ""
                selectedTaskIDRaw = ""
            },
            clearTask: {
                selectedTaskIDRaw = ""
            }
        )
    }

    private var shouldShowGlobalFilters: Bool {
        switch selectedSection.wrappedValue {
        case .goals, .milestones, .tasks, .sessions:
            true
        case .dashboard, .values, .dailyStreak, .settings:
            false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopTabsView(selection: selectedSection)

            if shouldShowGlobalFilters {
                GlobalFiltersBar(
                    selectedGoalIDRaw: $selectedGoalIDRaw,
                    selectedMilestoneIDRaw: $selectedMilestoneIDRaw,
                    selectedTaskIDRaw: $selectedTaskIDRaw
                )
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 20)
            }

            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(GoalTrackerHoverButtonStyle())
        .tint(GoalTrackerTheme.appYellow)
        .accentColor(GoalTrackerTheme.appYellow)
        .onAppear {
            DemoDataService.seedIfEmpty(in: managedObjectContext)
            if defaultDashboardStartScreen {
                selectedSectionRaw = NavigationSection.dashboard.rawValue
            }
            runAutomaticBackupIfNeeded(minimumInterval: 21_600)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                runAutomaticBackupIfNeeded(minimumInterval: 21_600)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection.wrappedValue {
        case .dashboard:
            DashboardView(filters: globalFilters)
        case .values:
            ValuesView()
        case .goals:
            GoalsView(filters: globalFilters, selectionActions: selectionActions)
        case .milestones:
            MilestonesView(filters: globalFilters, selectionActions: selectionActions)
        case .tasks:
            TasksView(filters: globalFilters, selectionActions: selectionActions)
        case .sessions:
            SessionsView(filters: globalFilters, selectionActions: selectionActions)
        case .dailyStreak:
            DailyStreakView()
        case .settings:
            SettingsView()
        }
    }

    private func runAutomaticBackupIfNeeded(minimumInterval: TimeInterval = 86_400) {
        guard autoICloudBackupsEnabled else { return }

        let lastBackupDate = lastAutomaticBackupAt > 0 ? Date(timeIntervalSince1970: lastAutomaticBackupAt) : nil
        do {
            if let result = try BackupService.createAutomaticBackupIfNeeded(
                from: managedObjectContext,
                lastBackupDate: lastBackupDate,
                minimumInterval: minimumInterval
            ) {
                lastAutomaticBackupAt = result.createdAt.timeIntervalSince1970
                lastBackupPath = ([result.url] + result.mirroredURLs).map(\.path).joined(separator: "\n")
                lastBackupError = ""
            }
        } catch {
            lastBackupError = error.localizedDescription
        }
    }
}
