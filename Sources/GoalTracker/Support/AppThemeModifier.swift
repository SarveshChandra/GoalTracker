import AppKit
import SwiftUI

struct AppThemeModifier: ViewModifier {
    let theme: ThemePreference

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(theme.colorScheme)
            .onAppear {
                theme.applyAppKitAppearance()
            }
            .onChange(of: theme) { _, newTheme in
                newTheme.applyAppKitAppearance()
            }
    }
}

extension View {
    func goalTrackerAppTheme(_ theme: ThemePreference) -> some View {
        modifier(AppThemeModifier(theme: theme))
    }
}

extension ThemePreference {
    private var appKitAppearance: NSAppearance? {
        switch self {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
    }

    func applyAppKitAppearance() {
        let appearance = appKitAppearance
        NSApp.appearance = appearance
        NSApp.windows.forEach { window in
            window.appearance = appearance
        }
    }
}
