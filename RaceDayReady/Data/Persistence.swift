//
//  Persistence.swift
//  Race Day Ready
//
//  Two stores, the way Apple's iCloud sharing works: "private" holds trips you created,
//  "shared" holds trips other people shared with you. New things are always saved into
//  the same store as the trip they belong to, so they sync to everyone on that trip.
//

import CoreData
import CloudKit
import UIKit

final class Persistence {
    static let shared = Persistence()

    /// Must match the iCloud container in the app's Signing & Capabilities (see README).
    static let cloudContainerID = "iCloud.com.electricsoup.racedayready"

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore?
    private(set) var sharedStore: NSPersistentStore?
    private(set) var cloudEnabled = true

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "RaceDayReady", managedObjectModel: ModelBuilder.model)

        let base = NSPersistentContainer.defaultDirectoryURL()
        let privateURL = inMemory ? URL(fileURLWithPath: "/dev/null") : base.appendingPathComponent("private.sqlite")
        let sharedURL = inMemory ? URL(fileURLWithPath: "/dev/null/shared") : base.appendingPathComponent("shared.sqlite")

        let privateDesc = NSPersistentStoreDescription(url: privateURL)
        let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
        for desc in [privateDesc, sharedDesc] {
            desc.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            desc.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        if !inMemory && Self.hasCloudKitEntitlement {
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudContainerID)
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions
            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudContainerID)
            sharedOptions.databaseScope = .shared
            sharedDesc.cloudKitContainerOptions = sharedOptions
        } else {
            cloudEnabled = false
        }
        container.persistentStoreDescriptions = inMemory ? [privateDesc] : [privateDesc, sharedDesc]

        var failed = false
        container.loadPersistentStores { _, error in
            if let error {
                print("Store failed to load: \(error)")
                failed = true
            }
        }
        if failed && !inMemory {
            // iCloud isn't set up (e.g. a build without the capability). Keep working on this device only.
            cloudEnabled = false
            for desc in container.persistentStoreDescriptions { desc.cloudKitContainerOptions = nil }
            container.loadPersistentStores { _, error in
                if let error { print("Local store failed to load: \(error)") }
            }
        }

        let coordinator = container.persistentStoreCoordinator
        privateStore = coordinator.persistentStore(for: privateURL) ?? coordinator.persistentStores.first
        sharedStore = inMemory ? nil : coordinator.persistentStore(for: sharedURL)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "app"
    }

    /// True when the app was signed with the iCloud (CloudKit) capability. Without it, CloudKit ends the
    /// app at launch, so unsigned builds (CI, or Xcode before a Team is picked) keep data on the device only.
    /// The entitlements are embedded in the signed executable; the key is assembled here so the search
    /// doesn't just find this line's own text.
    static let hasCloudKitEntitlement: Bool = {
        guard let url = Bundle.main.executableURL,
              let data = try? Data(contentsOf: url, options: .alwaysMapped) else { return false }
        let key = ["<key>com", "apple", "developer", "icloud-services</key>"].joined(separator: ".")
        return data.range(of: Data(key.utf8)) != nil
    }()

    // MARK: - Saving

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch { print("Save failed: \(error)") }
    }

    // MARK: - Creating things in the right store

    func store(for trip: Trip) -> NSPersistentStore? {
        trip.objectID.persistentStore ?? privateStore
    }

    /// Makes a new object that lives in the same store as its trip.
    func make<T: NSManagedObject>(_ type: T.Type, in trip: Trip) -> T {
        let obj = NSEntityDescription.insertNewObject(forEntityName: String(describing: T.self), into: viewContext) as! T
        if let store = store(for: trip) { viewContext.assign(obj, to: store) }
        return obj
    }

    func newTrip() -> Trip {
        let trip = NSEntityDescription.insertNewObject(forEntityName: "Trip", into: viewContext) as! Trip
        if let privateStore { viewContext.assign(trip, to: privateStore) }
        trip.uuid = UUID()
        trip.createdAt = Date()
        return trip
    }

    func addPerson(_ name: String, to trip: Trip, runs: [String] = []) -> Person {
        let p = make(Person.self, in: trip)
        p.uuid = UUID()
        p.name = name
        p.traveling = true
        p.runs = runs
        let existing = trip.peopleList
        p.sortOrder = Int16((existing.map { Int($0.sortOrder) }.max() ?? -1) + 1)
        p.colorIndex = Int16(existing.count % 6)
        p.trip = trip
        return p
    }

    @discardableResult
    func addItem(to trip: Trip, text: String, category: String, who: String, qty: Int = 1, bag: Bag = .any,
                 day: String? = nil, outfit: Outfit? = nil, status: ItemStatus = .none, note: String? = nil, packed: Bool = false) -> PackItem {
        let item = make(PackItem.self, in: trip)
        item.uuid = UUID()
        item.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = Starters.categoryIDs.contains(category) ? category : "misc"
        item.whoKey = who
        item.qty = Int16(max(1, min(99, qty)))
        item.bag = bag.rawValue
        item.dayKey = day
        item.outfit = outfit
        item.status = status.rawValue
        item.note = (note?.isEmpty ?? true) ? nil : note
        item.packed = packed
        item.createdAt = Date()
        item.trip = trip
        return item
    }

    @discardableResult
    func addOutfit(to trip: Trip, day: String?, slot: String, title: String = "", theme: String = "", ideasKey: String = "",
                   raceID: String = "", eventID: String = "", who: String, bag: Bag = .any, note: String = "") -> Outfit {
        let o = make(Outfit.self, in: trip)
        o.uuid = UUID()
        o.dayKey = day
        o.slot = slot
        o.title = title
        o.theme = theme
        o.ideasKey = ideasKey.isEmpty ? Starters.themeKey(theme) : ideasKey
        o.raceID = raceID
        o.eventID = eventID
        o.whoKey = who
        o.bag = bag.rawValue
        o.note = note
        o.sortOrder = Date().timeIntervalSince1970
        o.trip = trip
        return o
    }

    @discardableResult
    func addTask(to trip: Trip, title: String, due: String?, who: String = Who.shared, note: String = "") -> PrepTask {
        let t = make(PrepTask.self, in: trip)
        t.uuid = UUID()
        t.title = title
        t.dueDay = due
        t.whoKey = who
        t.note = note
        t.createdAt = Date()
        t.trip = trip
        return t
    }

    @discardableResult
    func addShot(to trip: Trip, title: String, day: String?, time: String? = nil, outfit: Outfit? = nil, who: String = Who.shared,
                 idea: IdeaDef? = nil) -> Shot {
        let s = make(Shot.self, in: trip)
        s.uuid = UUID()
        s.title = title
        s.dayKey = day
        s.time = time
        s.durationMin = 15
        s.outfit = outfit
        s.whoKey = who
        if let idea {
            s.ideaID = idea.id
            s.hook = idea.hook
            s.sound = idea.sound
            s.howTo = idea.how
            s.platform = idea.platforms?.first
        }
        s.createdAt = Date()
        s.trip = trip
        return s
    }

    /// Creates a trip from a weekend in the feed, with everyone running every race.
    @discardableResult
    func createTrip(from def: WeekendDef, people names: [String]) -> Trip {
        let trip = newTrip()
        apply(def, to: trip)
        trip.arriveDay = def.start
        trip.departDay = def.end
        let runs = def.races.map { $0.id }
        for n in names where !n.trimmingCharacters(in: .whitespaces).isEmpty {
            _ = addPerson(n.trimmingCharacters(in: .whitespaces), to: trip, runs: runs)
        }
        if trip.peopleList.isEmpty { _ = addPerson("Me", to: trip, runs: runs) }
        save()
        if let me = trip.peopleList.first { Prefs.setMe(me.key, for: trip) }
        return trip
    }

    func apply(_ def: WeekendDef, to trip: Trip) {
        trip.name = def.short
        trip.catalogID = def.id
        trip.theme = def.type
        trip.tagline = def.tagline
        trip.climate = def.climate
        trip.startDay = def.start
        trip.endDay = def.end
        trip.timeZoneID = def.timeZone ?? TimeZone.current.identifier
        trip.races = def.races
        trip.challenges = def.challenges ?? []
        trip.events = def.events ?? []
        trip.extras = def.extras ?? []
        trip.expo = def.expo ?? []
    }

    // MARK: - Deleting

    func delete(_ object: NSManagedObject) {
        viewContext.delete(object)
        save()
    }

    // MARK: - Sharing

    func isShared(_ trip: Trip) -> Bool {
        if let sharedStore, trip.objectID.persistentStore == sharedStore { return true }
        return existingShare(for: trip) != nil
    }

    func existingShare(for trip: Trip) -> CKShare? {
        guard cloudEnabled, !trip.objectID.isTemporaryID else { return nil }
        return (try? container.fetchShares(matching: [trip.objectID]))?[trip.objectID]
    }

    func canEdit(_ object: NSManagedObject) -> Bool {
        guard cloudEnabled, !object.objectID.isTemporaryID else { return true }
        return container.canUpdateRecord(forManagedObjectWith: object.objectID)
    }

    func isOwner(_ trip: Trip) -> Bool {
        guard let sharedStore else { return true }
        return trip.objectID.persistentStore != sharedStore
    }

    func acceptShare(_ metadata: CKShare.Metadata) {
        guard let sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error { print("Accepting share failed: \(error)") }
        }
    }
}

// MARK: - Per-device preferences

enum Prefs {
    private static let d = UserDefaults.standard

    static func me(for trip: Trip) -> String? { d.string(forKey: "me." + trip.idString) }
    static func setMe(_ key: String, for trip: Trip) { d.set(key, forKey: "me." + trip.idString) }

    static var raceKit: [String] {
        get { d.stringArray(forKey: "kit.race") ?? Starters.defaultRaceKit }
        set { d.set(newValue, forKey: "kit.race") }
    }
    static var parkKit: [String] {
        get { d.stringArray(forKey: "kit.park") ?? Starters.defaultParkKit }
        set { d.set(newValue, forKey: "kit.park") }
    }
    static var hiddenSuggestions: Set<String> {
        get { Set(d.stringArray(forKey: "hidden.suggestions") ?? []) }
        set { d.set(Array(newValue), forKey: "hidden.suggestions") }
    }
    static var lastNames: [String] {
        get { d.stringArray(forKey: "last.names") ?? [] }
        set { d.set(newValue, forKey: "last.names") }
    }
}
