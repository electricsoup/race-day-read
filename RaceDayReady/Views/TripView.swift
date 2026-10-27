//
//  TripView.swift
//  Race Day Ready
//
//  One race weekend: Pack, Outfits, Prep and Content tabs, all colored for the weekend.
//

import SwiftUI

enum TripTab: Hashable { case pack, outfits, prep, content }

struct TripView: View {
    @ObservedObject var trip: Trip
    @EnvironmentObject private var toasts: ToastCenter
    @AppStorage private var meKey: String
    @State private var tab: TripTab = .pack
    @State private var showSettings = false
    @State private var askWho = false
    @State private var shareError: String?
    @State private var pendingDelete = false
    @Environment(\.dismiss) private var dismiss

    init(trip: Trip) {
        self.trip = trip
        _meKey = AppStorage(wrappedValue: "", "me." + trip.idString)
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            let start: [String: TripTab] = ["pack": .pack, "outfits": .outfits, "prep": .prep, "content": .content]
            _tab = State(initialValue: start[args[i + 1]] ?? .pack)
        }
        #endif
    }

    private var palette: Palette { Palette.forTheme(trip.theme) }
    private var canEdit: Bool { Persistence.shared.canEdit(trip) }

    var body: some View {
        TabView(selection: $tab) {
            PackView(trip: trip, meKey: $meKey)
                .tabItem { Label("Pack", systemImage: "checklist") }
                .tag(TripTab.pack)
            OutfitsView(trip: trip, meKey: meKey)
                .tabItem { Label("Outfits", systemImage: "tshirt") }
                .tag(TripTab.outfits)
            PrepView(trip: trip, meKey: meKey)
                .tabItem { Label("Prep", systemImage: "list.bullet.clipboard") }
                .tag(TripTab.prep)
            ContentHubView(trip: trip, meKey: meKey)
                .tabItem { Label("Content", systemImage: "video") }
                .tag(TripTab.content)
        }
        .tint(palette.accent)
        .environment(\.palette, palette)
        .environment(\.canEdit, canEdit)
        .navigationTitle(trip.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(palette.header, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if Persistence.shared.isOwner(trip) {
                    Button {
                        Task {
                            do { try await TripSharing.present(for: trip) }
                            catch { shareError = error.localizedDescription }
                        }
                    } label: { Image(systemName: Persistence.shared.isShared(trip) ? "person.2.fill" : "person.crop.circle.badge.plus") }
                    .accessibilityLabel("Share this trip")
                }
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Trip settings")
            }
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            guard pendingDelete else { return }
            pendingDelete = false
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [trip] in Persistence.shared.delete(trip) }
        }) {
            TripSettingsView(trip: trip, meKey: $meKey, onDelete: { pendingDelete = true })
                .environment(\.palette, palette)
                .environment(\.canEdit, canEdit)
        }
        .confirmationDialog("Which one is you?", isPresented: $askWho, titleVisibility: .visible) {
            ForEach(trip.peopleList) { p in
                Button(p.displayName) { meKey = p.key }
            }
        } message: {
            Text("This trip opens on your bib and your list. Anyone can still switch who they're packing for.")
        }
        .alert("Couldn't share", isPresented: Binding(get: { shareError != nil }, set: { if !$0 { shareError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareError ?? "")
        }
        .onAppear {
            if trip.person(meKey) == nil {
                if trip.peopleList.count > 1 { askWho = true }
                else if let only = trip.peopleList.first { meKey = only.key }
            }
        }
    }
}

// MARK: - Header: bib, race tiles, medals

struct TripHeader: View {
    @ObservedObject var trip: Trip
    var meKey: String
    @Environment(\.palette) private var palette
    @Environment(\.canEdit) private var canEdit

    private var me: Person? { trip.person(meKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(DayKey.rangeLabel(trip.arrive, trip.depart).uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(palette.gold)
                    Text(trip.displayName)
                        .font(.display(30, weight: .heavy)).textCase(.uppercase)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    if let tag = trip.tagline, !tag.isEmpty {
                        Text(tag).font(.caption).foregroundStyle(.white.opacity(0.75)).lineLimit(3)
                    }
                    countdown
                }
                Spacer(minLength: 0)
                bib
            }
            if !trip.races.isEmpty || !trip.events.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(trip.races) { race in raceTile(race) }
                        ForEach(trip.events) { event in eventTile(event) }
                    }
                }
            }
            ForEach(trip.challenges) { c in medalLine(c) }
        }
        .padding(16)
        .background(palette.header)
    }

    private var countdown: some View {
        let left = DayKey.between(DayKey.today, trip.arrive)
        let gone = DayKey.between(trip.depart, DayKey.today)
        let text: String
        if left > 1 { text = "\(left) days until you fly" }
        else if left == 1 { text = "1 day until you fly" }
        else if left == 0 { text = "Travel day" }
        else if gone <= 0 { text = "Race weekend is on" }
        else { text = "Finished" }
        return Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy)).tracking(0.8)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(palette.gold, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(palette.header)
    }

    private var bib: some View {
        let total = trip.miles(for: me)
        let onTrip = me?.traveling ?? false
        return VStack(spacing: 2) {
            Text(trip.displayName.uppercased())
                .font(.system(size: 9, weight: .bold)).tracking(1)
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(palette.header)
            Divider().overlay(palette.header)
            Text(milesText(total))
                .font(.display(40, weight: .heavy).monospacedDigit())
                .foregroundStyle(Color(hex: 0x1D1B24))
            Text((me?.displayName ?? "Runner").uppercased())
                .font(.display(14)).tracking(1)
                .foregroundStyle(Color(hex: 0x1D1B24))
                .lineLimit(1)
            Text(!onTrip ? "not on this trip" : (total > 0 ? "miles this weekend" : "cheer squad"))
                .font(.system(size: 9)).foregroundStyle(Color(hex: 0x5E5A63))
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .frame(width: 128)
        .background(Color(hex: 0xFFFDF8), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            GeometryReader { g in
                ForEach(0..<4, id: \.self) { i in
                    Circle().fill(palette.header).frame(width: 7, height: 7)
                        .position(x: i % 2 == 0 ? 9 : g.size.width - 9, y: i < 2 ? 9 : g.size.height - 9)
                }
            }
        }
        .rotationEffect(.degrees(-2))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 5)
        .accessibilityElement(children: .combine)
    }

    private func raceTile(_ race: RaceDef) -> some View {
        let on = me?.runs.contains(race.id) ?? false
        let runners = trip.runners(of: race.id).map { $0.displayName }
        return Button {
            guard let me else { return }
            var runs = me.runs
            if on { runs.removeAll { $0 == race.id } } else { runs.append(race.id); me.traveling = true }
            me.runs = trip.races.map { $0.id }.filter { runs.contains($0) }
            Persistence.shared.save()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text((DayKey.format(race.date, "EEE M/d") + (race.time.map { " · " + TimeKey.label($0) } ?? "")).uppercased())
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                Text(race.short.uppercased()).font(.display(22, weight: .heavy)).foregroundStyle(.white.opacity(on ? 1 : 0.55))
                Text(race.theme ?? "—").font(.caption).foregroundStyle(.white.opacity(on ? 0.8 : 0.5)).lineLimit(2)
                Text(runners.isEmpty ? "Nobody running" : joinNames(runners) + " running")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(palette.gold).lineLimit(2)
                    .padding(.top, 2)
            }
            .frame(width: 140, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(on ? 0.13 : 0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? palette.gold : Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!canEdit || me == nil)
        .accessibilityHint(on ? "Tap if \(me?.displayName ?? "you") isn't running this one" : "Tap if \(me?.displayName ?? "you") is running this one")
    }

    private func eventTile(_ event: EventDef) -> some View {
        let goers = trip.goers(of: event).map { $0.displayName }
        return VStack(alignment: .leading, spacing: 2) {
            Text((DayKey.format(event.date, "EEE M/d") + (event.when.map { " · " + $0 } ?? "")).uppercased())
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
            Text(event.short.uppercased()).font(.display(19, weight: .heavy)).foregroundStyle(.white)
            Text([event.place, event.about].compactMap { $0 }.joined(separator: " · "))
                .font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
            if !goers.isEmpty {
                Text(joinNames(goers) + " going").font(.system(size: 10, weight: .bold)).foregroundStyle(palette.gold).padding(.top, 2)
            }
        }
        .frame(width: 150, alignment: .leading)
        .padding(10)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.gold, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func medalLine(_ c: ChallengeDef) -> some View {
        let earners = trip.earners(of: c).map { $0.displayName }
        let names = c.needs.compactMap { id in trip.races.first { $0.id == id }?.short }.joined(separator: " + ")
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(earners.isEmpty ? Color.clear : palette.gold)
                .overlay(Circle().stroke(palette.gold, lineWidth: 1.5))
                .frame(width: 18, height: 18)
                .padding(.top, 1)
            (Text(c.name).bold().foregroundColor(.white)
             + Text(" · finish the \(names) (\(milesText(c.dist)) mi)\(c.theme.map { " for the \($0) medal" } ?? ""). ")
             + Text(earners.isEmpty ? "Nobody's running all of them yet." : joinNames(earners) + (earners.count > 1 ? " are" : " is") + " going for it."))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.top, 8)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1) }
    }
}
