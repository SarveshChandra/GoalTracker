import CoreData
import Foundation

enum BackupKind: String {
    case automatic = "Auto"
    case manual = "Manual"
    case preRestore = "PreRestore"
}

struct BackupResult {
    let url: URL
    let mirroredURLs: [URL]
    let createdAt: Date
    let prunedCount: Int
}

enum BackupServiceError: LocalizedError {
    case iCloudDriveUnavailable

    var errorDescription: String? {
        switch self {
        case .iCloudDriveUnavailable:
            "iCloud Drive is not available. Make sure iCloud Drive is enabled for this Mac."
        }
    }
}

@MainActor
enum BackupService {
    static let automaticBackupInterval: TimeInterval = 86_400
    static let automaticBackupLimit = 30
    static let manualBackupLimit = 20

    static func createAutomaticBackupIfNeeded(
        from context: NSManagedObjectContext,
        lastBackupDate: Date?,
        minimumInterval: TimeInterval = 86_400,
        userDefaults: UserDefaults = .standard
    ) throws -> BackupResult? {
        if let lastBackupDate, Date().timeIntervalSince(lastBackupDate) < minimumInterval {
            return nil
        }

        let folders = try automaticBackupFolders()
        return try writeBackup(from: context, to: folders, kind: .automatic, userDefaults: userDefaults)
    }

    static func createManualBackup(from context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> BackupResult {
        let folders = try manualBackupFolders()
        return try writeBackup(from: context, to: folders, kind: .manual, userDefaults: userDefaults)
    }

    static func createPreRestoreBackup(from context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) throws -> BackupResult {
        let folders = try preRestoreBackupFolders()
        return try writeBackup(from: context, to: folders, kind: .preRestore, userDefaults: userDefaults)
    }

    static func writeBackup(
        from context: NSManagedObjectContext,
        to folder: URL,
        kind: BackupKind,
        userDefaults: UserDefaults = .standard
    ) throws -> BackupResult {
        try writeBackup(
            from: context,
            to: [folder],
            kind: kind,
            userDefaults: userDefaults
        )
    }

    static func writeBackup(
        from context: NSManagedObjectContext,
        to folders: [URL],
        kind: BackupKind,
        userDefaults: UserDefaults = .standard
    ) throws -> BackupResult {
        let fileManager = FileManager.default
        let createdAt = Date()
        let urls = uniqueBackupURLs(in: folders, kind: kind, createdAt: createdAt)
        for url in urls {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        for url in urls {
            try ImportExportService.writeJSONSnapshot(from: context, to: url, userDefaults: userDefaults)
        }

        let prunedCount = try pruneBackupsIfNeeded(in: folders, kind: kind)
        return BackupResult(url: urls[0], mirroredURLs: Array(urls.dropFirst()), createdAt: createdAt, prunedCount: prunedCount)
    }

    static func revealBackupFolder() throws -> URL {
        try revealBackupFolders()[0]
    }

    static func revealBackupFolders() throws -> [URL] {
        let folders = try backupRootFolders()
        for folder in folders {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folders
    }

    static func backupRootFolder() throws -> URL {
        try backupRootFolders()[0]
    }

    static func backupRootFolders() throws -> [URL] {
        let root = try iCloudDriveRoot()
        let primary = root
            .appendingPathComponent("Goal Tracker", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
        let secondary = root
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
            .appendingPathComponent("Goal Tracker", isDirectory: true)
        return [primary, secondary]
    }

    static func automaticBackupFolder() throws -> URL {
        try automaticBackupFolders()[0]
    }

    static func automaticBackupFolders() throws -> [URL] {
        try backupRootFolders().map { $0.appendingPathComponent("Auto", isDirectory: true) }
    }

    static func manualBackupFolder() throws -> URL {
        try manualBackupFolders()[0]
    }

    static func manualBackupFolders() throws -> [URL] {
        try backupRootFolders().map { $0.appendingPathComponent("Manual", isDirectory: true) }
    }

    static func preRestoreBackupFolder() throws -> URL {
        try preRestoreBackupFolders()[0]
    }

    static func preRestoreBackupFolders() throws -> [URL] {
        try backupRootFolders().map { $0.appendingPathComponent("Pre-Restore", isDirectory: true) }
    }

    private static func iCloudDriveRoot() throws -> URL {
        let fileManager = FileManager.default
        let cloudDocs = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Mobile Documents", isDirectory: true)
            .appendingPathComponent("com~apple~CloudDocs", isDirectory: true)

        if fileManager.fileExists(atPath: cloudDocs.path) {
            return cloudDocs
        }

        if let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            let documents = ubiquityURL.appendingPathComponent("Documents", isDirectory: true)
            try fileManager.createDirectory(at: documents, withIntermediateDirectories: true)
            return documents
        }

        throw BackupServiceError.iCloudDriveUnavailable
    }

    private static func uniqueBackupURLs(in folders: [URL], kind: BackupKind, createdAt: Date) -> [URL] {
        let timestamp = backupTimestampFormatter.string(from: createdAt)
        let baseName = "GoalTracker-\(kind.rawValue)-\(timestamp)"
        let fileManager = FileManager.default
        var suffix = 1

        while true {
            let fileName = suffix == 1 ? "\(baseName).json" : "\(baseName)-\(suffix).json"
            let candidates = folders.map { $0.appendingPathComponent(fileName) }
            if candidates.allSatisfy({ !fileManager.fileExists(atPath: $0.path) }) {
                return candidates
            }
            suffix += 1
        }
    }

    private static func pruneBackupsIfNeeded(in folders: [URL], kind: BackupKind) throws -> Int {
        guard let limit = retentionLimit(for: kind) else { return 0 }
        return try folders.reduce(0) { partialCount, folder in
            partialCount + (try pruneBackups(in: folder, kind: kind, keeping: limit))
        }
    }

    private static func pruneBackups(in folder: URL, kind: BackupKind, keeping limit: Int) throws -> Int {
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(backupFilePrefix(for: kind)) }
        .sorted { left, right in
            backupDate(for: left) > backupDate(for: right)
        }

        guard files.count > limit else { return 0 }

        let extraFiles = files.dropFirst(limit)
        for file in extraFiles {
            try fileManager.removeItem(at: file)
        }
        return extraFiles.count
    }

    private static func retentionLimit(for kind: BackupKind) -> Int? {
        switch kind {
        case .automatic:
            automaticBackupLimit
        case .manual:
            manualBackupLimit
        case .preRestore:
            nil
        }
    }

    private static func backupFilePrefix(for kind: BackupKind) -> String {
        "GoalTracker-\(kind.rawValue)-"
    }

    private static func backupDate(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        return values?.contentModificationDate ?? values?.creationDate ?? .distantPast
    }

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
