//
//  Importer.swift
//  Race Day Ready
//
//  Brings in lists exported from the Race Day Ready web version (a .json file).
//  Trips that already exist on this phone are skipped, so importing twice is safe.
//

import Foundation

enum Importer {
    struct Export: Decodable {
        var people: [ExPerson]?
        var weekends: [String: ExWeekend]?
        var items: [ExItem]?
        var outfits: [ExOutfit]?
    }
    struct ExPerson: Decodable { var id: String; var name: String? }
    struct ExWeekend: Decodable {
        var travelers: [String]?
        var runs: [String: [String]]?
        var arrive: String?
        var depart: String?
    }
    struct ExItem: Decodable {
        var wk: String
        var text: String?
        var cat: String?
        var who: String?
        var qty: Int?
        var bag: String?
        var day: String?
        var outfit: String?
        var status: String?
        var note: String?
        var packed: Bool?
        var ts: Double?
    }
    struct ExOutfit: Decodable {
        var id: String
        var wk: String
        var day: String?
        var slot: String?
        var title: String?
        var theme: String?
        var ideas: String?
        var race: String?
        var event: String?
        var bag: String?
        var who: String?
        var note: String?
        var ord: Double?
    }

    struct Result { var trips = 0; var items = 0; var outfits = 0; var skipped: [String] = [] }

    @MainActor
    static func run(data: Data, feed: FeedStore, existing: [Trip]) throws -> Result {
        let export = try JSONDecoder().decode(Export.self, from: data)
        let p = Persistence.shared
        var result = Result()

        var weekendIDs = Set((export.items ?? []).map { $0.wk })
        weekendIDs.formUnion((export.outfits ?? []).map { $0.wk })
        weekendIDs.formUnion((export.weekends ?? [:]).keys)

        for wid in weekendIDs.sorted() {
            guard let def = feed.weekend(wid) else { result.skipped.append(wid); continue }
            if existing.contains(where: { $0.catalogID == wid }) { result.skipped.append(def.short); continue }

            let trip = p.newTrip()
            p.apply(def, to: trip)
            let settings = export.weekends?[wid]
            trip.arriveDay = settings?.arrive ?? def.start
            trip.departDay = settings?.depart ?? def.end

            // People keep their names; their old ids map to new ones on this trip.
            var idMap: [String: String] = [:]
            let roster = export.people ?? [ExPerson(id: "her", name: "Me")]
            for person in roster {
                let runs = settings?.runs?[person.id] ?? (person.id == roster.first?.id ? def.races.map { $0.id } : [])
                let np = p.addPerson(person.name ?? "Someone", to: trip, runs: runs)
                np.traveling = settings?.travelers?.contains(person.id) ?? true
                idMap[person.id] = np.key
            }
            func who(_ old: String?) -> String {
                switch old ?? "" {
                case "both": return Who.shared
                case "match": return Who.matching
                default: return idMap[old ?? ""] ?? trip.peopleList.first?.key ?? Who.shared
                }
            }

            var outfitMap: [String: Outfit] = [:]
            for o in (export.outfits ?? []) where o.wk == wid {
                let outfit = p.addOutfit(to: trip, day: o.day, slot: o.slot ?? "Outfit", title: o.title ?? "", theme: o.theme ?? "",
                                         ideasKey: o.ideas ?? "", raceID: o.race ?? "", eventID: o.event ?? "", who: who(o.who),
                                         bag: Bag(key: o.bag), note: o.note ?? "")
                if let ord = o.ord { outfit.sortOrder = ord }
                outfitMap[o.id] = outfit
                result.outfits += 1
            }
            for i in (export.items ?? []) where i.wk == wid {
                guard let text = i.text, !text.isEmpty else { continue }
                let item = p.addItem(to: trip, text: text, category: i.cat ?? "misc", who: who(i.who), qty: i.qty ?? 1, bag: Bag(key: i.bag),
                                     day: (i.day?.isEmpty ?? true) ? nil : i.day, outfit: i.outfit.flatMap { outfitMap[$0] },
                                     status: ItemStatus(key: i.status), note: i.note, packed: i.packed ?? false)
                if let ts = i.ts { item.createdAt = Date(timeIntervalSince1970: ts / 1000) }
                result.items += 1
            }
            if let first = trip.peopleList.first { Prefs.setMe(first.key, for: trip) }
            result.trips += 1
        }
        p.save()
        return result
    }
}
