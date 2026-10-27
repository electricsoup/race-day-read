//
//  NewTripView.swift
//  Race Day Ready
//
//  Pick a race weekend from this season's calendar, or set up your own.
//

import SwiftUI

struct NewTripView: View {
    var onCreated: (Trip) -> Void

    @EnvironmentObject private var feed: FeedStore
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "startDay", ascending: true)]) private var trips: FetchedResults<Trip>

    @State private var names: [NameEntry] = (Prefs.lastNames.isEmpty ? [""] : Prefs.lastNames).map { NameEntry(text: $0) }
    @State private var showCustom = false

    private var weekends: [WeekendDef] {
        feed.feed.weekends.filter { $0.end >= DayKey.today }.sorted { $0.start < $1.start }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($names) { $entry in
                        let first = entry.id == names.first?.id
                        HStack {
                            TextField(first ? "Your name" : "Name", text: $entry.text)
                                .textContentType(first ? .givenName : .name)
                            if names.count > 1 {
                                Button(role: .destructive) { names.removeAll { $0.id == entry.id } } label: { Image(systemName: "minus.circle.fill") }
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Remove")
                            }
                        }
                    }
                    Button { names.append(NameEntry(text: "")) } label: { Label("Add someone", systemImage: "person.badge.plus") }
                } header: {
                    Text("Who's going")
                } footer: {
                    Text("Everyone starts out running every race. You can change that on the trip.")
                }

                Section("This season") {
                    if weekends.isEmpty {
                        Text("No upcoming weekends in the calendar yet. Set up your own below.").foregroundStyle(.secondary)
                    }
                    ForEach(weekends) { def in
                        let already = trips.contains { $0.catalogID == def.id }
                        Button {
                            create(def)
                        } label: {
                            WeekendRow(def: def, already: already)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    Button { showCustom = true } label: { Label("Set up a different race weekend", systemImage: "square.and.pencil") }
                }
            }
            .navigationTitle("New race weekend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .sheet(isPresented: $showCustom) {
                CustomTripView(names: cleanNames) { trip in
                    showCustom = false
                    onCreated(trip)
                }
            }
        }
    }

    private var cleanNames: [String] {
        names.map { $0.text.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func create(_ def: WeekendDef) {
        let list = cleanNames
        if !list.isEmpty { Prefs.lastNames = list }
        let trip = Persistence.shared.createTrip(from: def, people: list)
        onCreated(trip)
    }
}

private struct WeekendRow: View {
    var def: WeekendDef
    var already: Bool
    var body: some View {
        let palette = Palette.forTheme(def.type)
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3).fill(palette.header).frame(width: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(def.short).font(.display(19)).textCase(.uppercase)
                Text(DayKey.rangeLabel(def.start, def.end)).font(.subheadline).foregroundStyle(.secondary)
                Text(def.races.map { $0.short + (($0.theme ?? "").isEmpty ? "" : " · " + ($0.theme ?? "")) }.joined(separator: "  /  "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if already {
                    Text("Already on your list — this adds another copy").font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer()
            Image(systemName: "plus.circle.fill").foregroundStyle(palette.accent).font(.title3)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

/// A race weekend that isn't in the calendar.
struct CustomTripView: View {
    var names: [String]
    var onCreated: (Trip) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var theme = "other"
    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var races: [RaceDraft] = [RaceDraft()]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name (e.g. Fall Half 2027)", text: $name)
                    Picker("Colors", selection: $theme) {
                        ForEach(Palette.themes, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    DatePicker("First day", selection: $start, displayedComponents: .date)
                    DatePicker("Last day", selection: $end, in: start..., displayedComponents: .date)
                }
                Section {
                    ForEach($races) { $race in
                        RaceDraftEditor(race: $race, start: start, end: end)
                    }
                    .onDelete { races.remove(atOffsets: $0) }
                    Button { races.append(RaceDraft(date: start)) } label: { Label("Add a race", systemImage: "plus") }
                } header: {
                    Text("Races")
                } footer: {
                    Text("Character names you type as a theme (Minnie, Goofy, Tiana…) get costume ideas in Outfits.")
                }
            }
            .navigationTitle("Your race weekend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        let p = Persistence.shared
        let trip = p.newTrip()
        let s = DayKey.key(fromLocal: start), e = DayKey.key(fromLocal: max(start, end))
        trip.name = name.trimmingCharacters(in: .whitespaces)
        trip.theme = theme
        trip.startDay = s
        trip.endDay = e
        trip.arriveDay = s
        trip.departDay = e
        trip.timeZoneID = TimeZone.current.identifier
        trip.races = races.filter { !$0.short.trimmingCharacters(in: .whitespaces).isEmpty }.map { $0.def(tripName: trip.displayName) }
        let runs = trip.races.map { $0.id }
        for n in (names.isEmpty ? ["Me"] : names) { _ = p.addPerson(n, to: trip, runs: runs) }
        p.save()
        if let me = trip.peopleList.first { Prefs.setMe(me.key, for: trip) }
        onCreated(trip)
    }
}

struct NameEntry: Identifiable, Hashable {
    let id = UUID()
    var text: String
}

struct RaceDraft: Identifiable, Hashable {
    var id = "r" + UUID().uuidString.prefix(6).lowercased()
    var short = ""
    var miles = ""
    var date = Date()
    var hasTime = false
    var time = Calendar.current.date(bySettingHour: 5, minute: 0, second: 0, of: Date()) ?? Date()
    var theme = ""

    init(date: Date = Date()) { self.date = date }

    init(_ r: RaceDef) {
        id = r.id
        short = r.short
        miles = r.dist > 0 ? milesText(r.dist) : ""
        date = DayKey.localDate(r.date)
        if let t = r.time, let d = TimeKey.date(t) { hasTime = true; time = d }
        theme = r.theme ?? ""
    }

    func def(tripName: String) -> RaceDef {
        let s = short.trimmingCharacters(in: .whitespaces)
        return RaceDef(id: id, name: tripName + " " + s, short: s, dist: Double(miles.replacingOccurrences(of: ",", with: ".")) ?? 0,
                       date: DayKey.key(fromLocal: date), time: hasTime ? TimeKey.key(time) : nil,
                       theme: theme.trimmingCharacters(in: .whitespaces), ideas: Starters.themeKey(theme))
    }
}

struct RaceDraftEditor: View {
    @Binding var race: RaceDraft
    var start: Date
    var end: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Distance (10K)", text: $race.short)
                TextField("Miles", text: $race.miles).keyboardType(.decimalPad).frame(width: 70)
            }
            DatePicker("Race day", selection: $race.date, displayedComponents: .date)
            Toggle("Start time", isOn: $race.hasTime)
            if race.hasTime {
                DatePicker("Starts", selection: $race.time, displayedComponents: .hourAndMinute)
            }
            TextField("Character theme (optional)", text: $race.theme)
        }
        .padding(.vertical, 4)
    }
}
