import Foundation

enum GoalTrackerAppIdentity {
    static let fallbackBundleIdentifier = "com.goaltracker.app"
    static let legacyBundleIdentifiers = ["local.goaltracker.app"]

    static var currentBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? fallbackBundleIdentifier
    }

    static var previewSuiteName: String {
        "\(currentBundleIdentifier).preview"
    }
}
