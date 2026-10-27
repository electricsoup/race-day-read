//
//  RaceDayReadyApp.swift
//  Race Day Ready
//

import SwiftUI

@main
struct RaceDayReadyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = StoreManager()
    @StateObject private var feed = FeedStore()
    @StateObject private var toasts = ToastCenter()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TripsListView()
                .environment(\.managedObjectContext, Persistence.shared.viewContext)
                .environmentObject(store)
                .environmentObject(feed)
                .environmentObject(toasts)
                .overlay { ToastOverlay(center: toasts) }
                .task { await feed.refresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Persistence.shared.save() }
        }
    }
}
