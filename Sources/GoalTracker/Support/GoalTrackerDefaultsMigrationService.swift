import Foundation

enum GoalTrackerDefaultsMigrationService {
    private static let migrationMarkerPrefix = "GoalTracker.defaultsMigrated."

    static func migrateLegacyDefaultsIfNeeded(into userDefaults: UserDefaults) {
        let currentBundleIdentifier = GoalTrackerAppIdentity.currentBundleIdentifier
        guard !currentBundleIdentifier.isEmpty else { return }

        for legacyBundleIdentifier in GoalTrackerAppIdentity.legacyBundleIdentifiers where legacyBundleIdentifier != currentBundleIdentifier {
            let migrationMarkerKey = migrationMarkerPrefix + legacyBundleIdentifier
            if userDefaults.bool(forKey: migrationMarkerKey) {
                continue
            }

            guard let legacyDomain = userDefaults.persistentDomain(forName: legacyBundleIdentifier) else {
                continue
            }

            let appScopedEntries = legacyDomain.filter { $0.key.hasPrefix("GoalTracker.") }
            for (key, value) in appScopedEntries where userDefaults.object(forKey: key) == nil {
                userDefaults.set(value, forKey: key)
            }

            if !appScopedEntries.isEmpty {
                userDefaults.set(true, forKey: migrationMarkerKey)
            }
        }
    }
}
