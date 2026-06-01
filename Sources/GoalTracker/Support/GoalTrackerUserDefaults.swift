import SwiftUI

private struct GoalTrackerUserDefaultsKey: EnvironmentKey {
    static let defaultValue: UserDefaults = .standard
}

extension EnvironmentValues {
    var goalTrackerUserDefaults: UserDefaults {
        get { self[GoalTrackerUserDefaultsKey.self] }
        set { self[GoalTrackerUserDefaultsKey.self] = newValue }
    }
}
