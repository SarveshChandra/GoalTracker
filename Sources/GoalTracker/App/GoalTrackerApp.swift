import AppKit
import CoreData
import Darwin
import SwiftUI

private enum GoalTrackerLaunchMode: Equatable {
    case normal
    case previewGoals

    init(arguments: [String]) {
        if arguments.contains("--preview-goals") {
            self = .previewGoals
        } else {
            self = .normal
        }
    }

    var usesInMemoryStore: Bool {
        switch self {
        case .normal: false
        case .previewGoals: true
        }
    }

    var initialSection: NavigationSection? {
        switch self {
        case .normal: nil
        case .previewGoals: .goals
        }
    }

    var allowsAutomaticBackups: Bool {
        switch self {
        case .normal: true
        case .previewGoals: false
        }
    }

    var userDefaults: UserDefaults {
        switch self {
        case .normal:
            return .standard
        case .previewGoals:
            let suiteName = GoalTrackerAppIdentity.previewSuiteName
            let defaults = UserDefaults(suiteName: suiteName) ?? .standard
            defaults.removePersistentDomain(forName: suiteName)
            defaults.set(NavigationSection.goals.rawValue, forKey: "GoalTracker.selectedSection")
            defaults.set(false, forKey: "GoalTracker.autoICloudBackupsEnabled")
            return defaults
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.sendAction(#selector(NSApplication.newWindowForTab(_:)), to: nil, from: nil)
        }
        return true
    }
}

@main
struct GoalTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("GoalTracker.themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    private let launchMode: GoalTrackerLaunchMode
    private let persistenceController: PersistenceController
    private let userDefaults: UserDefaults

    private var theme: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    private var storeLoadError: Error? {
        persistenceController.loadError
    }

    init() {
        let launchMode = GoalTrackerLaunchMode(arguments: CommandLine.arguments)
        let userDefaults = launchMode.userDefaults
        if launchMode == .normal {
            GoalTrackerDefaultsMigrationService.migrateLegacyDefaultsIfNeeded(into: userDefaults)
        }

        self.launchMode = launchMode
        self.persistenceController = launchMode.usesInMemoryStore ? PersistenceController(inMemory: true) : PersistenceController.shared
        self.userDefaults = userDefaults
        _themePreferenceRaw = AppStorage(
            wrappedValue: ThemePreference.system.rawValue,
            "GoalTracker.themePreference",
            store: userDefaults
        )

        if CommandLine.arguments.contains("--reset-demo-data") {
            DemoDataService.installDemoData(in: persistenceController.container.viewContext, markInstalled: true)
            Darwin.exit(0)
        }

        if launchMode == .previewGoals {
            PreviewDataService.installReadmePreviewData(in: persistenceController.container.viewContext)
        }

        UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        Window("Goal Tracker", id: "main") {
            if let storeLoadError {
                StoreLoadFailureView(error: storeLoadError)
                    .font(.custom("Helvetica Neue", size: 13))
                    .goalTrackerAppTheme(theme)
            } else {
                ContentView(
                    initialSectionOverride: launchMode.initialSection,
                    allowsAutomaticBackupsOverride: launchMode.allowsAutomaticBackups,
                    userDefaults: userDefaults
                )
                    .defaultAppStorage(userDefaults)
                    .environment(\.goalTrackerUserDefaults, userDefaults)
                    .font(.custom("Helvetica Neue", size: 13))
                    .goalTrackerAppTheme(theme)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(
            width: storeLoadError == nil ? 1480 : 900,
            height: storeLoadError == nil ? 900 : 560
        )

        Settings {
            if let storeLoadError {
                StoreLoadFailureView(error: storeLoadError)
                    .font(.custom("Helvetica Neue", size: 13))
                    .goalTrackerAppTheme(theme)
            } else {
                SettingsView(allowsDataSafetyActions: launchMode.allowsAutomaticBackups, userDefaults: userDefaults)
                    .defaultAppStorage(userDefaults)
                    .environment(\.goalTrackerUserDefaults, userDefaults)
                    .font(.custom("Helvetica Neue", size: 13))
                    .goalTrackerAppTheme(theme)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
