import CoreData
import SwiftUI

struct DailyStreakView: View {
    @FetchRequest(sortDescriptors: []) private var sessions: FetchedResults<WorkSession>
    @State private var selectedMonth = Date()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ModuleHeader(
                title: "Daily Streak",
                subtitle: "A read-only monthly view of focused work. Each day reflects Sessions marked Partial or Completed."
            ) {
                HStack(spacing: 8) {
                    Button {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .help("Previous month")

                    Text(DateUtils.monthFormatter.string(from: selectedMonth))
                        .font(.headline)
                        .frame(width: 160)

                    Button {
                        selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .help("Next month")

                    Button("Today") {
                        selectedMonth = Date()
                    }
                }
            }

            VStack(spacing: 10) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(DateUtils.datesForMonth(containing: selectedMonth), id: \.self) { day in
                        DayCell(
                            day: day,
                            selectedMonth: selectedMonth,
                            sessions: sessionsFor(day)
                        )
                    }
                }
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.08)))

            Spacer()
        }
        .padding(24)
    }

    private func sessionsFor(_ day: Date) -> [WorkSession] {
        sessions.filter { DateUtils.isDate($0.sessionDate, inSameDayAs: day) }
            .sorted { $0.status.displayName < $1.status.displayName }
    }
}

private struct DayCell: View {
    let day: Date
    let selectedMonth: Date
    let sessions: [WorkSession]

    private var isInMonth: Bool {
        Calendar.current.isDate(day, equalTo: selectedMonth, toGranularity: .month)
    }

    private var dayNumber: Int {
        Calendar.current.component(.day, from: day)
    }

    private var summary: String {
        let completed = sessions.filter { $0.status == .completed }.count
        let partial = sessions.filter { $0.status == .partial }.count
        let minutes = sessions.reduce(0) { $0 + $1.actualMinutesValue }
        let goals = Set(sessions.map(\.goalName).filter { !$0.isEmpty }).sorted().joined(separator: ", ")
        return "Sessions: \(sessions.count)\nCompleted: \(completed)\nPartial: \(partial)\nActual minutes: \(minutes)\nGoals: \(goals.isEmpty ? "None" : goals)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(dayNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isInMonth ? .primary : .tertiary)
                Spacer()
                if Calendar.current.isDateInToday(day) {
                    Circle()
                        .fill(GoalTrackerTheme.primaryAccent)
                        .frame(width: 6, height: 6)
                }
            }

            HStack(spacing: 5) {
                let visible = sessions.prefix(5)
                if visible.isEmpty {
                    SessionStatusCircle(status: .notStarted, size: 17)
                        .opacity(isInMonth ? 0.55 : 0.25)
                } else {
                    ForEach(Array(visible.enumerated()), id: \.offset) { _, session in
                        SessionStatusCircle(status: session.status, size: 17)
                    }
                    if sessions.count > 5 {
                        Text("+\(sessions.count - 5)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .frame(height: 92)
        .frame(maxWidth: .infinity)
        .background(dayBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .opacity(isInMonth ? 1 : 0.45)
        .help(summary)
    }

    private var dayBackground: Color {
        if sessions.contains(where: { $0.status == .completed }) {
            return GoalTrackerTheme.completed.opacity(0.52)
        }
        if sessions.contains(where: { $0.status == .partial }) {
            return GoalTrackerTheme.creamWork
        }
        return GoalTrackerTheme.neutral.opacity(0.38)
    }
}
