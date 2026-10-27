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
        }
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
