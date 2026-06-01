import CoreData
import Foundation

@MainActor
enum PreviewDataService {
    static func installReadmePreviewData(in context: NSManagedObjectContext) {
        DemoDataService.clearAllData(in: context)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func date(daysFromToday days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: today) ?? today
        }

        let product = CoreValue(context: context, name: "Product", valueDescription: "Ship useful product improvements.")
        let engineering = CoreValue(context: context, name: "Engineering", valueDescription: "Keep quality high and delivery steady.")
        let design = CoreValue(context: context, name: "Design", valueDescription: "Make the product clear and usable.")
        let operations = CoreValue(context: context, name: "Operations", valueDescription: "Protect reliability and reduce friction.")

        let releaseGoal = Goal(
            context: context,
            name: "Launch version 1.2 release plan",
            priority: .high,
            startDate: date(daysFromToday: -10),
            endDate: date(daysFromToday: 18),
            antiGoal: "Last-minute release chaos",
            sacrifice: "Unplanned scope changes",
            coreValues: [product, engineering]
        )
        let releaseMilestone = Milestone(
            context: context,
            name: "Prepare release candidate",
            goal: releaseGoal,
            startDate: releaseGoal.startDate,
            endDate: releaseGoal.endDate
        )
        let releaseTask = TaskItem(
            context: context,
            name: "Validate release checklist",
            milestone: releaseMilestone,
            priority: .high,
            status: .active,
            taskType: .deep,
            taskDescription: "Review blockers, QA coverage, and rollout timing.",
            estimatedMinutes: 90
        )
        _ = WorkSession(
            context: context,
            task: releaseTask,
            sessionLabel: "Release checklist review",
            estimatedMinutes: 90,
            actualMinutes: 45,
            expectedResult: "Confirm release readiness",
            whatText: "Review pending release items",
            whenText: "Today",
            whyText: "Reduce risk before shipping",
            howText: "Work through the checklist top to bottom",
            howMuchText: "90 min",
            status: .partial,
            sessionDate: date(daysFromToday: 0),
            sessionNotes: "Half complete"
        )

        let dashboardGoal = Goal(
            context: context,
            name: "Refresh dashboard metrics layout",
            priority: .medium,
            startDate: date(daysFromToday: 0),
            endDate: date(daysFromToday: 24),
            antiGoal: "Unreadable dashboard summaries",
            sacrifice: "Extra visual clutter",
            coreValues: [design, product]
        )
        let dashboardMilestone = Milestone(
            context: context,
            name: "Design metrics summary cards",
            goal: dashboardGoal,
            startDate: dashboardGoal.startDate,
            endDate: dashboardGoal.endDate
        )
        _ = TaskItem(
            context: context,
            name: "Draft new dashboard card specs",
            milestone: dashboardMilestone,
            priority: .medium,
            status: .notStarted,
            taskType: .deep,
            taskDescription: "Define layout, density, and hierarchy for summary cards.",
            estimatedMinutes: 75
        )

        let incidentGoal = Goal(
            context: context,
            name: "Close overdue backup audit items",
            priority: .high,
            startDate: date(daysFromToday: -20),
            endDate: date(daysFromToday: -2),
            antiGoal: "Unverified restore paths",
            sacrifice: "Leaving audit gaps for later",
            coreValues: [operations, engineering]
        )
        let incidentMilestone = Milestone(
            context: context,
            name: "Review restore and retention logs",
            goal: incidentGoal,
            startDate: incidentGoal.startDate,
            endDate: incidentGoal.endDate
        )
        _ = TaskItem(
            context: context,
            name: "Check missing retention alerts",
            milestone: incidentMilestone,
            priority: .high,
            status: .active,
            taskType: .deep,
            taskDescription: "Audit alerting gaps and define follow-up work.",
            estimatedMinutes: 60
        )

        let archiveGoal = Goal(
            context: context,
            name: "Archive completed onboarding updates",
            priority: .low,
            startDate: date(daysFromToday: -18),
            endDate: date(daysFromToday: -4),
            antiGoal: "Leaving outdated onboarding docs live",
            sacrifice: "Keeping duplicate documentation",
            coreValues: [operations, design]
        )
        let archiveMilestone = Milestone(
            context: context,
            name: "Close onboarding cleanup pass",
            goal: archiveGoal,
            startDate: archiveGoal.startDate,
            endDate: archiveGoal.endDate
        )
        let archiveTask = TaskItem(
            context: context,
            name: "Publish final onboarding checklist",
            milestone: archiveMilestone,
            priority: .medium,
            status: .completed,
            taskType: .shallow,
            taskDescription: "Finalize and publish the checklist.",
            estimatedMinutes: 30
        )
        _ = WorkSession(
            context: context,
            task: archiveTask,
            sessionLabel: "Checklist publish",
            estimatedMinutes: 30,
            actualMinutes: 30,
            expectedResult: "Checklist published",
            whatText: "Publish onboarding checklist",
            whenText: "Last week",
            whyText: "Finish the cleanup cycle",
            howText: "Publish and verify links",
            howMuchText: "30 min",
            status: .completed,
            sessionDate: date(daysFromToday: -5),
            sessionNotes: "Done"
        )

        try? context.save()
    }
}
