import SwiftUI

struct SessionStudyGrid: View {
    let session: WorkSession

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                SessionStudyField(title: "Session", value: session.displayLabel, style: .compact)
                    .frame(maxWidth: .infinity)
                SessionStudyField(title: "Estimated Minutes", value: Formatters.minutes(session.estimatedMinutesValue), style: .compact)
                    .frame(width: 160)
                SessionStudyField(title: "Actual Minutes", value: Formatters.minutes(session.actualMinutesValue), style: .compact)
                    .frame(width: 150)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), alignment: .leading, spacing: 8) {
                SessionStudyField(title: "Expected Result", value: session.expectedResult, style: .multiline)
                SessionStudyField(title: "What", value: session.whatText, style: .multiline)
                SessionStudyField(title: "When", value: session.whenText, style: .multiline)
                SessionStudyField(title: "Why", value: session.whyText, style: .multiline)
                SessionStudyField(title: "How", value: session.howText, style: .multiline)
                SessionStudyField(title: "How Much", value: session.howMuchText, style: .multiline)
                SessionStudyField(title: "Session Notes", value: session.sessionNotes, style: .multiline)
            }
        }
    }
}

struct SelectedTaskSessionStudySection: View {
    let task: TaskItem
    let sessions: [WorkSession]
    let addSession: () -> Void
    let editSession: (WorkSession) -> Void

    private var taskStatus: TaskStatus {
        task.computedStatus(selectedTaskID: task.id)
    }

    private var selectedSession: WorkSession? {
        SessionFocusService.firstIncompleteSession(in: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.name)
                        .font(.custom("Helvetica Neue", size: 22).weight(.bold))
                        .foregroundStyle(.primary)
                    Text(task.contextSummary.isEmpty ? "Standalone Task" : task.contextSummary)
                        .font(.custom("Helvetica Neue", size: 14))
                        .foregroundStyle(Color.black.opacity(0.56))
                }
                Spacer()
                Button(action: addSession) {
                    Label("Add Session", systemImage: "plus")
                }
                .buttonStyle(GoalTrackerDimButtonStyle())
            }

            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], alignment: .leading, spacing: 8) {
                    SessionStudyField(title: "Task Type", value: task.taskType.rawValue, style: .compact)
                    SessionStudyField(title: "Task Status", value: taskStatus.rawValue, style: .compact)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), alignment: .leading, spacing: 8) {
                    SessionStudyField(title: "Task Description", value: task.taskDescription, style: .multiline)
                    SessionStudyField(title: "Anti-Goal", value: task.milestone?.goal?.antiGoal ?? "", style: .multiline)
                    SessionStudyField(title: "Sacrifice", value: task.milestone?.goal?.sacrifice ?? "", style: .multiline)
                }
            }

            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("No session is created for this selected task.")
                    } icon: {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(GoalTrackerTheme.moduleIconRed)
                    }
                        .font(.custom("Helvetica Neue", size: 15).weight(.semibold))
                        .foregroundStyle(Color.black)
                    Text("Create a Session to prepare the expected result, what, when, why, how, and how much before starting focus.")
                        .foregroundStyle(Color.black.opacity(0.72))
                    Button(action: addSession) {
                        Label("Add Session", systemImage: "plus")
                    }
                    .buttonStyle(GoalTrackerDimButtonStyle())
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GoalTrackerTheme.creamWork)
                .overlay(
                    Rectangle().stroke(GoalTrackerTheme.appYellow.opacity(0.38), lineWidth: 1)
                )
            } else {
                ForEach(sessions) { session in
                    let isSelectedSession = selectedSession?.id == session.id
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            SessionStatusCircle(status: session.status, size: 20)
                            Text(session.displayLabel)
                                .font(.custom("Helvetica Neue", size: 15).weight(.bold))
                            if isSelectedSession {
                                StatusBadge(text: "Active", color: GoalTrackerTheme.appYellow.opacity(0.75))
                            }
                            Spacer()
                            Text(session.sessionDate.map { DateUtils.displayDate($0) } ?? "No date")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Button("Update") {
                                editSession(session)
                            }
                            .buttonStyle(GoalTrackerDimButtonStyle())
                        }
                        SessionStudyGrid(session: session)
                    }
                    .padding(12)
                    .background(sessionBlockBackground(for: session, isSelectedSession: isSelectedSession))
                    .overlay(
                        Rectangle()
                            .stroke(sessionBlockBorder(for: session, isSelectedSession: isSelectedSession), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 1120, alignment: .top)
        .background(GoalTrackerTheme.headerFill)
        .overlay(
            Rectangle().stroke(GoalTrackerTheme.appYellow.opacity(0.34), lineWidth: 1)
        )
    }

    private func sessionBlockBackground(for session: WorkSession, isSelectedSession: Bool) -> Color {
        if isSelectedSession {
            return GoalTrackerTheme.creamWork.opacity(0.58)
        }

        if session.status == .completed {
            return GoalTrackerTheme.rowCompleted.opacity(0.48)
        }

        return Color.white
    }

    private func sessionBlockBorder(for session: WorkSession, isSelectedSession: Bool) -> Color {
        if isSelectedSession {
            return GoalTrackerTheme.appYellow.opacity(0.46)
        }

        if session.status == .completed {
            return GoalTrackerTheme.completed.opacity(0.48)
        }

        return Color.primary.opacity(0.12)
    }
}

private struct SessionStudyField: View {
    enum Style {
        case compact
        case multiline
        case large
    }

    let title: String
    let value: String
    var style: Style = .compact

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.black.opacity(0.56))

            Text(value.isEmpty ? " " : value)
                .font(.custom("Helvetica Neue", size: 13))
                .foregroundStyle(Color.black)
                .lineLimit(style == .compact ? 2 : nil)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .padding(.horizontal, 9)
                .padding(.vertical, style == .compact ? 7 : 8)
                .background(Color.white)
                .overlay(Rectangle().stroke(Color.black.opacity(0.10), lineWidth: 1))
        }
    }

    private var minHeight: CGFloat {
        switch style {
        case .compact: 0
        case .multiline: 54
        case .large: 68
        }
    }
}
