import AppKit
import SwiftUI

struct StoreLoadFailureView: View {
    let error: Error

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Goal Tracker couldn't open its local data.")
                .font(.system(size: 24, weight: .bold))

            Text("The app is still intact, but the Core Data store could not be loaded. Open the data or backup folders below, fix the underlying file issue, then relaunch the app.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Error")
                    .font(.headline)
                Text(error.localizedDescription)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Open App Support Folder", action: openAppSupportFolder)
                Button("Open Backup Folder", action: openBackupFolder)
            }

            Text("App Support: ~/Library/Application Support/Goal Tracker")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openAppSupportFolder() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Goal Tracker", isDirectory: true) else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    private func openBackupFolder() {
        guard let url = try? BackupService.revealBackupFolder() else { return }
        NSWorkspace.shared.open(url)
    }
}
