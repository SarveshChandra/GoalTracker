import AppKit
import SwiftUI

struct TopTabsView: View {
    @Binding var selection: NavigationSection

    private var centerSections: [NavigationSection] {
        NavigationSection.allCases.filter { $0 != .settings }
    }

    var body: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center) {
                appBrand
                    .frame(width: 172, alignment: .leading)

                Spacer(minLength: 0)

                settingsButton
                    .frame(width: 172, alignment: .trailing)
            }

            centerTabs
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 188)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(GoalTrackerTheme.headerFill)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(GoalTrackerTheme.tableBorder)
                .frame(height: 1)
        }
    }

    private var centerTabs: some View {
        HStack(spacing: 6) {
            ForEach(centerSections) { section in
                TopTabButton(
                    section: section,
                    isSelected: section == selection,
                    action: {
                        selection = section
                    }
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var settingsButton: some View {
        Button {
            selection = .settings
        } label: {
            Text("Settings")
        }
        .buttonStyle(GoalTrackerTabButtonStyle(isSelected: selection == .settings))
        .help("Settings")
    }

    private var appBrand: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text("Goal Tracker")
                .font(.custom("Helvetica Neue", size: 15).weight(.bold))
                .foregroundStyle(GoalTrackerTheme.devotionalRed)
                .lineLimit(1)
        }
        .fixedSize()
    }
}

private struct TopTabButton: View {
    let section: NavigationSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                sectionIcon

                Text(section.navigationTitle)
            }
        }
        .buttonStyle(GoalTrackerTabButtonStyle(isSelected: isSelected))
        .help(section.navigationTitle)
    }

    @ViewBuilder
    private var sectionIcon: some View {
        switch section {
        case .values:
            Text("ॐ")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GoalTrackerTheme.moduleIconRed)
        case .goals, .milestones, .tasks, .sessions:
            Image(systemName: section.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(GoalTrackerTheme.moduleIconRed)
        case .dashboard, .dailyStreak, .settings:
            EmptyView()
        }
    }
}
