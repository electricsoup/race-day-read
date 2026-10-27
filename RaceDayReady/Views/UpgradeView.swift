//
//  UpgradeView.swift
//  Race Day Ready
//

import SwiftUI

struct UpgradeView: View {
    var compact: Bool
    @EnvironmentObject private var store: StoreManager
    @Environment(\.palette) private var palette

    private static let features: [(String, String, String)] = [
        ("sparkles", "Trend-based content ideas", "Hooks, sounds and filming notes matched to each race weekend, refreshed as trends change."),
        ("list.bullet.rectangle", "A shot list for every day", "Plan what to film when, and match each shot to the outfit you'll be wearing."),
        ("calendar.badge.plus", "Export to your calendar", "Send the whole shot list, or one day, to Calendar with times, hooks and outfits in each event."),
        ("person.2", "Covers your family", "One purchase works for everyone in your Apple family.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RACE DAY READY PRO").font(.system(size: 12, weight: .heavy)).tracking(1.4).foregroundStyle(palette.gold)
                    Text("Film the weekend, not just run it.")
                        .font(.display(30, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Content ideas and shot lists for creators who race.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.header, in: RoundedRectangle(cornerRadius: 16))

                ForEach(Self.features, id: \.1) { f in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: f.0).font(.title3).foregroundStyle(palette.accent).frame(width: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(f.1).font(.headline)
                            Text(f.2).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    Task { await store.purchase() }
                } label: {
                    HStack {
                        if store.isWorking { ProgressView().tint(.white) }
                        Text(store.priceLabel.isEmpty ? "Unlock Pro" : "Unlock Pro · \(store.priceLabel), one time")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isWorking)

                Button("Restore purchase") { Task { await store.restore() } }
                    .frame(maxWidth: .infinity)
                    .font(.subheadline)
                    .disabled(store.isWorking)

                Text("A one-time purchase. No subscription. Packing lists, outfits, to-dos and sharing stay free.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .alert("Pro", isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(store.lastError ?? "") }
    }
}
