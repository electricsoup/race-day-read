//
//  TripSettingsView.swift
//  Race Day Ready
//
//  Who's going and what they're running, travel dates, races, sharing.
//

import SwiftUI

struct TripSettingsView: View {
    @ObservedObject var trip: Trip
    @Binding var meKey: String
    var onDelete: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.canEdit) private var canEdit
    @EnvironmentObject private var feed: FeedStore

    @State private var name = ""
    @State private var arrive = Date()
    @State private var depart = Date()
    @State private var timeZoneID = TimeZone.current.identifier
    @State private var newPerson = ""
    @State private var confirmDelete = false
    @State private var editingRaces = false
    @State private var shareError: String?
    @State private var loaded = false

    private static let zones: [(String, String)] = [
        ("America/New_York", "Eastern"), ("America/Chicago", "Central"), ("America/Denver", "Mountain"),
        ("America/Phoenix", "Arizona"), ("America/Los_Angeles", "Pacific"), ("Pacific/Honolulu", "Hawaii"),
        ("Europe/London", "UK"), ("Europe/Paris", "Central Europe"), ("Asia/Tokyo", "Japan")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Trip name", text: $name)
                    DatePicker("Arrive", selection: $arrive, displayedComponents: .date)
                    DatePicker("Fly home", selection: $depart, in: arrive..., displayedComponents: .date)
                    Picker("Race time zone", selection: $timeZoneID) {
                        ForEach(zoneOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                } footer: {
                    Text("Outfits shows one card per day between these dates. The time zone keeps shot-list times right when you export them.")
                }

                Section {
                    ForEach(trip.peopleList) { person in
                        PersonRaces(person: person, trip: trip, isMe: person.key == meKey)
                    }
                    .onDelete(perform: deletePeople)
                    if canEdit {
                        HStack {
                            TextField("Add someone", text: $newPerson).onSubmit(addPerson)
                            Button("Add", action: addPerson).disabled(newPerson.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                } header: {
                    Text("Who's going and what they're running")
                } footer: {
                    Text("Untick every race for someone who's coming to cheer. Removing a person keeps their things on the list as Shared.")
                }

                Section {
                    Picker("This is me", selection: $meKey) {
                        ForEach(trip.peopleList) { Text($0.displayName).tag($0.key) }
                    }
                } footer: {
                    Text("Only changes this phone. The trip opens on your bib and list.")
                }

                Section {
                    Button { editingRaces = true } label: { Label("Edit races (\(trip.races.count))", systemImage: "flag.checkered") }
                    if let def = feed.weekend(trip.catalogID) {
                        Button { refresh(from: def) } label: { Label("Update from the season calendar", systemImage: "arrow.clockwise") }
                    }
                }

                if Persistence.shared.isOwner(trip) {
                    Section {
                        Button {
                            Task {
                                do { try await TripSharing.present(for: trip) }
                                catch { shareError = error.localizedDescription }
                            }
                        } label: {
                            Label(Persistence.shared.isShared(trip) ? "Manage sharing" : "Share this trip", systemImage: "person.crop.circle.badge.plus")
                        }
                    } footer: {
                        Text("People you invite see and edit the whole trip: packing list, outfits, to-dos and shot list. Pro features need Pro on their Apple ID or in your Apple family.")
                    }
                } else {
                    Section { Label("Shared with you", systemImage: "person.2.fill").foregroundStyle(.secondary) }
                }

                if Persistence.shared.isOwner(trip) {
                    Section {
                        Button("Delete this trip", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .disabled(!canEdit)
            .navigationTitle("Trip settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { saveAndClose() } }
            }
            .onAppear(perform: load)
            .sheet(isPresented: $editingRaces) { RacesEditor(trip: trip) }
            .confirmationDialog("Delete \(trip.displayName)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete trip and everything on it", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            } message: {
                Text("This removes the packing list, outfits, to-dos and shot list for everyone it's shared with.")
            }
            .alert("Couldn't share", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(shareError ?? "") }
        }
    }

    private var zoneOptions: [(String, String)] {
        var list = Self.zones
        if !list.contains(where: { $0.0 == timeZoneID }) { list.insert((timeZoneID, timeZoneID), at: 0) }
        return list
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        name = trip.name ?? ""
        arrive = DayKey.localDate(trip.arrive)
        depart = DayKey.localDate(trip.depart)
        timeZoneID = trip.timeZoneID ?? TimeZone.current.identifier
    }

    private func saveAndClose() {
        if canEdit && !trip.isDeleted {
            let a = DayKey.key(fromLocal: arrive)
            var d = DayKey.key(fromLocal: depart)
            if d < a { d = a }
            if DayKey.between(a, d) > 20 { d = DayKey.add(a, days: 20) }
            if !name.trimmingCharacters(in: .whitespaces).isEmpty { trip.name = name.trimmingCharacters(in: .whitespaces) }
            trip.arriveDay = a
            trip.departDay = d
            trip.timeZoneID = timeZoneID
            Persistence.shared.save()
        }
        dismiss()
    }

    private func addPerson() {
        let n = newPerson.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        _ = Persistence.shared.addPerson(n, to: trip, runs: [])
        Persistence.shared.save()
        newPerson = ""
    }

    private func deletePeople(at offsets: IndexSet) {
        let list = trip.peopleList
        for i in offsets {
            let person = list[i]
            let key = person.key
            for item in trip.itemList where item.whoKey == key { item.whoKey = Who.shared }
            for o in trip.outfitList where o.whoKey == key { o.whoKey = Who.shared }
            for t in ((trip.tasks as? Set<PrepTask>) ?? []) where t.whoKey == key { t.whoKey = Who.shared }
            for s in ((trip.shots as? Set<Shot>) ?? []) where s.whoKey == key { s.whoKey = Who.shared }
            Persistence.shared.viewContext.delete(person)
        }
        Persistence.shared.save()
    }

    private func refresh(from def: WeekendDef) {
        let tagline = def.tagline, climate = def.climate
        trip.races = def.races
        trip.challenges = def.challenges ?? []
        trip.events = def.events ?? []
        trip.extras = def.extras ?? []
        trip.expo = def.expo ?? []
        trip.tagline = tagline
        trip.climate = climate
        let ids = Set(def.races.map { $0.id })
        for p in trip.peopleList { p.runs = p.runs.filter { ids.contains($0) } }
        Persistence.shared.save()
    }
}

private struct PersonRaces: View {
    @ObservedObject var person: Person
    var trip: Trip
    var isMe: Bool
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Name", text: $name)
                    .font(.headline)
                    .onSubmit(commitName)
                    .onChange(of: name) { _, _ in commitName() }
                if isMe { Text("You").font(.caption.bold()).foregroundStyle(.secondary) }
            }
            Toggle("On this trip", isOn: Binding(get: { person.traveling }, set: { person.traveling = $0; Persistence.shared.save() }))
                .font(.subheadline)
            if person.traveling {
                ForEach(trip.races) { race in
                    Toggle(isOn: Binding(get: { person.runs.contains(race.id) }, set: { on in
                        var runs = person.runs
                        if on { runs.append(race.id) } else { runs.removeAll { $0 == race.id } }
                        person.runs = trip.races.map { $0.id }.filter { runs.contains($0) }
                        Persistence.shared.save()
                    })) {
                        Text("\(race.short) · \(DayKey.short(race.date))" + ((race.theme ?? "").isEmpty ? "" : " · \(race.theme ?? "")"))
                            .font(.subheadline)
                    }
                    .padding(.leading, 12)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear { name = person.name ?? "" }
    }

    private func commitName() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, n != person.name else { return }
        person.name = n
        Persistence.shared.save()
    }
}

struct RacesEditor: View {
    @ObservedObject var trip: Trip
    @Environment(\.dismiss) private var dismiss
    @State private var races: [RaceDraft] = []
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                ForEach($races) { $race in
                    Section { RaceDraftEditor(race: $race, start: DayKey.localDate(trip.arrive), end: DayKey.localDate(trip.depart)) }
                }
                .onDelete { races.remove(atOffsets: $0) }
                Section {
                    Button { races.append(RaceDraft(date: DayKey.localDate(trip.arrive))) } label: { Label("Add a race", systemImage: "plus") }
                }
            }
            .navigationTitle("Races")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                races = trip.races.map { RaceDraft($0) }
            }
        }
    }

    private func save() {
        let old = trip.races
        let defs = races.filter { !$0.short.trimmingCharacters(in: .whitespaces).isEmpty }.map { draft -> RaceDef in
            var def = draft.def(tripName: trip.displayName)
            if let previous = old.first(where: { $0.id == def.id }) {
                def.name = previous.name
                if def.ideas?.isEmpty ?? true { def.ideas = previous.ideas }
            }
            return def
        }
        trip.races = defs
        let ids = Set(defs.map { $0.id })
        for p in trip.peopleList { p.runs = p.runs.filter { ids.contains($0) } }
        Persistence.shared.save()
        dismiss()
    }
}
