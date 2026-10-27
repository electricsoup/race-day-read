//
//  Helpers.swift
//  Race Day Ready
//
//  Days are stored as "yyyy-MM-dd" strings so a race on Oct 25 stays on Oct 25
//  no matter which time zone the phone is in. Times are "HH:mm" strings.
//

import Foundation
import CoreData

enum DayKey {
    private static let utc = TimeZone(identifier: "UTC")!

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func date(_ key: String?) -> Date? {
        guard let key, !key.isEmpty else { return nil }
        return parser.date(from: key)
    }

    static func key(_ date: Date) -> String { parser.string(from: date) }

    /// Today's date where the phone is, as a day key.
    static var today: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// Converts a calendar date picked in the UI (local midnight) to a day key.
    static func key(fromLocal date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 2000, c.month ?? 1, c.day ?? 1)
    }

    /// The local-midnight Date for a day key, for DatePickers.
    static func localDate(_ key: String?) -> Date {
        guard let key, key.count == 10 else { return Date() }
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return Date() }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) ?? Date()
    }

    static func add(_ key: String, days: Int) -> String {
        guard let d = date(key), let n = calendar.date(byAdding: .day, value: days, to: d) else { return key }
        return Self.key(n)
    }

    static func between(_ a: String, _ b: String) -> Int {
        guard let x = date(a), let y = date(b) else { return 0 }
        return calendar.dateComponents([.day], from: x, to: y).day ?? 0
    }

    static func range(_ from: String, _ to: String, max: Int = 21) -> [String] {
        guard date(from) != nil else { return [] }
        let end = to >= from ? to : from
        var out: [String] = []
        var d = from
        while d <= end && out.count < max {
            out.append(d)
            d = add(d, days: 1)
        }
        return out
    }

    static func format(_ key: String?, _ template: String) -> String {
        guard let d = date(key) else { return "" }
        let f = DateFormatter()
        f.timeZone = utc
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(template)
        return f.string(from: d)
    }

    static func short(_ key: String?) -> String { format(key, "EEE MMM d") }
    static func long(_ key: String?) -> String { format(key, "EEEE MMMM d") }

    static func rangeLabel(_ a: String?, _ b: String?) -> String {
        guard let a, date(a) != nil else { return "" }
        guard let b, date(b) != nil, a != b else { return format(a, "MMM d yyyy") }
        if a.prefix(7) == b.prefix(7) { return format(a, "MMM d") + "–" + format(b, "d, yyyy") }
        if a.prefix(4) == b.prefix(4) { return format(a, "MMM d") + " – " + format(b, "MMM d, yyyy") }
        return format(a, "MMM d yyyy") + " – " + format(b, "MMM d yyyy")
    }
}

enum TimeKey {
    static func label(_ t: String?) -> String {
        guard let t, let d = date(t) else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }

    /// A Date today at this time, for time pickers.
    static func date(_ t: String?) -> Date? {
        guard let t else { return nil }
        let parts = t.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date())
    }

    static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}

func normalized(_ s: String?) -> String {
    (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
}

func milesText(_ n: Double) -> String {
    let r = (n * 10).rounded() / 10
    return r == r.rounded() ? String(Int(r)) : String(format: "%.1f", r)
}

func joinNames(_ list: [String]) -> String {
    if list.count <= 2 { return list.joined(separator: " & ") }
    return list.dropLast().joined(separator: ", ") + " & " + (list.last ?? "")
}

// MARK: - Whose is it

/// Items, outfits, to-dos and shots belong to one person (their uuid string),
/// to everyone ("shared"), or are matching outfits ("matching").
enum Who {
    static let shared = "shared"
    static let matching = "matching"
}

// MARK: - Item vocab

enum Bag: String, CaseIterable, Identifiable {
    case any = "", carry, checked
    var id: String { rawValue }
    var label: String {
        switch self {
        case .any: return "Any bag"
        case .carry: return "Carry-on"
        case .checked: return "Checked"
        }
    }
    var next: Bag {
        switch self {
        case .any: return .carry
        case .carry: return .checked
        case .checked: return .any
        }
    }
    init(key: String?) { self = Bag(rawValue: key ?? "") ?? .any }
}

enum ItemStatus: String, CaseIterable, Identifiable {
    case none = "", own, buy, make
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "No status"
        case .own: return "Have it"
        case .buy: return "To buy"
        case .make: return "To make"
        }
    }
    init(key: String?) { self = ItemStatus(rawValue: key ?? "") ?? .none }
}

// MARK: - Trip conveniences

private func decodeJSON<T: Decodable>(_ s: String?, type: T.Type) -> T? {
    guard let s, let data = s.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
}

private func encodeJSON<T: Encodable>(_ v: T) -> String? {
    guard let data = try? JSONEncoder().encode(v) else { return nil }
    return String(data: data, encoding: .utf8)
}

extension Trip {
    var displayName: String { name?.isEmpty == false ? name! : "Race weekend" }
    var idString: String { uuid?.uuidString ?? objectID.uriRepresentation().absoluteString }

    var races: [RaceDef] {
        get { decodeJSON(racesJSON, type: [RaceDef].self) ?? [] }
        set { racesJSON = encodeJSON(newValue) }
    }
    var challenges: [ChallengeDef] {
        get { decodeJSON(challengesJSON, type: [ChallengeDef].self) ?? [] }
        set { challengesJSON = encodeJSON(newValue) }
    }
    var events: [EventDef] {
        get { decodeJSON(eventsJSON, type: [EventDef].self) ?? [] }
        set { eventsJSON = encodeJSON(newValue) }
    }
    var extras: [ExtraDef] {
        get { decodeJSON(extrasJSON, type: [ExtraDef].self) ?? [] }
        set { extrasJSON = encodeJSON(newValue) }
    }
    var expo: [String] {
        get { (expoCSV ?? "").split(separator: ",").map(String.init) }
        set { expoCSV = newValue.joined(separator: ",") }
    }

    var arrive: String { arriveDay ?? startDay ?? DayKey.today }
    var depart: String { departDay ?? endDay ?? arrive }
    var days: [String] { DayKey.range(arrive, depart) }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID ?? "") ?? .current }

    var peopleList: [Person] {
        ((people as? Set<Person>) ?? []).sorted { ($0.sortOrder, $0.name ?? "") < ($1.sortOrder, $1.name ?? "") }
    }
    var travelers: [Person] { peopleList.filter { $0.traveling } }
    var itemList: [PackItem] { Array((items as? Set<PackItem>) ?? []) }
    var outfitList: [Outfit] {
        ((outfits as? Set<Outfit>) ?? []).sorted { ($0.dayKey ?? "", $0.sortOrder) < ($1.dayKey ?? "", $1.sortOrder) }
    }

    func person(_ key: String?) -> Person? {
        guard let key else { return nil }
        return peopleList.first { $0.uuid?.uuidString == key }
    }

    func whoLabel(_ key: String?) -> String {
        switch key ?? "" {
        case Who.shared: return "Shared"
        case Who.matching: return "Matching"
        default: return person(key)?.name ?? "Someone"
        }
    }

    /// People choices for pickers: each person, then Shared and Matching.
    var whoOptions: [(String, String)] {
        peopleList.map { ($0.key, $0.displayName) } + [(Who.shared, "Shared (everyone)"), (Who.matching, "Matching outfits")]
    }

    func runners(of raceID: String) -> [Person] { travelers.filter { $0.runs.contains(raceID) } }

    func goers(of event: EventDef) -> [Person] {
        let rs = event.forRaces ?? []
        guard !rs.isEmpty else { return [] }
        return travelers.filter { p in rs.contains { p.runs.contains($0) } }
    }

    func earners(of challenge: ChallengeDef) -> [Person] {
        travelers.filter { p in challenge.needs.allSatisfy { p.runs.contains($0) } }
    }

    func miles(for person: Person?) -> Double {
        guard let person else { return 0 }
        return races.filter { person.runs.contains($0.id) }.reduce(0) { $0 + $1.dist }
    }

    func themes() -> [(String, String)] {
        var out: [(String, String)] = []
        for r in races { if let t = r.theme, !t.isEmpty, !out.contains(where: { $0.0 == t }) { out.append((t, r.ideas ?? Starters.themeKey(t))) } }
        for c in challenges { if let t = c.theme, !t.isEmpty, !out.contains(where: { $0.0 == t }) { out.append((t, Starters.themeKey(t))) } }
        return out
    }

    struct DayTag: Identifiable {
        enum Kind { case race, raceOff, expo, event, note }
        var id: String
        var kind: Kind
        var label: String
        var race: RaceDef?
        var event: EventDef?
    }

    func tags(for day: String) -> [DayTag] {
        var out: [DayTag] = []
        let many = peopleList.count > 1
        for r in races where r.date == day {
            let who = runners(of: r.id)
            var label = r.short + (r.theme.map { " · " + $0 } ?? "")
            if let t = r.time, !who.isEmpty { label += " · " + TimeKey.label(t) + " start" }
            if many && !who.isEmpty { label += " · " + joinNames(who.map { $0.displayName }) }
            out.append(DayTag(id: "r-" + r.id, kind: who.isEmpty ? .raceOff : .race, label: label, race: r))
        }
        if expo.contains(day) { out.append(DayTag(id: "expo", kind: .expo, label: "Expo")) }
        for e in events where e.date == day {
            let label = e.short + (e.place.map { " · " + $0 } ?? "") + (e.when.map { " · " + $0 } ?? "")
            out.append(DayTag(id: "e-" + e.id, kind: .event, label: label, event: e))
        }
        if !out.contains(where: { $0.kind == .race }) {
            if day == days.first { out.append(DayTag(id: "travel", kind: .note, label: "Travel day")) }
            else if day == days.last { out.append(DayTag(id: "home", kind: .note, label: "Fly home")) }
        }
        return out
    }
}

extension Person {
    var key: String { uuid?.uuidString ?? "" }
    var displayName: String { name?.isEmpty == false ? name! : "Someone" }
    var runs: [String] {
        get { (runsCSV ?? "").split(separator: ",").map(String.init) }
        set { runsCSV = newValue.joined(separator: ",") }
    }
}

extension PackItem {
    var bagValue: Bag { get { Bag(key: bag) } set { bag = newValue.rawValue } }
    var statusValue: ItemStatus { get { ItemStatus(key: status) } set { status = newValue.rawValue } }
    var categoryKey: String { Starters.categoryIDs.contains(category ?? "") ? category! : "misc" }
    func belongs(to personKey: String) -> Bool {
        let w = whoKey ?? ""
        return w == personKey || w == Who.shared || w == Who.matching
    }
}

extension Outfit {
    var itemList: [PackItem] { ((items as? Set<PackItem>) ?? []).sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } }
    var shotList: [Shot] { ((shots as? Set<Shot>) ?? []).sorted { ($0.time ?? "99") < ($1.time ?? "99") } }
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let t = theme, !t.isEmpty { return t }
        return "Untitled outfit"
    }
    var label: String {
        var parts: [String] = []
        if let d = dayKey { parts.append(DayKey.format(d, "EEE")) }
        parts.append(slot ?? "Outfit")
        return parts.joined(separator: " · ") + " — " + displayTitle
    }
}
