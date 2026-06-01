# Goal Tracker

Goal Tracker is a native macOS SwiftUI app for Values, Goals, Milestones, Tasks, Sessions, Daily Streak, and Dashboard focus tracking.

## Run

Use the project-local run script:

```bash
./script/build_and_run.sh
```

The script compiles the SwiftUI/Core Data app with `swiftc`, generates the app icon, stages `dist/Goal Tracker.app`, and launches it as a normal macOS app bundle. The Codex Run action is wired to the same script.

## Persistence

Data is stored locally with Core Data in Application Support under `Goal Tracker/GoalTracker.sqlite`. The app is offline-first and does not require login or a backend.

Core Data stores tracker data only: Values, Goals, Milestones, Tasks, and Sessions. UI preferences such as theme, filters, selected focus, delete confirmations, session-date confirmation, and backup toggles are stored in macOS preferences through SwiftUI `@AppStorage`.

## Data Safety

Goal Tracker includes mirrored JSON backup support for iCloud Drive:

- Automatic JSON backups are written to both `iCloud Drive/Goal Tracker/Backups/Auto` and `iCloud Drive/Vault/Backups/Goal Tracker/Auto`.
- Manual JSON backups are written to both `iCloud Drive/Goal Tracker/Backups/Manual` and `iCloud Drive/Vault/Backups/Goal Tracker/Manual`.
- Before restoring a JSON backup, the app attempts a pre-restore backup in both `iCloud Drive/Goal Tracker/Backups/Pre-Restore` and `iCloud Drive/Vault/Backups/Goal Tracker/Pre-Restore`.
- The automatic backup folder keeps the latest 30 automatic JSON backups.
- The manual backup folder keeps the latest 20 manual JSON backups.
- Every JSON backup includes `schemaVersion` and `appVersion`.
- JSON backups are decoded and verified immediately after writing before they are treated as successful.
- Settings includes a Data Health check for entity counts, invalid dates, overlapping Milestone ranges, broken relationships, and negative minute values.
- CSV export is available as a readable fallback, but JSON is the restore format.

## Included

- Top tabs for Dashboard, Values Sheet, Goals Sheet, Milestones Sheet, Tasks Sheet, Sessions Sheet, Daily Streak, and Settings
- Core Data models for Values, Goals, Milestones, Tasks, Sessions, and Settings
- CRUD for Values, Goals, Milestones, Tasks, and Sessions
- High, Medium, and Low Goal priorities
- Goal and Milestone Due Date labeling with computed Goal planning status
- Session-weighted progress: Partial Sessions count as 0.5, Completed Sessions count as 1, then roll up through Tasks, Milestones, and Goals
- Read-only Dashboard and Daily Streak views
- Demo data reset and clear-all controls
- JSON import/export and CSV export
