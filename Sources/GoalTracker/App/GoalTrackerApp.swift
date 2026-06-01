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

    private var theme: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    init() {
        let launchMode = GoalTrackerLaunchMode(arguments: CommandLine.arguments)
        self.launchMode = launchMode
        self.persistenceController = launchMode.usesInMemoryStore ? PersistenceController(inMemory: true) : PersistenceController.shared

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
            ContentView(
                initialSectionOverride: launchMode.initialSection,
                allowsAutomaticBackupsOverride: launchMode.allowsAutomaticBackups
            )
                .font(.custom("Helvetica Neue", size: 13))
                .goalTrackerAppTheme(theme)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1480, height: 900)

        Settings {
            SettingsView()
                .font(.custom("Helvetica Neue", size: 13))
                .goalTrackerAppTheme(theme)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
