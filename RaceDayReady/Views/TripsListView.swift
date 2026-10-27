//
//  TripsListView.swift
//  Race Day Ready
//
//  Home: your race weekends, upcoming first, with packing progress.
//

import SwiftUI
import CoreData

struct TripsListView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "startDay", ascending: true)])
    private var trips: FetchedResults<Trip>

    @State private var showNewTrip = false
    @State private var showSettings = false
    @State private var path = NavigationPath()
    @EnvironmentObject private var feed: FeedStore

    private var upcoming: [Trip] { trips.filter { $0.depart >= DayKey.today } }
    private var past: [Trip] { trips.filter { $0.depart < DayKey.today }.reversed() }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("No race weekends yet", systemImage: "figure.run")
                    } description: {
                        Text("Add a race weekend to start your packing list, outfits and pre-trip to-dos.")
                    } actions: {
                        Button("Add a race weekend") { showNewTrip = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Coming up") {
                                ForEach(upcoming) { trip in
                                    NavigationLink(value: trip) { TripRow(trip: trip) }
                                }
                            }
                        }
                        if !past.isEmpty {
                            Section("Finished") {
                                ForEach(past) { trip in
                                    NavigationLink(value: trip) { TripRow(trip: trip) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Race Day Ready")
            .navigationDestination(for: Trip.self) { trip in
                TripView(trip: trip)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewTrip = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a race weekend")
                }
            }
            .sheet(isPresented: $showNewTrip) {
                NewTripView { trip in
                    showNewTrip = false
                    path.append(trip)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task { openDemoIfAsked() }
        }
    }

    /// For screenshots and testing: launch with -demoTrip to open a filled-in sample trip.
    private func openDemoIfAsked() {
        #if DEBUG
        guard CommandLine.arguments.contains("-demoTrip") else { return }
        if let first = trips.first { path.append(first); return }
        guard let def = feed.weekend("mw-2027") ?? feed.feed.weekends.first else { return }
        let p = Persistence.shared
        let trip = p.createTrip(from: def, people: ["Misty", "Andrew"])
        guard let me = trip.peopleList.first, let him = trip.peopleList.last else { return }
        for s in Starters.essentials.prefix(14) {
            p.addItem(to: trip, text: s.text, category: s.cat, who: s.shared ? Who.shared : me.key, bag: s.bag, note: s.note)
        }
        p.addItem(to: trip, text: "Extra race shoes", category: "race", who: me.key, qty: 2)
        p.addItem(to: trip, text: "Running belt", category: "race", who: him.key, status: .buy)
        if let race = trip.races.first(where: { $0.id == "half" }) {
            let o = p.addOutfit(to: trip, day: race.date, slot: "Race", title: race.name, theme: race.theme ?? "", ideasKey: race.ideas ?? "",
                                raceID: race.id, who: me.key, bag: .carry)
            for piece in ["Daisy's pink hair bow", "Lavender top (Daisy)", "Hat / visor / headband"] {
                p.addItem(to: trip, text: piece, category: "outfits", who: me.key, bag: .carry, day: race.date, outfit: o)
            }
            let shot = p.addShot(to: trip, title: "Low-angle costume walk reveal", day: race.date, time: "04:15", outfit: o, who: me.key,
                                 idea: feed.feed.ideas.first { $0.id == "rc-costume-walk" })
            shot.location = "Corral"
        }
        for t in Starters.prepTemplates.prefix(5) { p.addTask(to: trip, title: t.title, due: DayKey.add(trip.arrive, days: -t.daysBefore)) }
        p.save()
        path.append(trip)
        #endif
    }
}

private struct TripRow: View {
    @ObservedObject var trip: Trip

    var body: some View {
        let palette = Palette.forTheme(trip.theme)
        let items = trip.itemList
        let packed = items.filter { $0.packed }.count
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(palette.header)
                .frame(width: 6)
                .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 3).fill(palette.gold).frame(height: 14) }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(trip.displayName).font(.display(20)).textCase(.uppercase)
                    if Persistence.shared.isShared(trip) {
                        Image(systemName: "person.2.fill").font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("Shared")
                    }
                }
                Text(DayKey.rangeLabel(trip.arrive, trip.depart)).font(.subheadline).foregroundStyle(.secondary)
                if !items.isEmpty {
                    ProgressView(value: Double(packed), total: Double(max(items.count, 1)))
                        .tint(palette.accent)
                    Text("\(packed) of \(items.count) packed").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}
