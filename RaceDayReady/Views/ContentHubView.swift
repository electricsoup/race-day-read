//
//  ContentHubView.swift
//  Race Day Ready
//
//  Pro: trend-based content ideas for this weekend, and a shot list for each day that
//  ties every shot to the outfit you'll be wearing. Export the shot list to your calendar.
//

import SwiftUI
import CoreData

struct ContentHubView: View {
    @ObservedObject var trip: Trip
    var meKey: String
    @EnvironmentObject private var store: StoreManager

    enum Mode: String, CaseIterable, Identifiable {
        case ideas = "Ideas", shots = "Shot list"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .ideas

    var body: some View {
        if store.isPro {
            VStack(spacing: 0) {
                Picker("Show", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                switch mode {
                case .ideas: IdeasView(trip: trip, meKey: meKey, openShots: { mode = .shots })
                case .shots: ShotListView(trip: trip, meKey: meKey)
                }
            }
            .background(Color(.systemGroupedBackground))
        } else {
            UpgradeView(compact: false)
        }
    }
}

// MARK: - Ideas

struct IdeasView: View {
    @ObservedObject var trip: Trip
    var meKey: String
    var openShots: () -> Void
    @EnvironmentObject private var feed: FeedStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.palette) private var palette
    @FetchRequest private var shots: FetchedResults<Shot>

    @State private var platform = "all"
    @State private var kind = "all"
    @State private var adding: ShotEditorTarget?

    init(trip: Trip, meKey: String, openShots: @escaping () -> Void) {
        self.trip = trip
        self.meKey = meKey
        self.openShots = openShots
        _shots = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: NSPredicate(format: "trip == %@", trip))
    }

    private var ideas: [IdeaDef] {
        feed.ideas(for: trip.theme).filter { idea in
            (platform == "all" || (idea.platforms ?? []).contains(platform)) && (kind == "all" || idea.kind == kind)
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Menu {
                            Picker("Platform", selection: $platform) {
                                Text("All platforms").tag("all")
                                ForEach(Platform.all, id: \.0) { Text($0.1).tag($0.0) }
                            }
                        } label: { Label(platform == "all" ? "All platforms" : Platform.label(platform), systemImage: "play.rectangle") }
                        .buttonStyle(.bordered)
                        Menu {
                            Picker("Kind", selection: $kind) {
                                Text("Everything").tag("all")
                                Text("Trending now").tag("trend")
                                Text("Race weekend").tag("race")
                                Text("Park & travel").tag("park")
                                Text("After the trip").tag("post")
                            }
                        } label: { Label(kind == "all" ? "Everything" : IdeaDef(id: "", kind: kind, title: "").kindLabel, systemImage: "sparkles") }
                        .buttonStyle(.bordered)
                    }
                    .font(.subheadline)
                    HStack(spacing: 4) {
                        if feed.isRefreshing { ProgressView().controlSize(.mini) }
                        Text(feed.feed.updated.isEmpty ? "Ideas built in" : "Ideas updated \(DayKey.format(feed.feed.updated, "MMM d"))")
                        Button("Check for new") { Task { await feed.refresh() } }.buttonStyle(.borderless)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    if let note = feed.feed.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                }
            }
            if ideas.isEmpty {
                Text("No ideas match these filters.").foregroundStyle(.secondary)
            }
            ForEach(ideas) { idea in
                IdeaCard(idea: idea, added: shots.contains { $0.ideaID == idea.id }) {
                    adding = ShotEditorTarget(shot: nil, idea: idea, day: suggestedDay(for: idea))
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable { await feed.refresh() }
        .sheet(item: $adding) { target in
            ShotEditor(trip: trip, shot: nil, idea: target.idea, day: target.day, defaultWho: trip.person(meKey) != nil ? meKey : Who.shared) {
                toasts.show("Added to your shot list", actionLabel: "View") { openShots() }
            }
        }
    }

    /// Puts race-morning ideas on the first race day, travel ideas on day one, and so on.
    private func suggestedDay(for idea: IdeaDef) -> String {
        let days = trip.days
        let me = trip.person(meKey)
        let myRaces = trip.races.filter { me?.runs.contains($0.id) ?? true }.sorted { $0.date < $1.date }
        switch idea.when ?? "" {
        case "racemorning", "raceday": return myRaces.first?.date ?? days.first ?? ""
        case "night": return myRaces.first.map { DayKey.add($0.date, days: -1) } ?? days.first ?? ""
        case "expo": return trip.expo.first ?? days.first ?? ""
        case "party": return trip.events.first?.date ?? days.last ?? ""
        case "travel": return days.first ?? ""
        case "post": return days.last ?? ""
        case "park": return days.first { d in !trip.races.contains { $0.date == d } } ?? days.first ?? ""
        default: return days.first ?? ""
        }
    }
}

struct IdeaCard: View {
    var idea: IdeaDef
    var added: Bool
    var onAdd: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Tag(text: idea.kindLabel, fg: palette.accent, bg: palette.wash)
                InfoChip(text: idea.whenLabel, systemImage: "clock")
                Spacer()
                Text((idea.platforms ?? []).map { Platform.label($0) }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Text(idea.title).font(.headline)
            if let hook = idea.hook, !hook.isEmpty {
                Text("“\(hook)”").font(.subheadline).italic()
            }
            if let sound = idea.sound, !sound.isEmpty {
                Label(sound, systemImage: "music.note").font(.caption).foregroundStyle(.secondary)
            }
            if let how = idea.how, !how.isEmpty {
                Text(how).font(.callout).foregroundStyle(.secondary)
            }
            HStack {
                if added {
                    Label("On your shot list", systemImage: "checkmark.circle.fill").font(.caption.bold()).foregroundStyle(palette.accent)
                }
                Spacer()
                if canEdit {
                    Button(added ? "Add again" : "Add to shot list", action: onAdd)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Shot list

struct ShotEditorTarget: Identifiable {
    let id = UUID()
    var shot: Shot?
    var idea: IdeaDef?
    var day: String
}

struct ShotListView: View {
    @ObservedObject var trip: Trip
    var meKey: String
    @FetchRequest private var shots: FetchedResults<Shot>
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    @State private var editing: ShotEditorTarget?
    @State private var exportFile: ExportFile?
    @State private var exportError: String?
    @State private var whoFilter = "all"

    init(trip: Trip, meKey: String) {
        self.trip = trip
        self.meKey = meKey
        _shots = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "time", ascending: true), NSSortDescriptor(key: "createdAt", ascending: true)],
                              predicate: NSPredicate(format: "trip == %@", trip))
    }

    private func shown(_ s: Shot) -> Bool {
        let w = s.whoKey ?? Who.shared
        return whoFilter == "all" || w == whoFilter || w == Who.shared
    }

    var body: some View {
        let days = trip.days
        let visible = shots.filter(shown)
        let filmed = visible.filter { $0.filmed }.count
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(visible.isEmpty ? "Add shots from Ideas, or plan your own for any day." : "\(filmed) of \(visible.count) filmed")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    HStack {
                        if trip.peopleList.count > 1 {
                            Menu {
                                Picker("Whose shots", selection: $whoFilter) {
                                    Text("Everyone").tag("all")
                                    ForEach(trip.peopleList) { Text($0.displayName).tag($0.key) }
                                }
                            } label: { Label(whoFilter == "all" ? "Everyone" : trip.whoLabel(whoFilter), systemImage: "person.crop.circle") }
                            .buttonStyle(.bordered)
                        }
                        Spacer()
                        Menu {
                            Button { export(visible, suffix: "") } label: { Label("Whole trip", systemImage: "calendar") }
                            Button { export(visible.filter { !$0.filmed }, suffix: "-to-film") } label: { Label("Only shots not filmed yet", systemImage: "video.badge.plus") }
                            Divider()
                            ForEach(days, id: \.self) { d in
                                Button(DayKey.short(d)) { export(visible.filter { $0.dayKey == d }, suffix: "-" + d) }
                            }
                        } label: {
                            Label("Export to Calendar", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(visible.isEmpty)
                    }
                    .font(.subheadline)
                }
            }

            ForEach(days, id: \.self) { day in
                let list = visible.filter { $0.dayKey == day }
                let outfits = trip.outfitList.filter { $0.dayKey == day }
                Section {
                    ForEach(list) { shot in
                        ShotRow(shot: shot, trip: trip) { editing = ShotEditorTarget(shot: shot, idea: nil, day: day) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if canEdit {
                                    Button(role: .destructive) { remove(shot) } label: { Label("Delete", systemImage: "trash") }
                                    Button { editing = ShotEditorTarget(shot: shot, idea: nil, day: day) } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                                }
                            }
                            .swipeActions(edge: .leading) {
                                if canEdit {
                                    Button {
                                        shot.filmed.toggle()
                                        Persistence.shared.save()
                                    } label: { Label(shot.filmed ? "Not filmed" : "Filmed", systemImage: "checkmark") }
                                    .tint(palette.accent)
                                }
                            }
                    }
                    if list.isEmpty && !outfits.isEmpty {
                        Text("Wearing: " + outfits.map { "\($0.slot ?? "Outfit") (\($0.displayTitle))" }.joined(separator: ", "))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if canEdit {
                        Button { editing = ShotEditorTarget(shot: nil, idea: nil, day: day) } label: { Label("Add a shot", systemImage: "plus") }
                            .font(.subheadline)
                    }
                } header: {
                    DayHeader(day: day, tags: trip.tags(for: day))
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { target in
            ShotEditor(trip: trip, shot: target.shot, idea: target.idea, day: target.day, defaultWho: trip.person(meKey) != nil ? meKey : Who.shared)
        }
        .sheet(item: $exportFile) { file in
            ActivityView(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    private func export(_ list: [Shot], suffix: String) {
        guard !list.isEmpty else {
            exportError = "There are no shots to export for that choice."
            return
        }
        do { exportFile = ExportFile(url: try ICSExporter.exportFile(trip: trip, shots: list, suffix: suffix)) }
        catch { exportError = "The calendar file couldn't be created. Try again." }
    }

    private func remove(_ shot: Shot) {
        let snapshot = ShotSnapshot(shot)
        let title = shot.title ?? "shot"
        Persistence.shared.delete(shot)
        toasts.show("Removed \"\(title)\"", actionLabel: "Undo") { [trip] in
            snapshot.insert(into: trip)
            Persistence.shared.save()
        }
    }
}

struct ShotSnapshot {
    var title, hook, sound, howTo, location, dayKey, time, platform, ideaID, whoKey, note: String?
    var durationMin: Int16
    var filmed: Bool
    var outfit: Outfit?

    init(_ s: Shot) {
        title = s.title; hook = s.hook; sound = s.sound; howTo = s.howTo; location = s.location; dayKey = s.dayKey; time = s.time
        platform = s.platform; ideaID = s.ideaID; whoKey = s.whoKey; note = s.note; durationMin = s.durationMin; filmed = s.filmed; outfit = s.outfit
    }

    func insert(into trip: Trip) {
        let s = Persistence.shared.addShot(to: trip, title: title ?? "Shot", day: dayKey, time: time, outfit: outfit, who: whoKey ?? Who.shared)
        s.hook = hook; s.sound = sound; s.howTo = howTo; s.location = location; s.platform = platform; s.ideaID = ideaID
        s.note = note; s.durationMin = durationMin; s.filmed = filmed
    }
}

struct ShotRow: View {
    @ObservedObject var shot: Shot
    var trip: Trip
    var onEdit: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                shot.filmed.toggle()
                Persistence.shared.save()
            } label: {
                Image(systemName: shot.filmed ? "checkmark.circle.fill" : "video.circle")
                    .font(.title3)
                    .foregroundStyle(shot.filmed ? palette.accent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canEdit)
            .accessibilityLabel(shot.filmed ? "Filmed" : "Not filmed yet")

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(shot.time.map { TimeKey.label($0) } ?? "Any time")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(palette.accent)
                    Text(shot.title ?? "Shot").strikethrough(shot.filmed).foregroundStyle(shot.filmed ? .secondary : .primary)
                }
                if let hook = shot.hook, !hook.isEmpty { Text("“\(hook)”").font(.caption).italic().foregroundStyle(.secondary).lineLimit(2) }
                FlowLayout(spacing: 5) {
                    if let o = shot.outfit { InfoChip(text: (o.slot ?? "Outfit") + ": " + o.displayTitle, systemImage: "tshirt") }
                    if let loc = shot.location, !loc.isEmpty { InfoChip(text: loc, systemImage: "mappin") }
                    if let w = shot.whoKey, w != Who.shared, trip.person(w) != nil { WhoTag(whoKey: w, trip: trip) }
                    if let p = shot.platform, !p.isEmpty { InfoChip(text: Platform.label(p)) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)
        }
    }
}

struct ShotEditor: View {
    @ObservedObject var trip: Trip
    var shot: Shot?
    var idea: IdeaDef?
    var day: String
    var defaultWho: String
    var onAdded: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @Environment(\.canEdit) private var canEdit

    @State private var title = ""
    @State private var dayKey = ""
    @State private var hasTime = false
    @State private var time = Date()
    @State private var duration = 15
    @State private var location = ""
    @State private var outfitKey = ""
    @State private var who = Who.shared
    @State private var platform = ""
    @State private var hook = ""
    @State private var sound = ""
    @State private var howTo = ""
    @State private var note = ""
    @State private var filmed = false
    @State private var loaded = false

    private var dayOutfits: [Outfit] { trip.outfitList.filter { $0.dayKey == dayKey } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What you're filming", text: $title, axis: .vertical)
                    Picker("Day", selection: $dayKey) {
                        ForEach(trip.days, id: \.self) { Text(DayKey.short($0)).tag($0) }
                    }
                    Toggle("Set a time", isOn: $hasTime)
                    if hasTime {
                        DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        Stepper("Takes about \(duration) min", value: $duration, in: 5...120, step: 5)
                    }
                    TextField("Where (e.g. corral, castle, hotel room)", text: $location)
                } footer: {
                    if hasTime { Text("Times are in the trip's time zone (\(trip.timeZone.localizedName(for: .shortGeneric, locale: .current) ?? trip.timeZone.identifier)), so calendar events land at the right hour wherever you open them.") }
                }

                Section {
                    Picker("Outfit", selection: $outfitKey) {
                        Text("No outfit").tag("")
                        ForEach(dayOutfits) { o in Text("\(o.slot ?? "Outfit") · \(o.displayTitle)" + (trip.peopleList.count > 1 ? " (\(trip.whoLabel(o.whoKey)))" : "")).tag(o.uuid?.uuidString ?? "") }
                    }
                    if let o = dayOutfits.first(where: { $0.uuid?.uuidString == outfitKey }), !o.itemList.isEmpty {
                        Text(o.itemList.compactMap { $0.text }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
                    }
                    Picker("Who's on camera", selection: $who) {
                        ForEach(trip.peopleList) { Text($0.displayName).tag($0.key) }
                        Text("Everyone").tag(Who.shared)
                    }
                    Picker("Posting to", selection: $platform) {
                        Text("Not sure yet").tag("")
                        ForEach(Platform.all, id: \.0) { Text($0.1).tag($0.0) }
                    }
                } header: {
                    Text("Outfit & people")
                } footer: {
                    if dayOutfits.isEmpty { Text("Plan outfits for this day in the Outfits tab and you can match shots to them here.") }
                }

                Section("Script") {
                    TextField("Hook / on-screen text", text: $hook, axis: .vertical)
                    TextField("Sound", text: $sound, axis: .vertical)
                    TextField("How to film it", text: $howTo, axis: .vertical)
                    TextField("Note", text: $note, axis: .vertical)
                }

                if shot != nil {
                    Section { Toggle("Filmed", isOn: $filmed) }
                }
            }
            .disabled(!canEdit)
            .navigationTitle(shot == nil ? "Add a shot" : "Edit shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(shot == nil ? "Add" : "Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || !canEdit)
                }
            }
            .onAppear(perform: load)
            .onChange(of: dayKey) { _, _ in
                if !dayOutfits.contains(where: { $0.uuid?.uuidString == outfitKey }) { outfitKey = "" }
            }
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let shot {
            title = shot.title ?? ""
            dayKey = shot.dayKey ?? day
            if let t = shot.time, let d = TimeKey.date(t) { hasTime = true; time = d }
            duration = Int(shot.durationMin == 0 ? 15 : shot.durationMin)
            location = shot.location ?? ""
            outfitKey = shot.outfit?.uuid?.uuidString ?? ""
            who = shot.whoKey ?? Who.shared
            platform = shot.platform ?? ""
            hook = shot.hook ?? ""
            sound = shot.sound ?? ""
            howTo = shot.howTo ?? ""
            note = shot.note ?? ""
            filmed = shot.filmed
        } else {
            dayKey = trip.days.contains(day) ? day : (trip.days.first ?? day)
            who = defaultWho
            if let idea {
                title = idea.title
                hook = idea.hook ?? ""
                sound = idea.sound ?? ""
                howTo = idea.how ?? ""
                platform = idea.platforms?.first ?? ""
            }
            // Default to the outfit this person wears that day, if there's exactly one.
            let mine = trip.outfitList.filter { $0.dayKey == dayKey && ($0.whoKey == who || $0.whoKey == Who.matching) }
            if mine.count == 1 { outfitKey = mine[0].uuid?.uuidString ?? "" }
            if idea?.when == "racemorning", let race = trip.races.first(where: { $0.date == dayKey }), let t = race.time,
               let start = TimeKey.date(t) {
                hasTime = true
                time = start.addingTimeInterval(-45 * 60)
            }
        }
    }

    private func save() {
        let p = Persistence.shared
        let outfit = trip.outfitList.first { $0.uuid?.uuidString == outfitKey }
        let target = shot ?? p.addShot(to: trip, title: title, day: dayKey, idea: idea)
        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dayKey = dayKey
        target.time = hasTime ? TimeKey.key(time) : nil
        target.durationMin = Int16(duration)
        target.location = location
        target.outfit = outfit
        target.whoKey = who
        target.platform = platform
        target.hook = hook
        target.sound = sound
        target.howTo = howTo
        target.note = note
        target.filmed = filmed
        p.save()
        let wasNew = shot == nil
        dismiss()
        if wasNew { onAdded?() }
    }
}
