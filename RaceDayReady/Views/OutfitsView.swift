//
//  OutfitsView.swift
//  Race Day Ready
//
//  A card for each day of the trip. Plan as many outfits a day as you like; every piece
//  you add goes straight onto the packing list. Race days prompt for each runner's outfit.
//

import SwiftUI
import CoreData

struct OutfitsView: View {
    @ObservedObject var trip: Trip
    var meKey: String
    @FetchRequest private var outfits: FetchedResults<Outfit>
    @FetchRequest private var items: FetchedResults<PackItem>
    @EnvironmentObject private var feed: FeedStore
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    @State private var whoFilter = "all"
    @State private var editing: OutfitEditorTarget?
    @State private var editingItem: PackItem?
    @State private var deleting: Outfit?
    @State private var showKits = false
    @State private var drafts: [String: String] = [:]

    init(trip: Trip, meKey: String) {
        self.trip = trip
        self.meKey = meKey
        let pred = NSPredicate(format: "trip == %@", trip)
        _outfits = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "sortOrder", ascending: true)], predicate: pred)
        _items = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)], predicate: pred)
    }

    private var newOutfitWho: String {
        if trip.person(whoFilter) != nil { return whoFilter }
        return trip.person(meKey) != nil ? meKey : (trip.peopleList.first?.key ?? Who.shared)
    }

    private func shown(_ o: Outfit) -> Bool {
        let w = o.whoKey ?? ""
        if trip.person(whoFilter) != nil { return w == whoFilter || w == Who.shared || w == Who.matching }
        if whoFilter == Who.shared || whoFilter == Who.matching { return w == whoFilter }
        return true
    }

    private func personShown(_ key: String) -> Bool { whoFilter == "all" || whoFilter == key }

    var body: some View {
        let days = trip.days
        let visible = outfits.filter(shown)
        List {
            Section {
                HStack {
                    Menu {
                        Picker("Show outfits for", selection: $whoFilter) {
                            Text("Everyone").tag("all")
                            ForEach(trip.peopleList) { p in Text(p.displayName).tag(p.key) }
                            Text("Shared").tag(Who.shared)
                            Text("Matching").tag(Who.matching)
                        }
                    } label: {
                        Label(whoFilter == "all" ? "Everyone" : trip.whoLabel(whoFilter), systemImage: "person.crop.circle")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if canEdit {
                        Button { showKits = true } label: { Label("Outfit basics", systemImage: "bag") }
                            .buttonStyle(.bordered)
                    }
                }
                .font(.subheadline)
                if whoFilter != "all" {
                    Text("Showing \(trip.whoLabel(whoFilter))'s outfits.").font(.caption).foregroundStyle(.secondary)
                }
            }

            ForEach(days, id: \.self) { day in
                let tags = trip.tags(for: day)
                let dayOutfits = visible.filter { $0.dayKey == day }
                Section {
                    ForEach(dayOutfits) { outfit in outfitRows(outfit) }
                    prompts(day: day, tags: tags, planned: outfits.filter { $0.dayKey == day })
                    if canEdit { addOutfitMenu(day: day) }
                } header: {
                    DayHeader(day: day, tags: tags)
                }
            }

            let stray = visible.filter { !days.contains($0.dayKey ?? "") }
            if !stray.isEmpty {
                Section("Outside your travel dates") {
                    ForEach(stray) { outfit in outfitRows(outfit) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { target in
            OutfitEditor(trip: trip, outfit: target.outfit, preset: target.preset)
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(trip: trip, item: item, draft: ItemDraft(item))
        }
        .sheet(isPresented: $showKits) { KitsEditor() }
        .confirmationDialog("Delete this outfit?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { outfit in
            let count = outfit.itemList.count
            if count > 0 {
                Button("Delete outfit, keep \(count) piece\(count == 1 ? "" : "s") on the list") { removeOutfit(outfit, keepPieces: true) }
                Button("Delete outfit and its pieces", role: .destructive) { removeOutfit(outfit, keepPieces: false) }
            } else {
                Button("Delete outfit", role: .destructive) { removeOutfit(outfit, keepPieces: true) }
            }
        }
    }

    // MARK: Rows for one outfit

    @ViewBuilder
    private func outfitRows(_ outfit: Outfit) -> some View {
        let pieces = items.filter { $0.outfit == outfit }
        OutfitHeaderRow(outfit: outfit, trip: trip, pieceCount: pieces.count, packedCount: pieces.filter { $0.packed }.count,
                        shotCount: store.isPro ? outfit.shotList.count : 0,
                        onEdit: { editing = OutfitEditorTarget(outfit: outfit) },
                        onDelete: { deleting = outfit })
        ForEach(pieces) { piece in
            ItemRow(item: piece, trip: trip, showWho: false, showDay: false, showOutfit: false, onEdit: { editingItem = piece })
                .padding(.leading, 14)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if canEdit {
                        Button(role: .destructive) { removePiece(piece) } label: { Label("Delete", systemImage: "trash") }
                        Button { editingItem = piece } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                    }
                }
        }
        if canEdit {
            QuickAddRow(placeholder: "Add a piece (goes on the packing list)…", text: draftBinding(outfit.uuid?.uuidString ?? "")) { text in
                addPiece(text, to: outfit)
            }
            .padding(.leading, 14)
            let ideas = feed.costumeIdeas(for: outfit.ideasKey)
            if IdeaChipsRow.hasContent(outfit: outfit, pieces: pieces, ideas: ideas) {
            IdeaChipsRow(outfit: outfit, pieces: pieces, ideas: ideas) { text in
                addPiece(text, to: outfit)
            } addKit: { list in
                for t in list { addPiece(t, to: outfit, save: false) }
                Persistence.shared.save()
            }
            .padding(.leading, 14)
            }
        }
    }

    @ViewBuilder
    private func prompts(day: String, tags: [Trip.DayTag], planned: [Outfit]) -> some View {
        ForEach(tags) { tag in
            if let race = tag.race, tag.kind == .race {
                ForEach(trip.runners(of: race.id).filter { r in personShown(r.key) && !planned.contains { o in o.raceID == race.id && o.whoKey == r.key } }) { p in
                    promptRow(title: "Plan \(trip.peopleList.count > 1 ? p.displayName + "'s" : "your") \(race.short) outfit",
                              detail: race.theme ?? "") {
                        let o = Persistence.shared.addOutfit(to: trip, day: day, slot: "Race", title: race.name, theme: race.theme ?? "",
                                                             ideasKey: race.ideas ?? "", raceID: race.id, who: p.key)
                        if race.id == firstRaceID(for: p) { o.bag = Bag.carry.rawValue }
                        Persistence.shared.save()
                    }
                }
            }
            if let event = tag.event {
                ForEach(trip.goers(of: event).filter { g in personShown(g.key) && !planned.contains { o in o.eventID == event.id && o.whoKey == g.key } }) { p in
                    promptRow(title: "Plan \(trip.peopleList.count > 1 ? p.displayName + "'s" : "your") \(event.short) outfit",
                              detail: [event.place, event.when].compactMap { $0 }.joined(separator: ", ")) {
                        Persistence.shared.addOutfit(to: trip, day: day, slot: event.slot ?? "Party", title: event.name, eventID: event.id, who: p.key)
                        Persistence.shared.save()
                    }
                }
            }
        }
    }

    private func promptRow(title: String, detail: String, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                if !detail.isEmpty { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if canEdit {
                Button("Start it", action: action).buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .listRowBackground(palette.wash)
    }

    private func addOutfitMenu(day: String) -> some View {
        Menu {
            ForEach(Starters.slots, id: \.self) { slot in
                Button(slot) {
                    Persistence.shared.addOutfit(to: trip, day: day, slot: slot, who: newOutfitWho)
                    Persistence.shared.save()
                }
            }
            Button("Something else…") { editing = OutfitEditorTarget(outfit: nil, preset: OutfitPreset(day: day, who: newOutfitWho)) }
        } label: {
            Label("Add an outfit" + (trip.peopleList.count > 1 ? " for \(trip.whoLabel(newOutfitWho))" : ""), systemImage: "plus")
                .font(.subheadline)
        }
    }

    // MARK: Actions

    private func firstRaceID(for person: Person) -> String? {
        trip.races.filter { person.runs.contains($0.id) }.min { $0.date < $1.date }?.id
    }

    private func draftBinding(_ key: String) -> Binding<String> {
        Binding(get: { drafts[key] ?? "" }, set: { drafts[key] = $0 })
    }

    private func addPiece(_ text: String, to outfit: Outfit, save: Bool = true) {
        Persistence.shared.addItem(to: trip, text: text, category: "outfits", who: outfit.whoKey ?? newOutfitWho,
                                   bag: Bag(key: outfit.bag), day: outfit.dayKey, outfit: outfit)
        if save { Persistence.shared.save() }
    }

    private func removePiece(_ piece: PackItem) {
        let snapshot = ItemDraft(piece)
        let outfit = piece.outfit
        let name = piece.text ?? "piece"
        Persistence.shared.delete(piece)
        toasts.show("Removed \"\(name)\"", actionLabel: "Undo") { [trip] in
            snapshot.insert(into: trip, outfit: outfit)
            Persistence.shared.save()
        }
    }

    private func removeOutfit(_ outfit: Outfit, keepPieces: Bool) {
        let snapshot = OutfitSnapshot(outfit)
        let pieces = outfit.itemList
        let pieceDrafts = pieces.map { ItemDraft($0) }
        let keptIDs = pieces.map { $0.objectID }
        let title = outfit.displayTitle
        let ctx = Persistence.shared.viewContext
        if keepPieces { pieces.forEach { $0.outfit = nil } } else { pieces.forEach { ctx.delete($0) } }
        ctx.delete(outfit)
        Persistence.shared.save()
        toasts.show("Removed \(title)", actionLabel: "Undo") { [trip] in
            let restored = snapshot.insert(into: trip)
            if keepPieces {
                for id in keptIDs { (try? ctx.existingObject(with: id) as? PackItem)?.outfit = restored }
            } else {
                for d in pieceDrafts { d.insert(into: trip, outfit: restored) }
            }
            Persistence.shared.save()
        }
    }
}

// MARK: - Pieces

struct OutfitEditorTarget: Identifiable {
    let id = UUID()
    var outfit: Outfit?
    var preset: OutfitPreset? = nil
}

struct OutfitPreset {
    var day: String
    var who: String
    var slot = "Park"
}

struct OutfitSnapshot {
    var slot, title, theme, ideasKey, raceID, eventID, bag, whoKey, dayKey, note: String
    var sortOrder: Double

    init(_ o: Outfit) {
        slot = o.slot ?? "Outfit"; title = o.title ?? ""; theme = o.theme ?? ""; ideasKey = o.ideasKey ?? ""
        raceID = o.raceID ?? ""; eventID = o.eventID ?? ""; bag = o.bag ?? ""; whoKey = o.whoKey ?? Who.shared
        dayKey = o.dayKey ?? ""; note = o.note ?? ""; sortOrder = o.sortOrder
    }

    func insert(into trip: Trip) -> Outfit {
        let o = Persistence.shared.addOutfit(to: trip, day: dayKey.isEmpty ? nil : dayKey, slot: slot, title: title, theme: theme,
                                             ideasKey: ideasKey, raceID: raceID, eventID: eventID, who: whoKey, bag: Bag(key: bag), note: note)
        o.sortOrder = sortOrder
        return o
    }
}

struct DayHeader: View {
    var day: String
    var tags: [Trip.DayTag]
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Text(DayKey.format(day, "EEE").uppercased()).font(.system(size: 10, weight: .bold)).tracking(1)
                Text(DayKey.format(day, "d")).font(.display(26, weight: .heavy).monospacedDigit())
                Text(DayKey.format(day, "MMM").uppercased()).font(.system(size: 10, weight: .semibold)).tracking(1)
            }
            .foregroundStyle(palette.accent)
            .frame(width: 50)
            .padding(.vertical, 4)
            .background(palette.wash, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 5) {
                Text(DayKey.long(day)).font(.display(17)).textCase(.uppercase).foregroundStyle(.primary)
                if !tags.isEmpty {
                    FlowLayout(spacing: 5) {
                        ForEach(tags) { tag in
                            Text(tag.label)
                                .font(.system(size: 11, weight: tag.kind == .race ? .bold : .regular))
                                .textCase(nil)
                                .strikethrough(tag.kind == .raceOff)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .foregroundStyle(tag.kind == .race ? Color.white : (tag.kind == .expo || tag.kind == .event ? palette.accent : Color.secondary))
                                .background {
                                    if tag.kind == .race { RoundedRectangle(cornerRadius: 5).fill(palette.accent) }
                                    else { RoundedRectangle(cornerRadius: 5).stroke(tag.kind == .expo || tag.kind == .event ? palette.accent : Color(.separator)) }
                                }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct OutfitHeaderRow: View {
    @ObservedObject var outfit: Outfit
    var trip: Trip
    var pieceCount: Int
    var packedCount: Int
    var shotCount: Int
    var onEdit: () -> Void
    var onDelete: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text((outfit.slot ?? "Outfit").uppercased())
                    .font(.system(size: 11, weight: .heavy)).tracking(1)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(palette.wash, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(palette.accent)
                Text(outfit.displayTitle).font(.headline).lineLimit(2)
                Spacer(minLength: 4)
                if pieceCount > 0 {
                    Text("\(packedCount)/\(pieceCount)").font(.caption.monospacedDigit())
                        .foregroundStyle(packedCount == pieceCount ? palette.accent : .secondary)
                }
                Menu {
                    Button { onEdit() } label: { Label("Edit outfit", systemImage: "pencil") }
                    if canEdit { Button(role: .destructive) { onDelete() } label: { Label("Delete outfit", systemImage: "trash") } }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Outfit options")
            }
            FlowLayout(spacing: 5) {
                if trip.peopleList.count > 1 { WhoTag(whoKey: outfit.whoKey, trip: trip) }
                if Bag(key: outfit.bag) != .any { BagPill(bag: Bag(key: outfit.bag), onChange: nil) }
                if let t = outfit.theme, !t.isEmpty { InfoChip(text: t, systemImage: "sparkles") }
                if shotCount > 0 { InfoChip(text: "\(shotCount) shot\(shotCount == 1 ? "" : "s")", systemImage: "video") }
            }
            if let n = outfit.note, !n.isEmpty { Text(n).font(.caption).foregroundStyle(.secondary) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .padding(.vertical, 2)
    }
}

struct IdeaChipsRow: View {
    @ObservedObject var outfit: Outfit
    var pieces: [PackItem]
    var ideas: [String]
    var addIdea: (String) -> Void
    var addKit: ([String]) -> Void
    @Environment(\.palette) private var palette

    static func kit(for outfit: Outfit) -> [String] {
        let slot = normalized(outfit.slot)
        return slot == "race" ? Prefs.raceKit : (slot == "park" ? Prefs.parkKit : [])
    }

    static func hasContent(outfit: Outfit, pieces: [PackItem], ideas: [String]) -> Bool {
        let have = Set(pieces.map { normalized($0.text) })
        return (ideas + kit(for: outfit)).contains { !have.contains(normalized($0)) }
    }

    var body: some View {
        let have = Set(pieces.map { normalized($0.text) })
        let remaining = ideas.filter { !have.contains(normalized($0)) }
        let slot = normalized(outfit.slot)
        let kitMissing = Self.kit(for: outfit).filter { !have.contains(normalized($0)) }
        if !remaining.isEmpty || !kitMissing.isEmpty {
            FlowLayout(spacing: 6) {
                if !kitMissing.isEmpty {
                    Button {
                        addKit(kitMissing)
                    } label: {
                        Label("\(slot == "race" ? "Race bag" : "Park outfit") basics (\(kitMissing.count))", systemImage: "bag.badge.plus")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                ForEach(remaining, id: \.self) { idea in
                    Button { addIdea(idea) } label: { Text("+ " + idea).font(.caption) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(palette.accent)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
