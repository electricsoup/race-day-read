//
//  Starters.swift
//  Race Day Ready
//
//  Built-in lists: packing categories, the race-weekend essentials, outfit basics,
//  pre-trip to-dos, and fallback costume ideas for when the feed hasn't loaded.
//

import Foundation

struct StarterItem: Hashable {
    var text: String
    var cat: String
    var note: String? = nil
    var shared: Bool = false
    var bag: Bag = .any
}

struct PrepTemplate: Hashable, Identifiable {
    var id: String { title }
    var title: String
    var daysBefore: Int
    var perPerson: Bool = false
}

enum Starters {
    static let categories: [(id: String, title: String, subtitle: String)] = [
        ("race", "Race kit", "Everything that crosses the start line"),
        ("fuel", "Fuel & hydration", "Pre-race breakfast through the finish"),
        ("outfits", "Outfits & costumes", "Pieces from your outfits land here"),
        ("park", "Park days", ""),
        ("recovery", "Recovery & care", "For the miles between races"),
        ("clothes", "Clothes & sleep", ""),
        ("toiletries", "Toiletries & meds", ""),
        ("tech", "Tech & content", "Cameras, chargers, filming kit"),
        ("docs", "Documents & travel", ""),
        ("misc", "Everything else", "")
    ]
    static var categoryIDs: [String] { categories.map { $0.id } }
    static func categoryTitle(_ id: String?) -> String { categories.first { $0.id == id }?.title ?? "Everything else" }

    static let slots = ["Race", "Park", "Expo", "Travel", "Dinner", "Party", "Pool", "Sleep"]

    static let essentials: [StarterItem] = [
        StarterItem(text: "Race shoes (broken in)", cat: "race"),
        StarterItem(text: "Running socks", cat: "race", note: "One pair per race, plus a spare"),
        StarterItem(text: "Sports bras", cat: "race", note: "One per race"),
        StarterItem(text: "Running shorts or skirts", cat: "race"),
        StarterItem(text: "Race belt or safety pins for the bib", cat: "race"),
        StarterItem(text: "Hat or visor", cat: "race"),
        StarterItem(text: "Running sunglasses", cat: "race"),
        StarterItem(text: "Anti-chafe balm", cat: "race"),
        StarterItem(text: "Throwaway layer for the corral", cat: "race"),
        StarterItem(text: "Rain poncho", cat: "race"),
        StarterItem(text: "Phone running belt", cat: "race"),
        StarterItem(text: "Headphones", cat: "race", bag: .carry),
        StarterItem(text: "Energy gels or chews", cat: "fuel", note: "Count them by race distance"),
        StarterItem(text: "Electrolyte tablets", cat: "fuel"),
        StarterItem(text: "Pre-race breakfast", cat: "fuel", note: "Pack it the night before; corrals open before 4 AM"),
        StarterItem(text: "Refillable water bottle", cat: "fuel"),
        StarterItem(text: "Coffee or caffeine for 3 AM wake-ups", cat: "fuel", shared: true),
        StarterItem(text: "Compression socks or sleeves", cat: "recovery"),
        StarterItem(text: "Recovery slides", cat: "recovery"),
        StarterItem(text: "Massage gun or roller ball", cat: "recovery", shared: true),
        StarterItem(text: "KT tape", cat: "recovery", shared: true),
        StarterItem(text: "Blister kit", cat: "recovery", shared: true),
        StarterItem(text: "Zip-top bags for ice", cat: "recovery", shared: true),
        StarterItem(text: "Post-race change of clothes", cat: "clothes", note: "Fits in the clear gear-check bag from the expo"),
        StarterItem(text: "Sleepwear", cat: "clothes"),
        StarterItem(text: "Light jacket or hoodie", cat: "clothes"),
        StarterItem(text: "Swimsuit", cat: "clothes"),
        StarterItem(text: "Park ears or hat", cat: "park"),
        StarterItem(text: "Park band or tickets", cat: "park"),
        StarterItem(text: "Portable charger", cat: "park"),
        StarterItem(text: "Small park bag", cat: "park"),
        StarterItem(text: "Sunscreen", cat: "toiletries", shared: true),
        StarterItem(text: "Daily meds and vitamins", cat: "toiletries", bag: .carry),
        StarterItem(text: "Pain relief you trust", cat: "toiletries", shared: true),
        StarterItem(text: "Toiletry bag", cat: "toiletries"),
        StarterItem(text: "GPS watch + charger", cat: "tech", bag: .carry),
        StarterItem(text: "Phone charger and cable", cat: "tech", bag: .carry),
        StarterItem(text: "Camera or phone gimbal", cat: "tech"),
        StarterItem(text: "Wireless mic", cat: "tech"),
        StarterItem(text: "Photo ID for packet pickup", cat: "docs", bag: .carry),
        StarterItem(text: "Race waiver / registration confirmation", cat: "docs"),
        StarterItem(text: "Boarding passes", cat: "docs", bag: .carry),
        StarterItem(text: "Hotel confirmation", cat: "docs", shared: true),
        StarterItem(text: "Padded pouch for medals on the way home", cat: "misc"),
        StarterItem(text: "Laundry bag for sweaty race gear", cat: "misc", shared: true)
    ]

    static let defaultRaceKit = [
        "Gallon zip-top bag, labeled with the day", "Hat / visor / headband", "Sports bra / underwear", "Shirt / skirt / pants",
        "Calf sleeves / socks", "Grocery bag, folded and rubber-banded (post-race)", "Snack-size zip-top bag of meds",
        "Sports chews / salt chews", "Mylar blanket"
    ]
    static let defaultParkKit = ["Bag for the day", "Ears", "Top", "Bottom", "Park band", "Underwear / socks"]

    static let prepTemplates: [PrepTemplate] = [
        PrepTemplate(title: "Book park tickets and reservations", daysBefore: 60),
        PrepTemplate(title: "Make dining reservations", daysBefore: 60),
        PrepTemplate(title: "Confirm race registration and sign the waiver", daysBefore: 30, perPerson: true),
        PrepTemplate(title: "Book pet sitter or boarding", daysBefore: 30),
        PrepTemplate(title: "Break in race shoes (20+ miles on them)", daysBefore: 21, perPerson: true),
        PrepTemplate(title: "Finish and test-run race costumes", daysBefore: 14, perPerson: true),
        PrepTemplate(title: "Check packet pickup hours and ID rules", daysBefore: 7),
        PrepTemplate(title: "Arrange airport ride or parking", daysBefore: 7),
        PrepTemplate(title: "Check the 10-day forecast and adjust layers", daysBefore: 5),
        PrepTemplate(title: "Hold mail and package deliveries", daysBefore: 3),
        PrepTemplate(title: "Download offline maps and the park app", daysBefore: 3),
        PrepTemplate(title: "Plan expo day and any merch queue", daysBefore: 3),
        PrepTemplate(title: "Pack one labeled bag per race", daysBefore: 2, perPerson: true),
        PrepTemplate(title: "Save confirmations offline", daysBefore: 2),
        PrepTemplate(title: "Check in for the flight", daysBefore: 1, perPerson: true),
        PrepTemplate(title: "Charge watch, headphones, phone and battery packs", daysBefore: 1, perPerson: true),
        PrepTemplate(title: "Set alarms for every race morning", daysBefore: 1, perPerson: true)
    ]

    /// Fallback costume ideas when the feed is missing a theme.
    static let themeIdeas: [String: [String]] = [:]

    private static let themeKeys: [(String, String)] = [
        ("aristocat", "aristocats"), ("caballero", "caballeros"), ("poppins", "poppins"), ("grumpy", "grumpy"), ("pluto", "pluto"),
        ("chip", "chipdale"), ("daisy", "donalddaisy"), ("donald", "donalddaisy"), ("minnie", "mickeyminnie"),
        ("steamboat", "steamboat"), ("mickey", "mickeyminnie"), ("goofy", "goofy"), ("dopey", "dopey"), ("tiana", "tiana"),
        ("snow", "snowwhite"), ("jasmine", "jasmine"), ("ariel", "ariel"), ("vanellope", "ralph"), ("ralph", "ralph"),
        ("robin", "robinhood"), ("alice", "alice"), ("cheshire", "alice")
    ]

    /// Matches a typed character name to a set of costume ideas.
    static func themeKey(_ theme: String?) -> String {
        let s = normalized(theme)
        guard !s.isEmpty else { return "" }
        return themeKeys.first { s.contains($0.0) }?.1 ?? ""
    }
}
