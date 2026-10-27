//
//  ItemEditor.swift
//  Race Day Ready
//

import SwiftUI

struct ItemDraft: Identifiable {
    let id = UUID()
    var text = ""
    var qty = 1
    var category = "race"
    var who: String
    var bag: Bag = .any
    var status: ItemStatus = .none
    var day = ""
    var outfitKey = ""
    var note = ""
    var packed = false

    init(who: String, category: String = "race") {
        self.who = who
        self.category = category
    }

    init(_ item: PackItem) {
        text = item.text ?? ""
        qty = max(1, Int(item.qty))
        category = item.categoryKey
        who = item.whoKey ?? Who.shared
        bag = item.bagValue
        status = item.statusValue
        day = item.dayKey ?? ""
        outfitKey = item.outfit?.uuid?.uuidString ?? ""
        note = item.note ?? ""
        packed = item.packed
    }

    func outfit(in trip: Trip) -> Outfit? {
        outfitKey.isEmpty ? nil : trip.outfitList.first { $0.uuid?.uuidString == outfitKey }
    }

    func apply(to item: PackItem, trip: Trip) {
        let o = outfit(in: trip)
        item.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        item.qty = Int16(max(1, min(99, qty)))
        item.category = category
        item.whoKey = who
        item.bag = bag.rawValue
        item.status = status.rawValue
        item.dayKey = day.isEmpty ? (o?.dayKey) : day
        item.outfit = o
        item.note = note.isEmpty ? nil : note
        item.packed = packed
    }

    /// Re-creates a deleted item (used by Undo).
    @discardableResult
    func insert(into trip: Trip, outfit: Outfit? = nil) -> PackItem {
        let item = Persistence.shared.addItem(to: trip, text: text, category: category, who: who, qty: qty, bag: bag,
                                              day: day.isEmpty ? nil : day, outfit: outfit ?? self.outfit(in: trip),
                                              status: status, note: note, packed: packed)
        return item
    }
}

struct ItemEditor: View {
    @ObservedObject var trip: Trip
    var item: PackItem?
    @State private var draft: ItemDraft
    @Environment(\.dismiss) private var dismiss
    @Environment(\.canEdit) private var canEdit
    @EnvironmentObject private var toasts: ToastCenter

    init(trip: Trip, item: PackItem?, draft: ItemDraft) {
        self.trip = trip
        self.item = item
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What to pack", text: $draft.text, axis: .vertical)
                    Stepper("How many: \(draft.qty)", value: $draft.qty, in: 1...99)
                    Picker("Category", selection: $draft.category) {
                        ForEach(Starters.categories, id: \.id) { Text($0.title).tag($0.id) }
                    }
                }
                Section("Packed in") {
                    Picker("Bag", selection: $draft.bag) {
                        ForEach(Bag.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Picker("Whose", selection: $draft.who) {
                        ForEach(trip.whoOptions, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    Picker("Status", selection: $draft.status) {
                        ForEach(ItemStatus.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Day", selection: $draft.day) {
                        Text("Any day").tag("")
                        ForEach(trip.days, id: \.self) { Text(DayKey.short($0)).tag($0) }
                    }
                    Picker("Outfit", selection: $draft.outfitKey) {
                        Text("Not part of an outfit").tag("")
                        ForEach(trip.outfitList) { o in Text(o.label).tag(o.uuid?.uuidString ?? "") }
                    }
                    Toggle("Packed", isOn: $draft.packed)
                }
                Section("Note") {
                    TextField("Optional", text: $draft.note, axis: .vertical)
                }
                if item != nil && canEdit {
                    Section {
                        Button("Delete item", role: .destructive) { deleteItem() }
                    }
                }
            }
            .disabled(!canEdit)
            .navigationTitle(item == nil ? "Add an item" : "Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(item == nil ? "Add" : "Save") { save() }
                        .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !canEdit)
                }
            }
        }
    }

    private func save() {
        if let item {
            draft.apply(to: item, trip: trip)
        } else {
            draft.insert(into: trip)
        }
        Persistence.shared.save()
        dismiss()
    }

    private func deleteItem() {
        guard let item else { return }
        let snapshot = ItemDraft(item)
        let outfit = item.outfit
        let name = item.text ?? "item"
        dismiss()
        Persistence.shared.delete(item)
        toasts.show("Removed \"\(name)\"", actionLabel: "Undo") { [trip] in
            snapshot.insert(into: trip, outfit: outfit)
            Persistence.shared.save()
        }
    }
}
