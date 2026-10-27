//
//  PackView.swift
//  Race Day Ready
//
//  The packing list, grouped by category. Each item has its own quantity, bag and owner.
//  Tap an item to edit it, swipe left to delete (with Undo), swipe right to check it off.
//

import SwiftUI
import CoreData

struct PackView: View {
    @ObservedObject var trip: Trip
    @Binding var meKey: String
    @FetchRequest private var items: FetchedResults<PackItem>
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    @State private var whoFilter = "all"
    @State private var bagFilter = "all"
    @State private var hidePacked = false
    @State private var search = ""
    @State private var editing: PackItem?
    @State private var adding: ItemDraft?
    @State private var showSuggestions = false
    @State private var drafts: [String: String] = [:]
    @State private var collapsed: Set<String> = []

    init(trip: Trip, meKey: Binding<String>) {
        self.trip = trip
        _meKey = meKey
        _items = FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)],
                              predicate: NSPredicate(format: "trip == %@", trip))
    }

    private var defaultWho: String {
        if trip.person(whoFilter) != nil { return whoFilter }
        if whoFilter == Who.shared || whoFilter == Who.matching { return whoFilter }
        return trip.person(meKey) != nil ? meKey : (trip.peopleList.first?.key ?? Who.shared)
    }

    private func matches(_ item: PackItem, ignorePacked: Bool = false) -> Bool {
        let w = item.whoKey ?? ""
        if trip.person(whoFilter) != nil && !item.belongs(to: whoFilter) { return false }
        if (whoFilter == Who.shared || whoFilter == Who.matching) && w != whoFilter { return false }
        if bagFilter != "all" && (item.bag ?? "") != bagFilter { return false }
        if !ignorePacked && hidePacked && item.packed { return false }
        if !search.isEmpty {
            let hay = ((item.text ?? "") + " " + (item.note ?? "")).lowercased()
            if !hay.contains(search.lowercased()) { return false }
        }
        return true
    }

    private var anyFilter: Bool { whoFilter != "all" || bagFilter != "all" || hidePacked || !search.isEmpty }

    var body: some View {
        let shown = items.filter { matches($0, ignorePacked: true) }
        let packedCount = shown.filter { $0.packed }.count
        let meHasItems = items.contains { ($0.whoKey ?? "") == meKey }

        List {
            Section {
                TripHeader(trip: trip, meKey: meKey)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: Double(packedCount), total: Double(max(shown.count, 1))).tint(palette.accent)
                    Text(progressLabel(shown: shown, packed: packedCount)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    HStack(spacing: 10) {
                        filterMenu
                        Button { showSuggestions = true } label: { IconText("Suggest", "sparkles") }
                            .buttonStyle(.bordered)
                        Spacer(minLength: 0)
                        if canEdit {
                            Button { adding = ItemDraft(who: defaultWho) } label: { IconText("Add", "plus").bold() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .font(.subheadline)
                    SearchField(text: $search, prompt: "Search this weekend")
                }
                .padding(.vertical, 2)
            }

            if canEdit && (items.isEmpty || (!meHasItems && trip.person(meKey) != nil)) {
                Section { StartPanel(trip: trip, personKey: trip.person(meKey) != nil ? meKey : defaultWho, empty: items.isEmpty) }
            }

            if !items.isEmpty {
                ForEach(Starters.categories, id: \.id) { cat in
                    categorySection(id: cat.id, title: cat.title, shown: shown)
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(item: $editing) { item in
            ItemEditor(trip: trip, item: item, draft: ItemDraft(item))
        }
        .sheet(item: $adding) { draft in
            ItemEditor(trip: trip, item: nil, draft: draft)
        }
        .sheet(isPresented: $showSuggestions) {
            SuggestionsView(trip: trip, personKey: trip.person(whoFilter) != nil ? whoFilter : meKey)
                .environment(\.palette, palette)
        }
    }


    @ViewBuilder
    private func categorySection(id: String, title: String, shown: [PackItem]) -> some View {
        let all = shown.filter { $0.categoryKey == id }
        let list = sortedForList(all.filter { matches($0) })
        if !(anyFilter && list.isEmpty) {
            Section {
                if !collapsed.contains(id) {
                    ForEach(list) { item in row(item) }
                    if canEdit {
                        QuickAddRow(placeholder: "Add to \(title)…", text: draftBinding(id)) { text in
                            Persistence.shared.addItem(to: trip, text: text, category: id, who: defaultWho)
                            Persistence.shared.save()
                        }
                    }
                }
            } header: {
                sectionHeader(id: id, title: title, all: all)
            }
        }
    }

    private func sortedForList(_ list: [PackItem]) -> [PackItem] {
        list.sorted { a, b in
            if a.packed != b.packed { return !a.packed }
            return (a.createdAt ?? .distantPast) < (b.createdAt ?? .distantPast)
        }
    }

    private func sectionHeader(id: String, title: String, all: [PackItem]) -> some View {
        let done = all.filter { $0.packed }.count
        let complete = !all.isEmpty && done == all.count
        return Button {
            if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(all.isEmpty ? "" : "\(done)/\(all.count)")
                    .monospacedDigit()
                    .foregroundStyle(complete ? palette.accent : Color.secondary)
                Image(systemName: collapsed.contains(id) ? "chevron.right" : "chevron.down").font(.caption)
            }
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: PackItem) -> some View {
        ItemRow(item: item, trip: trip, onEdit: { editing = item })
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if canEdit {
                    Button(role: .destructive) { remove(item) } label: { Label("Delete", systemImage: "trash") }
                    Button { editing = item } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if canEdit {
                    Button {
                        item.packed.toggle()
                        Persistence.shared.save()
                    } label: {
                        Label(item.packed ? "Unpack" : "Packed", systemImage: item.packed ? "arrow.uturn.backward" : "checkmark")
                    }
                    .tint(palette.accent)
                }
            }
            .contextMenu {
                Button { editing = item } label: { Label("Edit", systemImage: "pencil") }
                if canEdit {
                    Button(role: .destructive) { remove(item) } label: { Label("Delete", systemImage: "trash") }
                }
            }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Who", selection: $whoFilter) {
                Text("Everyone").tag("all")
                ForEach(trip.peopleList) { p in Text(p.displayName).tag(p.key) }
                Text("Shared").tag(Who.shared)
                Text("Matching").tag(Who.matching)
            }
            Picker("Bag", selection: $bagFilter) {
                Text("All bags").tag("all")
                ForEach(Bag.allCases) { b in Text(b.label).tag(b.rawValue) }
            }
            Toggle("Hide packed", isOn: $hidePacked)
            if anyFilter {
                Button("Clear filters") { whoFilter = "all"; bagFilter = "all"; hidePacked = false; search = "" }
            }
        } label: {
            IconText(anyFilter ? "Filters on" : "Filters", anyFilter ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.bordered)
    }

    private func progressLabel(shown: [PackItem], packed: Int) -> String {
        if items.isEmpty { return "Nothing on the list yet" }
        var s = "\(packed) of \(shown.count) packed"
        if whoFilter == "all" && trip.travelers.count > 1 {
            let per = trip.travelers.map { p -> String in
                let mine = items.filter { ($0.whoKey ?? "") == p.key }
                return "\(p.displayName) \(mine.filter { $0.packed }.count)/\(mine.count)"
            }
            s += " · " + per.joined(separator: " · ")
        }
        let buy = shown.filter { $0.statusValue == .buy }.count
        if buy > 0 { s += " · \(buy) to buy" }
        return s
    }

    private func draftBinding(_ key: String) -> Binding<String> {
        Binding(get: { drafts[key] ?? "" }, set: { drafts[key] = $0 })
    }

    private func remove(_ item: PackItem) {
        let snapshot = ItemDraft(item)
        let outfit = item.outfit
        let name = item.text ?? "item"
        Persistence.shared.delete(item)
        toasts.show("Removed \"\(name)\"", actionLabel: "Undo") { [trip] in
            snapshot.insert(into: trip, outfit: outfit)
            Persistence.shared.save()
        }
    }
}

// MARK: - Rows

struct ItemRow: View {
    @ObservedObject var item: PackItem
    var trip: Trip
    var showWho = true
    var showDay = true
    var showOutfit = true
    var onEdit: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                item.packed.toggle()
                Persistence.shared.save()
            } label: {
                Image(systemName: item.packed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.packed ? palette.accent : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!canEdit)
            .accessibilityLabel(item.packed ? "Packed" : "Not packed")

            VStack(alignment: .leading, spacing: 5) {
                Text(item.text ?? "")
                    .strikethrough(item.packed)
                    .foregroundStyle(item.packed ? .secondary : .primary)
                FlowLayout(spacing: 5) {
                    BagPill(bag: item.bagValue) { new in
                        item.bagValue = new
                        Persistence.shared.save()
                    }
                    if showWho { WhoTag(whoKey: item.whoKey, trip: trip) }
                    if item.statusValue == .buy { Tag(text: "To buy", fg: StatusColor.buyFG, bg: StatusColor.buyBG) }
                    if item.statusValue == .make { Tag(text: "To make", fg: StatusColor.makeFG, bg: StatusColor.makeBG) }
                    if showDay, let d = item.dayKey, !d.isEmpty { InfoChip(text: DayKey.short(d), systemImage: "calendar") }
                    if showOutfit, let o = item.outfit { InfoChip(text: o.label, systemImage: "tshirt") }
                }
                if let note = item.note, !note.isEmpty {
                    Text(note).font(.caption).italic().foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onEdit)

            QtyStepper(qty: Int(item.qty)) { n in
                item.qty = Int16(max(1, min(99, n)))
                Persistence.shared.save()
            }
        }
        .padding(.vertical, 2)
    }
}

struct SearchField: View {
    @Binding var text: String
    var prompt: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(prompt, text: $text).autocorrectionDisabled()
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 9))
    }
}

struct QuickAddRow: View {
    var placeholder: String
    @Binding var text: String
    var onAdd: (String) -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Image(systemName: "plus").foregroundStyle(palette.accent)
            TextField(placeholder, text: $text)
                .submitLabel(.done)
                .onSubmit(add)
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: add).buttonStyle(.borderless).font(.subheadline.bold())
            }
        }
    }

    private func add() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        onAdd(t)
        text = ""
    }
}

// MARK: - Starting a list

struct StartPanel: View {
    @ObservedObject var trip: Trip
    var personKey: String
    var empty: Bool
    @Environment(\.palette) private var palette
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "startDay", ascending: true)]) private var allTrips: FetchedResults<Trip>

    private var name: String { trip.person(personKey)?.displayName ?? "your" }

    var body: some View {
        let previous = previousTrip
        VStack(alignment: .leading, spacing: 10) {
            Text(empty ? "Start packing for \(trip.displayName)" : "Start \(name)'s list")
                .font(.display(22, weight: .heavy)).textCase(.uppercase)
                .foregroundStyle(palette.accent)
            Text(empty ? "Pick a starting point. You can change anything afterward, and outfit pieces you plan land on this list too."
                       : "\(name) has nothing of their own on this list yet.")
                .font(.subheadline).foregroundStyle(.secondary)
            if let previous {
                startButton("Bring back \(previous.0.displayName)", "\(previous.1) items, unpacked and ready to check off again") {
                    bringBack(from: previous.0)
                }
            }
            startButton("Race weekend essentials", "\(Starters.essentials.count + trip.extras.count) basics, plus picks for this weekend") {
                addEssentials()
            }
        }
        .padding(.vertical, 6)
    }

    private func startButton(_ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(palette.wash, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    /// The most recent other trip where this person (matched by name) had a list.
    private var previousTrip: (Trip, Int)? {
        let myName = normalized(trip.person(personKey)?.name)
        let candidates: [(Trip, Int)] = allTrips.compactMap { other in
            guard other != trip else { return nil }
            let count = other.itemList.filter { item in
                guard item.outfit == nil else { return false }
                let w = item.whoKey ?? ""
                return w == Who.shared || w == Who.matching || normalized(other.person(w)?.name) == myName
            }.count
            return count > 0 ? (other, count) : nil
        }
        let before = candidates.filter { ($0.0.startDay ?? "") < (trip.startDay ?? "") }
        return (before.isEmpty ? candidates : before).max { ($0.0.startDay ?? "") < ($1.0.startDay ?? "") }
    }

    private func bringBack(from other: Trip) {
        let p = Persistence.shared
        let myName = normalized(trip.person(personKey)?.name)
        let have = Set(trip.itemList.filter { $0.belongs(to: personKey) }.map { normalized($0.text) })
        for item in other.itemList where item.outfit == nil {
            let w = item.whoKey ?? ""
            let newWho: String
            if w == Who.shared || w == Who.matching { newWho = w }
            else if normalized(other.person(w)?.name) == myName { newWho = personKey }
            else { continue }
            guard !have.contains(normalized(item.text)) else { continue }
            let status: ItemStatus = item.statusValue == .buy ? .own : item.statusValue
            p.addItem(to: trip, text: item.text ?? "", category: item.categoryKey, who: newWho, qty: Int(item.qty),
                      bag: item.bagValue, status: status, note: item.note)
        }
        p.save()
    }

    private func addEssentials() {
        let p = Persistence.shared
        let have = Set(trip.itemList.filter { $0.belongs(to: personKey) }.map { normalized($0.text) })
        for s in Starters.essentials where !have.contains(normalized(s.text)) {
            p.addItem(to: trip, text: s.text, category: s.cat, who: s.shared ? Who.shared : personKey, bag: s.bag, note: s.note)
        }
        for e in trip.extras where !have.contains(normalized(e.text)) {
            p.addItem(to: trip, text: e.text, category: e.cat, who: (e.shared ?? false) ? Who.shared : personKey, bag: Bag(key: e.bag))
        }
        p.save()
    }
}
