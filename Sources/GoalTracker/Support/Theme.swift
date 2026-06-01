import SwiftUI

enum GoalTrackerTheme {
    static let appYellow = Color(red: 1.00, green: 0.82, blue: 0.22)
    static let lightYellow = Color(red: 1.00, green: 0.98, blue: 0.78)
    static let devotionalRed = Color(red: 0.48, green: 0.05, blue: 0.04)
    static let moduleIconRed = Color.red
    static let creamWork = Color(red: 1.00, green: 0.98, blue: 0.91)
    static let active = Color(red: 1.00, green: 0.88, blue: 0.34)
    static let completed = Color(red: 0.77, green: 0.92, blue: 0.80)
    static let overdue = Color(red: 0.98, green: 0.75, blue: 0.75)
    static let neutral = Color(nsColor: .controlBackgroundColor)
    static let computedFill = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let headerFill = Color(red: 0.96, green: 0.96, blue: 0.94)
    static let cardFill = Color(nsColor: .windowBackgroundColor)
    static let primaryAccent = appYellow
    static let secondaryAccent = Color(red: 0.94, green: 0.66, blue: 0.12)
    static let rowCompleted = Color(red: 0.86, green: 0.96, blue: 0.88)
    static let rowOverdue = Color(red: 1.00, green: 0.86, blue: 0.86)
    static let rowNotStarted = Color.white
    static let rowNeutral = Color.white
    static let tableBorder = Color(nsColor: .separatorColor)

    static func background(for status: GoalStatus) -> Color {
        switch status {
        case .notPlanned, .notStarted: rowNeutral
        case .completed: completed
        case .overdue: overdue
        case .inProgress: active
        }
    }

    static func background(for status: MilestoneStatus) -> Color {
        switch status {
        case .completed: completed
        case .overdue: overdue
        case .inProgress: active
        case .notStarted: rowNeutral
        }
    }

    static func background(for status: TaskStatus) -> Color {
        switch status {
        case .completed: completed
        case .active: active
        case .partiallyCompleted: active
        case .notStarted: rowNeutral
        }
    }

    static func background(for status: SessionStatus) -> Color {
        switch status {
        case .completed: completed
        case .partial: active
        case .notStarted: rowNeutral
        }
    }

    static func tableRowBackground(for status: GoalStatus) -> Color {
        switch status {
        case .notPlanned, .notStarted: rowNotStarted
        case .completed: rowCompleted
        case .overdue: rowOverdue
        case .inProgress: creamWork
        }
    }

    static func tableRowBackground(for status: MilestoneStatus) -> Color {
        switch status {
        case .completed: rowCompleted
        case .overdue: rowOverdue
        case .inProgress: creamWork
        case .notStarted: rowNotStarted
        }
    }

    static func tableRowBackground(for status: TaskStatus) -> Color {
        switch status {
        case .completed: rowCompleted
        case .active: creamWork
        case .partiallyCompleted: creamWork
        case .notStarted: rowNotStarted
        }
    }

    static func tableRowBackground(for status: SessionStatus) -> Color {
        switch status {
        case .completed: rowCompleted
        case .partial: creamWork
        case .notStarted: rowNotStarted
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
    }
}

struct GoalTrackerHoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerHoverButton(configuration: configuration)
    }

    private struct GoalTrackerHoverButton: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.custom("Helvetica Neue", size: 13).weight(.semibold))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.48)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.28)
            }
            return GoalTrackerTheme.cardFill.opacity(0.72)
        }

        private var borderColor: Color {
            if configuration.isPressed || isHovering {
                return GoalTrackerTheme.secondaryAccent.opacity(0.50)
            }
            return Color.primary.opacity(0.12)
        }
    }
}

struct GoalTrackerIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerIconButton(configuration: configuration)
    }

    private struct GoalTrackerIconButton: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .foregroundStyle(Color.black)
                .frame(width: 28, height: 28)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.48)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.28)
            }
            return Color.clear
        }

        private var borderColor: Color {
            if configuration.isPressed || isHovering {
                return GoalTrackerTheme.secondaryAccent.opacity(0.45)
            }
            return Color.clear
        }
    }
}

struct GoalTrackerTabButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerTabButton(configuration: configuration, isSelected: isSelected)
    }

    private struct GoalTrackerTabButton: View {
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.custom("Helvetica Neue", size: 13).weight(.regular))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(backgroundColor)
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(borderColor, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .contentShape(Rectangle())
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.58)
            }
            if isSelected {
                return GoalTrackerTheme.appYellow.opacity(isHovering ? 0.92 : 0.82)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.24)
            }
            return Color.white
        }

        private var borderColor: Color {
            if isSelected || isHovering || configuration.isPressed {
                return GoalTrackerTheme.secondaryAccent.opacity(0.45)
            }
            return Color.primary.opacity(0.10)
        }
    }
}

struct GoalTrackerDimButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerDimButton(configuration: configuration)
    }

    private struct GoalTrackerDimButton: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.custom("Helvetica Neue", size: 13).weight(.semibold))
                .foregroundStyle(Color.black.opacity(isHovering || configuration.isPressed ? 0.84 : 0.28))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.38)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.32)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.18)
            }
            return Color.clear
        }

        private var borderColor: Color {
            if configuration.isPressed || isHovering {
                return GoalTrackerTheme.secondaryAccent.opacity(0.32)
            }
            return Color.primary.opacity(0.04)
        }
    }
}

struct GoalTrackerDimIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        GoalTrackerDimIconButton(configuration: configuration)
    }

    private struct GoalTrackerDimIconButton: View {
        let configuration: ButtonStyle.Configuration
        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(isHovering || configuration.isPressed ? 0.82 : 0.22))
                .frame(width: 24, height: 24)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.36)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundColor: Color {
            if configuration.isPressed {
                return GoalTrackerTheme.appYellow.opacity(0.30)
            }
            if isHovering {
                return GoalTrackerTheme.appYellow.opacity(0.16)
            }
            return Color.clear
        }

        private var borderColor: Color {
            if configuration.isPressed || isHovering {
                return GoalTrackerTheme.secondaryAccent.opacity(0.28)
            }
            return Color.primary.opacity(0.04)
        }
    }
}

struct GoalTrackerStandaloneToggleButtonStyle: ButtonStyle {
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.black.opacity(isOn ? 0.82 : 0.42))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return GoalTrackerTheme.appYellow.opacity(0.28)
        }
        return isOn ? GoalTrackerTheme.appYellow.opacity(0.18) : Color(nsColor: .textBackgroundColor).opacity(0.68)
    }

    private func borderColor(isPressed: Bool) -> Color {
        if isOn || isPressed {
            return GoalTrackerTheme.appYellow.opacity(0.72)
        }
        return Color.primary.opacity(0.10)
    }
}

struct GoalTrackerFindAvailableButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
        }
        .buttonStyle(GoalTrackerDimIconButtonStyle())
        .help("Find available row")
    }
}

struct GoalTrackerHoverSurfaceModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background(isHovering ? GoalTrackerTheme.appYellow.opacity(0.18) : GoalTrackerTheme.cardFill.opacity(0.82))
            .animation(.easeOut(duration: 0.12), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func goalCard() -> some View {
        modifier(CardModifier())
    }

    func goalTrackerHoverSurface() -> some View {
        modifier(GoalTrackerHoverSurfaceModifier())
    }

    func tableContainer() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(GoalTrackerTheme.tableBorder, lineWidth: 1.2))
    }
}
