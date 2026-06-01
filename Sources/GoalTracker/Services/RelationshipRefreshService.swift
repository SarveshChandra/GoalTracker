import Foundation

enum RelationshipRefreshService {
    static func touchValueCascade(_ value: CoreValue?, now: Date = Date()) {
        guard let value else { return }
        value.updatedAt = now
        value.goals.forEach { touchGoalCascade($0, now: now) }
        value.standaloneTasks.forEach { task in
            touchTaskCascade(task, now: now)
            task.coreValue?.updatedAt = now
        }
    }

    static func touchGoalCascade(_ goal: Goal?, now: Date = Date()) {
        guard let goal else { return }
        goal.updatedAt = now
        goal.coreValues.forEach { $0.updatedAt = now }
        goal.milestones.forEach { touchMilestoneCascade($0, now: now) }
    }

    static func touchMilestoneCascade(_ milestone: Milestone?, now: Date = Date()) {
        guard let milestone else { return }
        milestone.updatedAt = now
        milestone.goal?.updatedAt = now
        milestone.goal?.coreValues.forEach { $0.updatedAt = now }
        milestone.tasks.forEach { touchTaskCascade($0, now: now) }
    }

    static func touchTaskCascade(_ task: TaskItem?, now: Date = Date()) {
        guard let task else { return }
        task.updatedAt = now
        task.coreValue?.updatedAt = now
        task.milestone?.updatedAt = now
        task.milestone?.goal?.updatedAt = now
        task.milestone?.goal?.coreValues.forEach { $0.updatedAt = now }
        task.sessions.filter { !$0.isDeleted }.forEach { $0.updatedAt = now }
    }

    static func touchTaskLineage(_ task: TaskItem?, now: Date = Date()) {
        guard let task else { return }
        task.updatedAt = now
        task.coreValue?.updatedAt = now
        task.milestone?.updatedAt = now
        task.milestone?.goal?.updatedAt = now
        task.milestone?.goal?.coreValues.forEach { $0.updatedAt = now }
    }

    static func touchSessionLineage(_ session: WorkSession?, now: Date = Date()) {
        guard let session else { return }
        session.updatedAt = now
        touchTaskLineage(session.task, now: now)
    }
}
