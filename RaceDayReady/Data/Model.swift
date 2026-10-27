//
//  Model.swift
//  Race Day Ready
//
//  The Core Data model, built in code so there is no .xcdatamodeld file to keep in sync.
//  Everything that belongs to a trip hangs off Trip through a relationship, which is what
//  lets iCloud share a whole trip (people, packing list, outfits, to-dos, shots) at once.
//
//  CloudKit rules this model follows: every attribute is optional or has a default,
//  every relationship is optional and has an inverse, and nothing is ordered or unique.
//

import CoreData

@objc(Trip)
final class Trip: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var name: String?
    @NSManaged var catalogID: String?
    @NSManaged var theme: String?
    @NSManaged var tagline: String?
    @NSManaged var climate: String?
    @NSManaged var startDay: String?
    @NSManaged var endDay: String?
    @NSManaged var arriveDay: String?
    @NSManaged var departDay: String?
    @NSManaged var timeZoneID: String?
    @NSManaged var racesJSON: String?
    @NSManaged var challengesJSON: String?
    @NSManaged var eventsJSON: String?
    @NSManaged var extrasJSON: String?
    @NSManaged var expoCSV: String?
    @NSManaged var createdAt: Date?
    @NSManaged var people: NSSet?
    @NSManaged var items: NSSet?
    @NSManaged var outfits: NSSet?
    @NSManaged var tasks: NSSet?
    @NSManaged var shots: NSSet?
}

@objc(Person)
final class Person: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var name: String?
    @NSManaged var colorIndex: Int16
    @NSManaged var runsCSV: String?
    @NSManaged var traveling: Bool
    @NSManaged var sortOrder: Int16
    @NSManaged var trip: Trip?
}

@objc(PackItem)
final class PackItem: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var text: String?
    @NSManaged var qty: Int16
    @NSManaged var bag: String?
    @NSManaged var category: String?
    @NSManaged var whoKey: String?
    @NSManaged var dayKey: String?
    @NSManaged var status: String?
    @NSManaged var note: String?
    @NSManaged var packed: Bool
    @NSManaged var createdAt: Date?
    @NSManaged var trip: Trip?
    @NSManaged var outfit: Outfit?
}

@objc(Outfit)
final class Outfit: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var slot: String?
    @NSManaged var title: String?
    @NSManaged var theme: String?
    @NSManaged var ideasKey: String?
    @NSManaged var raceID: String?
    @NSManaged var eventID: String?
    @NSManaged var bag: String?
    @NSManaged var whoKey: String?
    @NSManaged var dayKey: String?
    @NSManaged var note: String?
    @NSManaged var sortOrder: Double
    @NSManaged var trip: Trip?
    @NSManaged var items: NSSet?
    @NSManaged var shots: NSSet?
}

@objc(PrepTask)
final class PrepTask: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var title: String?
    @NSManaged var dueDay: String?
    @NSManaged var whoKey: String?
    @NSManaged var done: Bool
    @NSManaged var note: String?
    @NSManaged var createdAt: Date?
    @NSManaged var trip: Trip?
}

@objc(Shot)
final class Shot: NSManagedObject {
    @NSManaged var uuid: UUID?
    @NSManaged var title: String?
    @NSManaged var hook: String?
    @NSManaged var sound: String?
    @NSManaged var howTo: String?
    @NSManaged var location: String?
    @NSManaged var dayKey: String?
    @NSManaged var time: String?
    @NSManaged var durationMin: Int16
    @NSManaged var platform: String?
    @NSManaged var ideaID: String?
    @NSManaged var filmed: Bool
    @NSManaged var whoKey: String?
    @NSManaged var note: String?
    @NSManaged var createdAt: Date?
    @NSManaged var trip: Trip?
    @NSManaged var outfit: Outfit?
}

extension Trip: Identifiable {}
extension Person: Identifiable {}
extension PackItem: Identifiable {}
extension Outfit: Identifiable {}
extension PrepTask: Identifiable {}
extension Shot: Identifiable {}

// MARK: - Model description

enum ModelBuilder {
    /// Built once and shared, so Core Data never sees two descriptions of the same classes.
    static let model: NSManagedObjectModel = build()

    private static func attr(_ name: String, _ type: NSAttributeType, _ defaultValue: Any? = nil) -> NSAttributeDescription {
        let a = NSAttributeDescription()
        a.name = name
        a.attributeType = type
        a.isOptional = true
        if let defaultValue { a.defaultValue = defaultValue }
        return a
    }

    private static func entity(_ name: String, _ attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let e = NSEntityDescription()
        e.name = name
        e.managedObjectClassName = name
        e.properties = attributes
        return e
    }

    private static func relate(_ a: NSEntityDescription, _ aName: String, toMany aToMany: Bool, deleteRule aRule: NSDeleteRule,
                               _ b: NSEntityDescription, _ bName: String, toMany bToMany: Bool, deleteRule bRule: NSDeleteRule) {
        let ab = NSRelationshipDescription()
        ab.name = aName
        ab.destinationEntity = b
        ab.isOptional = true
        ab.minCount = 0
        ab.maxCount = aToMany ? 0 : 1
        ab.deleteRule = aRule

        let ba = NSRelationshipDescription()
        ba.name = bName
        ba.destinationEntity = a
        ba.isOptional = true
        ba.minCount = 0
        ba.maxCount = bToMany ? 0 : 1
        ba.deleteRule = bRule

        ab.inverseRelationship = ba
        ba.inverseRelationship = ab
        a.properties.append(ab)
        b.properties.append(ba)
    }

    private static func build() -> NSManagedObjectModel {
        let trip = entity("Trip", [
            attr("uuid", .UUIDAttributeType), attr("name", .stringAttributeType), attr("catalogID", .stringAttributeType),
            attr("theme", .stringAttributeType), attr("tagline", .stringAttributeType), attr("climate", .stringAttributeType),
            attr("startDay", .stringAttributeType), attr("endDay", .stringAttributeType),
            attr("arriveDay", .stringAttributeType), attr("departDay", .stringAttributeType),
            attr("timeZoneID", .stringAttributeType), attr("racesJSON", .stringAttributeType),
            attr("challengesJSON", .stringAttributeType), attr("eventsJSON", .stringAttributeType),
            attr("extrasJSON", .stringAttributeType), attr("expoCSV", .stringAttributeType), attr("createdAt", .dateAttributeType)
        ])
        let person = entity("Person", [
            attr("uuid", .UUIDAttributeType), attr("name", .stringAttributeType), attr("colorIndex", .integer16AttributeType, 0),
            attr("runsCSV", .stringAttributeType), attr("traveling", .booleanAttributeType, true), attr("sortOrder", .integer16AttributeType, 0)
        ])
        let item = entity("PackItem", [
            attr("uuid", .UUIDAttributeType), attr("text", .stringAttributeType), attr("qty", .integer16AttributeType, 1),
            attr("bag", .stringAttributeType), attr("category", .stringAttributeType), attr("whoKey", .stringAttributeType),
            attr("dayKey", .stringAttributeType), attr("status", .stringAttributeType), attr("note", .stringAttributeType),
            attr("packed", .booleanAttributeType, false), attr("createdAt", .dateAttributeType)
        ])
        let outfit = entity("Outfit", [
            attr("uuid", .UUIDAttributeType), attr("slot", .stringAttributeType), attr("title", .stringAttributeType),
            attr("theme", .stringAttributeType), attr("ideasKey", .stringAttributeType), attr("raceID", .stringAttributeType),
            attr("eventID", .stringAttributeType), attr("bag", .stringAttributeType), attr("whoKey", .stringAttributeType),
            attr("dayKey", .stringAttributeType), attr("note", .stringAttributeType), attr("sortOrder", .doubleAttributeType, 0.0)
        ])
        let task = entity("PrepTask", [
            attr("uuid", .UUIDAttributeType), attr("title", .stringAttributeType), attr("dueDay", .stringAttributeType),
            attr("whoKey", .stringAttributeType), attr("done", .booleanAttributeType, false), attr("note", .stringAttributeType),
            attr("createdAt", .dateAttributeType)
        ])
        let shot = entity("Shot", [
            attr("uuid", .UUIDAttributeType), attr("title", .stringAttributeType), attr("hook", .stringAttributeType),
            attr("sound", .stringAttributeType), attr("howTo", .stringAttributeType), attr("location", .stringAttributeType),
            attr("dayKey", .stringAttributeType), attr("time", .stringAttributeType), attr("durationMin", .integer16AttributeType, 15),
            attr("platform", .stringAttributeType), attr("ideaID", .stringAttributeType), attr("filmed", .booleanAttributeType, false),
            attr("whoKey", .stringAttributeType), attr("note", .stringAttributeType), attr("createdAt", .dateAttributeType)
        ])

        relate(trip, "people", toMany: true, deleteRule: .cascadeDeleteRule, person, "trip", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(trip, "items", toMany: true, deleteRule: .cascadeDeleteRule, item, "trip", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(trip, "outfits", toMany: true, deleteRule: .cascadeDeleteRule, outfit, "trip", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(trip, "tasks", toMany: true, deleteRule: .cascadeDeleteRule, task, "trip", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(trip, "shots", toMany: true, deleteRule: .cascadeDeleteRule, shot, "trip", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(outfit, "items", toMany: true, deleteRule: .nullifyDeleteRule, item, "outfit", toMany: false, deleteRule: .nullifyDeleteRule)
        relate(outfit, "shots", toMany: true, deleteRule: .nullifyDeleteRule, shot, "outfit", toMany: false, deleteRule: .nullifyDeleteRule)

        let model = NSManagedObjectModel()
        model.entities = [trip, person, item, outfit, task, shot]
        return model
    }
}
