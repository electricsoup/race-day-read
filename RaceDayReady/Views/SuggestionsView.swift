//
//  SuggestionsView.swift
//  Race Day Ready
//
//  What to add next: things you packed for other weekends (matched by your name),
//  picks for this weekend, and the essentials. Hide anything you never want suggested.
//

import SwiftUI
import CoreData

struct SuggestionsView: View {
    @ObservedObject var trip: Trip
    var personKey: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)]) private var allItems: FetchedResults<PackItem>
    @State private var hidden = Prefs.hiddenSuggestions

    private struct Suggestion: Identifiable {
        var id: String { key }
        var key: String
        var text: String
        var category: String
        var who: String
        var qty: Int
        var bag: Bag
        var note: String?
        var detail: String
        var costume: Bool
    }

    private var person: Person? { trip.person(personKey) ?? trip.peopleList.first }
    private var pkey: String { person?.key ?? Who.shared }

    private var have: Set<String> {
        Set(trip.itemList.filter { $0.belongs(to: pkey) }.map { normalized($0.text) })
    }

    private var library: [Suggestion] {
        let myName = normalized(person?.name)
        let have = self.have
        var byKey: [String: (Suggestion, Set<String>, String)] = [:]
        for item in allItems {
            guard let other = item.trip, other != trip else { continue }
            let w = item.whoKey ?? ""
            let isMine = w == Who.shared || w == Who.matching || normalized(other.person(w)?.name) == myName
            guard isMine else { continue }
            let key = normalized(item.text)
            guard !key.isEmpty, !have.contains(key), !hidden.contains(key) else { continue }
            let who = (w == Who.shared || w == Who.matching) ? w : pkey
            let start = other.startDay ?? ""
            if var entry = byKey[key] {
                entry.1.insert(other.idString)
                if start > entry.2 {
                    entry.0.text = item.text ?? entry.0.text
                    entry.2 = start
                }
                if item.outfit == nil { entry.0.costume = false }
                byKey[key] = entry
            } else {
                let s = Suggestion(key: key, text: item.text ?? "", category: item.categoryKey, who: who, qty: Int(max(1, item.qty)),
                                   bag: item.bagValue, note: item.note, detail: other.displayName, costume: item.outfit != nil)
                byKey[key] = (s, [other.idString], start)
            }
        }
        return byKey.values.map { entry -> Suggestion in
            var s = entry.0
            s.detail = entry.1.count > 1 ? "Packed for \(entry.1.count) weekends" : "Packed for \(s.detail)"
            if s.who == Who.shared { s.detail = "Shared · " + s.detail }
            return s
        }
        .sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
    }

    private var picks: [Suggestion] {
        trip.extras.filter { !have.contains(normalized($0.text)) }.map {
            Suggestion(key: normalized($0.text), text: $0.text, category: $0.cat, who: ($0.shared ?? false) ? Who.shared : pkey, qty: 1,
                       bag: Bag(key: $0.bag), note: nil, detail: Starters.categoryTitle($0.cat), costume: false)
        }
    }

    private var essentials: [Suggestion] {
        Starters.essentials.filter { !have.contains(normalized($0.text)) }.map {
            Suggestion(key: normalized($0.text), text: $0.text, category: $0.cat, who: $0.shared ? Who.shared : pkey, qty: 1,
                       bag: $0.bag, note: $0.note, detail: Starters.categoryTitle($0.cat) + ($0.shared ? " · goes on the shared list" : ""), costume: false)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if trip.peopleList.count > 1 {
                    Text("Suggestions for \(person?.displayName ?? "you"). Filter Pack by someone else to see theirs.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                let lib = library
                section("From your past lists", "Things you packed for other weekends that aren't on this list yet",
                        lib.filter { !$0.costume }, canHide: true,
                        empty: "Once you've packed for one weekend, everything on that list shows up here for the next one.")
                let costumes = lib.filter { $0.costume }
                if !costumes.isEmpty {
                    section("Costume pieces you've used", "Ears, bows and props from past outfits", costumes, canHide: true, empty: "")
                }
                section("Picked for \(trip.displayName)", trip.climate ?? "Extras for this weekend", picks, canHide: false,
                        empty: "All of these are on your list.")
                section("Race weekend essentials", "The basics", essentials, canHide: false, empty: "Every essential is on your list.")
                if !hidden.isEmpty {
                    Section {
                        Button("Show \(hidden.count) hidden suggestion\(hidden.count == 1 ? "" : "s") again") {
                            hidden = []
                            Prefs.hiddenSuggestions = []
                        }
                    }
                }
            }
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ subtitle: String, _ list: [Suggestion], canHide: Bool, empty: String) -> some View {
        Section {
            if list.isEmpty {
                if !empty.isEmpty { Text(empty).font(.subheadline).foregroundStyle(.secondary) }
            } else {
                ForEach(list) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.text)
                            Text(s.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if canHide {
                            Button("Hide") { hide(s.key) }.buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary)
                        }
                        Button { add([s]) } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                            .buttonStyle(.borderless)
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel("Add \(s.text)")
                    }
                }
                if list.count > 1 {
                    Button("Add all \(list.count)") { add(list) }.font(.subheadline.bold())
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle).font(.caption).textCase(nil).foregroundStyle(.secondary)
            }
        }
    }

    private func add(_ list: [Suggestion]) {
        let p = Persistence.shared
        for s in list {
            p.addItem(to: trip, text: s.text, category: s.costume ? "outfits" : s.category, who: s.who, qty: s.qty, bag: s.bag, note: s.note)
        }
        p.save()
    }

    private func hide(_ key: String) {
        hidden.insert(key)
        Prefs.hiddenSuggestions = hidden
    }
}
