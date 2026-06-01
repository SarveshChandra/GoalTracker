import AppKit
import CoreData
import Darwin
import SwiftUI

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
    private let persistenceController = PersistenceController.shared

    private var theme: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    init() {
        if CommandLine.arguments.contains("--reset-demo-data") {
            DemoDataService.installDemoData(in: persistenceController.container.viewContext, markInstalled: true)
            Darwin.exit(0)
        }

        UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    var body: some Scene {
        Window("Goal Tracker", id: "main") {
            ContentView()
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
