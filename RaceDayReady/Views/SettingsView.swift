//
//  SettingsView.swift
//  Race Day Ready
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var feed: FeedStore
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "startDay", ascending: true)]) private var trips: FetchedResults<Trip>

    @State private var showUpgrade = false
    @State private var showKits = false
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Pro") {
                    if store.isPro {
                        Label("Pro is unlocked. Thanks!", systemImage: "checkmark.seal.fill")
                    } else {
                        Button { showUpgrade = true } label: { Label("Unlock content ideas and shot lists", systemImage: "sparkles") }
                    }
                    Button("Restore purchase") { Task { await store.restore() } }
                }
                Section {
                    Button { showKits = true } label: { Label("Outfit basics", systemImage: "bag") }
                } footer: {
                    Text("What goes into every race-day bag and park outfit.")
                }
                Section {
                    HStack {
                        Text("Race calendar & ideas")
                        Spacer()
                        Text(feed.feed.updated.isEmpty ? "Built in" : "Updated \(DayKey.format(feed.feed.updated, "MMM d"))").foregroundStyle(.secondary)
                    }
                    Button { Task { await feed.refresh() } } label: {
                        HStack {
                            Text("Check for updates")
                            if feed.isRefreshing { Spacer(); ProgressView() }
                        }
                    }
                }
                Section {
                    Button { importing = true } label: { Label("Import lists from a file", systemImage: "square.and.arrow.down") }
                } footer: {
                    Text("Brings in a Race Day Ready export (.json). Weekends already on this phone are skipped.")
                }
                Section {
                    LabeledContent("iCloud sync", value: Persistence.shared.cloudEnabled ? "On" : "Off")
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                } footer: {
                    Text("Race Day Ready isn't affiliated with or endorsed by any race organizer or theme park.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showUpgrade) { UpgradeView(compact: false) }
            .sheet(isPresented: $showKits) { KitsEditor() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Import", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(message ?? "") }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            message = "That file couldn't be opened."
        case .success(let url):
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let r = try Importer.run(data: data, feed: feed, existing: Array(trips))
                var text = "Added \(r.trips) weekend\(r.trips == 1 ? "" : "s"), \(r.items) item\(r.items == 1 ? "" : "s") and \(r.outfits) outfit\(r.outfits == 1 ? "" : "s")."
                if !r.skipped.isEmpty { text += " Skipped: " + r.skipped.joined(separator: ", ") + "." }
                message = text
            } catch {
                message = "That file isn't a Race Day Ready export."
            }
        }
    }
}
