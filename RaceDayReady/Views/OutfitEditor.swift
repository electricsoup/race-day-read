//
//  OutfitEditor.swift
//  Race Day Ready
//

import SwiftUI

struct OutfitEditor: View {
    @ObservedObject var trip: Trip
    var outfit: Outfit?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.canEdit) private var canEdit

    @State private var slot: String
    @State private var customSlot: String
    @State private var title: String
    @State private var theme: String
    @State private var customTheme: String
    @State private var day: String
    @State private var who: String
    @State private var bag: Bag
    @State private var note: String

    private static let otherTag = "__other"

    init(trip: Trip, outfit: Outfit?, preset: OutfitPreset? = nil) {
        self.trip = trip
        self.outfit = outfit
        let s = outfit?.slot ?? preset?.slot ?? "Park"
        let isPreset = Starters.slots.contains(s)
        _slot = State(initialValue: isPreset ? s : Self.otherTag)
        _customSlot = State(initialValue: isPreset ? "" : s)
        _title = State(initialValue: outfit?.title ?? "")
        let t = outfit?.theme ?? ""
        let known = trip.themes().contains { $0.0 == t }
        _theme = State(initialValue: t.isEmpty ? "" : (known ? t : Self.otherTag))
        _customTheme = State(initialValue: known ? "" : t)
        _day = State(initialValue: outfit?.dayKey ?? preset?.day ?? (trip.days.first ?? ""))
        _who = State(initialValue: outfit?.whoKey ?? preset?.who ?? (trip.peopleList.first?.key ?? Who.shared))
        _bag = State(initialValue: Bag(key: outfit?.bag))
        _note = State(initialValue: outfit?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("What it's for", selection: $slot) {
                        ForEach(Starters.slots, id: \.self) { Text($0).tag($0) }
                        Text("Something else…").tag(Self.otherTag)
                    }
                    if slot == Self.otherTag {
                        TextField("e.g. Character breakfast", text: $customSlot)
                    }
                    TextField("Name (e.g. Mary Poppins half costume)", text: $title)
                }
                Section {
                    Picker("Theme", selection: $theme) {
                        Text("No theme").tag("")
                        ForEach(trip.themes(), id: \.0) { Text($0.0).tag($0.0) }
                        Text("Another character…").tag(Self.otherTag)
                    }
                    if theme == Self.otherTag {
                        TextField("Character", text: $customTheme)
                    }
                } footer: {
                    Text("Themes with costume ideas show suggestion chips under the outfit.")
                }
                Section {
                    Picker("Day", selection: $day) {
                        Text("No day").tag("")
                        ForEach(trip.days, id: \.self) { Text(DayKey.short($0)).tag($0) }
                    }
                    Picker("Who wears it", selection: $who) {
                        ForEach(trip.whoOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Packed in", selection: $bag) {
                        ForEach(Bag.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if let outfit, !outfit.itemList.isEmpty {
                        Text("Changing the day, who wears it or the bag updates its \(outfit.itemList.count) piece\(outfit.itemList.count == 1 ? "" : "s") too.")
                    }
                }
                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                }
            }
            .disabled(!canEdit)
            .navigationTitle(outfit == nil ? "Plan an outfit" : "Edit outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(outfit == nil ? "Add" : "Save") { save() }.disabled(!canEdit) }
            }
        }
    }

    private func save() {
        let finalSlot = slot == Self.otherTag ? (customSlot.trimmingCharacters(in: .whitespaces).isEmpty ? "Outfit" : customSlot.trimmingCharacters(in: .whitespaces)) : slot
        let finalTheme = theme == Self.otherTag ? customTheme.trimmingCharacters(in: .whitespaces) : theme
        let ideasKey = trip.themes().first { $0.0 == finalTheme }?.1 ?? Starters.themeKey(finalTheme)
        let p = Persistence.shared
        if let outfit {
            let oldBag = Bag(key: outfit.bag)
            for piece in outfit.itemList {
                if piece.dayKey != day { piece.dayKey = day.isEmpty ? nil : day }
                if piece.whoKey != who { piece.whoKey = who }
                if oldBag != bag && piece.bagValue != bag { piece.bagValue = bag }
            }
            outfit.slot = finalSlot
            outfit.title = title
            outfit.theme = finalTheme
            outfit.ideasKey = ideasKey
            outfit.dayKey = day.isEmpty ? nil : day
            outfit.whoKey = who
            outfit.bag = bag.rawValue
            outfit.note = note
        } else {
            p.addOutfit(to: trip, day: day.isEmpty ? nil : day, slot: finalSlot, title: title, theme: finalTheme, ideasKey: ideasKey,
                        who: who, bag: bag, note: note)
        }
        p.save()
        dismiss()
    }
}

/// What goes into every race-day bag and park outfit, one item per line.
struct KitsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var race = Prefs.raceKit.joined(separator: "\n")
    @State private var park = Prefs.parkKit.joined(separator: "\n")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $race).frame(minHeight: 180)
                } header: {
                    Text("Every race-day bag")
                } footer: {
                    Text("One item per line. Race outfits get a button that adds whatever they're still missing.")
                }
                Section("Every park outfit") {
                    TextEditor(text: $park).frame(minHeight: 130)
                }
                Section {
                    Button("Reset to the original lists") {
                        race = Starters.defaultRaceKit.joined(separator: "\n")
                        park = Starters.defaultParkKit.joined(separator: "\n")
                    }
                }
            }
            .navigationTitle("Outfit basics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Prefs.raceKit = lines(race)
                        Prefs.parkKit = lines(park)
                        dismiss()
                    }
                }
            }
        }
    }

    private func lines(_ s: String) -> [String] {
        s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
