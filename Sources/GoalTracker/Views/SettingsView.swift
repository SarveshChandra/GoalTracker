import AppKit
import CoreData
import SwiftUI

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var managedObjectContext
    @AppStorage("GoalTracker.themePreference") private var themePreferenceRaw = ThemePreference.system.rawValue
    @AppStorage("GoalTracker.defaultDashboardStartScreen") private var defaultDashboardStartScreen = true
    @AppStorage("GoalTracker.confirmBeforeDelete") private var confirmBeforeDelete = true
    @AppStorage("GoalTracker.confirmSessionDateClear") private var confirmSessionDateClear = true
    @AppStorage("GoalTracker.autoICloudBackupsEnabled") private var autoICloudBackupsEnabled = true
    @AppStorage("GoalTracker.lastAutomaticBackupAt") private var lastAutomaticBackupAt = 0.0
    @AppStorage("GoalTracker.lastBackupPath") private var lastBackupPath = ""
    @AppStorage("GoalTracker.lastBackupError") private var lastBackupError = ""
    @State private var message: String?
    @State private var restoreCandidate: URL?
    @State private var showRestoreConfirmation = false
    @State private var healthReport: DataHealthReport?
    @State private var healthError: String?

    private var selectedThemePreference: ThemePreference {
        ThemePreference(rawValue: themePreferenceRaw) ?? .system
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ModuleHeader(
                    title: "Settings",
                    subtitle: "Local preferences and export tools for Goal Tracker."
                ) {
                    EmptyView()
                }

                VStack(alignment: .leading, spacing: 14) {
                    Picker("Theme", selection: Binding(
                        get: { selectedThemePreference },
                        set: { newTheme in
                            themePreferenceRaw = newTheme.rawValue
                        }
                    )) {
                        ForEach(ThemePreference.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(GoalTrackerTheme.secondaryAccent)

                    Toggle("Default dashboard start screen", isOn: $defaultDashboardStartScreen)

                    Toggle("Confirm before delete", isOn: $confirmBeforeDelete)

                    Toggle("Ask before clearing Session Date", isOn: $confirmSessionDateClear)
                }
                .goalCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Safety")
                        .font(.headline)

                    Toggle("Automatic iCloud JSON backups", isOn: $autoICloudBackupsEnabled)

                    Text("Backups are saved in iCloud Drive under both Goal Tracker/Backups and Vault/Backups/Goal Tracker. JSON backups are the restore source; CSV exports are only a readable fallback.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            runManualBackup()
                        } label: {
                            Label("Backup Now", systemImage: "icloud.and.arrow.up")
                        }

                        Button {
                            chooseRestoreBackup()
                        } label: {
                            Label("Restore JSON Backup", systemImage: "arrow.clockwise.icloud")
                        }

                        Button {
                            openBackupFolder()
                        } label: {
                            Label("Open Backup Folder", systemImage: "folder")
                        }
                    }

                    if lastAutomaticBackupAt > 0 {
                        Text("Last automatic backup: \(DateUtils.dayTimeFormatter.string(from: Date(timeIntervalSince1970: lastAutomaticBackupAt)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !lastBackupPath.isEmpty {
                        Text(lastBackupPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    if !lastBackupError.isEmpty {
                        Text(lastBackupError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .goalCard()

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Data Health")
                            .font(.headline)
                        Spacer()
                        Button {
                            runDataCheck()
                        } label: {
                            Label("Run Data Check", systemImage: "checkmark.shield")
                        }
                    }

                    if let healthReport {
                        HStack(spacing: 8) {
                            HealthCountPill(title: "Values", count: healthReport.valuesCount)
                            HealthCountPill(title: "Goals", count: healthReport.goalsCount)
                            HealthCountPill(title: "Milestones", count: healthReport.milestonesCount)
                            HealthCountPill(title: "Tasks", count: healthReport.tasksCount)
                            HealthCountPill(title: "Sessions", count: healthReport.sessionsCount)
                        }

                        Label(
                            healthReport.statusText,
                            systemImage: healthReport.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(healthReport.isHealthy ? .green : .red)
                        .font(.custom("Helvetica Neue", size: 13).weight(.semibold))

                        Text("Checked: \(DateUtils.dayFormatter.string(from: healthReport.checkedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if !healthReport.issues.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(healthReport.issues.indices, id: \.self) { index in
                                    Text("• \(healthReport.issues[index])")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            .textSelection(.enabled)
                        }
                    } else {
                        Text("Run a check to verify data counts, date ranges, relationships, active goal priorities, and minute values.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let healthError {
                        Text(healthError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .goalCard()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Data")
                        .font(.headline)

                    HStack {
                        Button {
                            runExportJSON()
                        } label: {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            runExportCSV()
                        } label: {
                            Label("Export CSV", systemImage: "tablecells")
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .goalCard()
            }
            .padding(24)
        }
        .confirmationDialog("Restore JSON Backup?", isPresented: $showRestoreConfirmation) {
            Button("Replace Current Data", role: .destructive) {
                runRestoreBackup()
            }
            Button("Cancel", role: .cancel) {
                restoreCandidate = nil
            }
        } message: {
            Text("This replaces current Values, Goals, Milestones, Tasks, and Sessions. Goal Tracker will try to create a pre-restore backup first.")
        }
    }

    private func runManualBackup() {
        do {
            let result = try BackupService.createManualBackup(from: managedObjectContext)
            let backupSummary = backupPathSummary(for: result)
            lastBackupPath = backupSummary
            lastBackupError = ""
            message = "Created and verified iCloud JSON backups at:\n\(backupSummary)"
        } catch {
            lastBackupError = error.localizedDescription
            message = "Backup failed: \(error.localizedDescription)"
        }
    }

    private func chooseRestoreBackup() {
        do {
            if let url = try ImportExportService.chooseJSONFile(title: "Choose Goal Tracker JSON Backup") {
                restoreCandidate = url
                showRestoreConfirmation = true
            }
        } catch {
            message = "Restore selection failed: \(error.localizedDescription)"
        }
    }

    private func runRestoreBackup() {
        guard let restoreCandidate else { return }

        do {
            _ = try? BackupService.createPreRestoreBackup(from: managedObjectContext)
            try ImportExportService.restoreJSON(from: restoreCandidate, into: managedObjectContext)
            message = "Restored backup from \(restoreCandidate.path)"
            self.restoreCandidate = nil
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func openBackupFolder() {
        do {
            let folders = try BackupService.revealBackupFolders()
            lastBackupError = ""
            for folder in folders {
                NSWorkspace.shared.open(folder)
            }
        } catch {
            lastBackupError = error.localizedDescription
            message = "Could not open backup folder: \(error.localizedDescription)"
        }
    }

    private func backupPathSummary(for result: BackupResult) -> String {
        ([result.url] + result.mirroredURLs).map(\.path).joined(separator: "\n")
    }

    private func runDataCheck() {
        do {
            healthReport = try DataHealthService.run(in: managedObjectContext)
            healthError = nil
        } catch {
            healthError = error.localizedDescription
        }
    }

    private func runExportJSON() {
        do {
            if let url = try ImportExportService.exportJSON(from: managedObjectContext) {
                message = "Exported JSON to \(url.path)"
            }
        } catch {
            message = "JSON export failed: \(error.localizedDescription)"
        }
    }

    private func runExportCSV() {
        do {
            if let url = try ImportExportService.exportCSV(from: managedObjectContext) {
                message = "Exported CSV files to \(url.path)"
            }
        } catch {
            message = "CSV export failed: \(error.localizedDescription)"
        }
    }
}

private struct HealthCountPill: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.custom("Helvetica Neue", size: 15).weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(GoalTrackerTheme.computedFill)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
