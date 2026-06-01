import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let loadError: Error?

    init(inMemory: Bool = false) {
        let model = Self.makeModel()
        container = NSPersistentContainer(name: "GoalTracker", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions = [NSPersistentStoreDescription()]
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("Goal Tracker", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let storeURL = support.appendingPathComponent("GoalTracker.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.shouldInferMappingModelAutomatically = true
            description.shouldMigrateStoreAutomatically = true
            container.persistentStoreDescriptions = [description]
        }

        var persistentStoreLoadError: Error?
        container.loadPersistentStores { _, error in
            if let error {
                persistentStoreLoadError = error
            }
        }
        loadError = persistentStoreLoadError

        if loadError == nil {
            container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true
        }
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let valueEntity = entity("CoreValue", CoreValue.self)
        let goalEntity = entity("Goal", Goal.self)
        let milestoneEntity = entity("Milestone", Milestone.self)
        let taskEntity = entity("TaskItem", TaskItem.self)
        let sessionEntity = entity("WorkSession", WorkSession.self)

        valueEntity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("valueDescription", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        goalEntity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("priorityRaw", .stringAttributeType),
            attribute("startDate", .dateAttributeType),
            attribute("endDate", .dateAttributeType),
            attribute("progress", .doubleAttributeType),
            attribute("antiGoal", .stringAttributeType),
            attribute("sacrifice", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        milestoneEntity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("startDate", .dateAttributeType),
            attribute("endDate", .dateAttributeType),
            attribute("progress", .doubleAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        taskEntity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("priorityRaw", .stringAttributeType),
            attribute("statusRaw", .stringAttributeType),
            attribute("taskTypeRaw", .stringAttributeType),
            attribute("taskDescription", .stringAttributeType),
            attribute("estimatedMinutes", .integer64AttributeType),
            attribute("resultNotes", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        sessionEntity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("sessionLabel", .stringAttributeType, defaultValue: ""),
            attribute("estimatedMinutes", .integer64AttributeType, defaultValue: 0),
            attribute("actualMinutes", .integer64AttributeType),
            attribute("expectedResult", .stringAttributeType),
            attribute("whatText", .stringAttributeType),
            attribute("whenText", .stringAttributeType),
            attribute("whyText", .stringAttributeType),
            attribute("howText", .stringAttributeType),
            attribute("howMuchText", .stringAttributeType),
            attribute("statusRaw", .stringAttributeType),
            attribute("sessionDate", .dateAttributeType, optional: true),
            attribute("sessionNotes", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("updatedAt", .dateAttributeType)
        ]

        let valueGoals = relationship("goals", destination: goalEntity, toMany: true, deleteRule: .nullifyDeleteRule)
        let goalValues = relationship("coreValues", destination: valueEntity, toMany: true, deleteRule: .nullifyDeleteRule)
        valueGoals.inverseRelationship = goalValues
        goalValues.inverseRelationship = valueGoals

        let goalMilestones = relationship("milestones", destination: milestoneEntity, toMany: true, deleteRule: .cascadeDeleteRule)
        let milestoneGoal = relationship("goal", destination: goalEntity, toMany: false, deleteRule: .nullifyDeleteRule, optional: true)
        goalMilestones.inverseRelationship = milestoneGoal
        milestoneGoal.inverseRelationship = goalMilestones

        let milestoneTasks = relationship("tasks", destination: taskEntity, toMany: true, deleteRule: .cascadeDeleteRule)
        let taskMilestone = relationship("milestone", destination: milestoneEntity, toMany: false, deleteRule: .nullifyDeleteRule, optional: true)
        milestoneTasks.inverseRelationship = taskMilestone
        taskMilestone.inverseRelationship = milestoneTasks

        let valueStandaloneTasks = relationship("standaloneTasks", destination: taskEntity, toMany: true, deleteRule: .nullifyDeleteRule)
        let taskCoreValue = relationship("coreValue", destination: valueEntity, toMany: false, deleteRule: .nullifyDeleteRule, optional: true)
        valueStandaloneTasks.inverseRelationship = taskCoreValue
        taskCoreValue.inverseRelationship = valueStandaloneTasks

        let taskSessions = relationship("sessions", destination: sessionEntity, toMany: true, deleteRule: .cascadeDeleteRule)
        let sessionTask = relationship("task", destination: taskEntity, toMany: false, deleteRule: .nullifyDeleteRule, optional: true)
        taskSessions.inverseRelationship = sessionTask
        sessionTask.inverseRelationship = taskSessions

        valueEntity.properties.append(contentsOf: [valueGoals, valueStandaloneTasks])
        goalEntity.properties.append(contentsOf: [goalValues, goalMilestones])
        milestoneEntity.properties.append(contentsOf: [milestoneGoal, milestoneTasks])
        taskEntity.properties.append(contentsOf: [taskCoreValue, taskMilestone, taskSessions])
        sessionEntity.properties.append(sessionTask)

        model.entities = [valueEntity, goalEntity, milestoneEntity, taskEntity, sessionEntity]
        return model
    }

    private static func entity<T: NSManagedObject>(_ name: String, _ type: T.Type) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(type)
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func relationship(
        _ name: String,
        destination: NSEntityDescription,
        toMany: Bool,
        deleteRule: NSDeleteRule,
        optional: Bool = true
    ) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.destinationEntity = destination
        relationship.minCount = 0
        relationship.maxCount = toMany ? 0 : 1
        relationship.isOptional = optional
        relationship.deleteRule = deleteRule
        return relationship
    }
}

extension NSManagedObjectContext {
    func fetchAll<T: NSManagedObject>(_ type: T.Type, sortDescriptors: [NSSortDescriptor] = []) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.sortDescriptors = sortDescriptors
        return try fetch(request)
    }
}
