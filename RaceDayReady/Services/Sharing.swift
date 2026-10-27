//
//  Sharing.swift
//  Race Day Ready
//
//  Shares a trip through iCloud with Apple's standard sharing sheet
//  (Messages, Mail, copy link…), and accepts invitations when someone opens the link.
//

import CloudKit
import SwiftUI
import UIKit

@MainActor
enum TripSharing {
    static func present(for trip: Trip) async throws {
        let persistence = Persistence.shared
        guard persistence.cloudEnabled else { throw SharingError.iCloudOff }
        persistence.save()

        let share: CKShare
        let ckContainer = CKContainer(identifier: Persistence.cloudContainerID)
        if let existing = persistence.existingShare(for: trip) {
            share = existing
        } else {
            let (_, newShare, _) = try await persistence.container.share([trip], to: nil)
            share = newShare
        }
        share[CKShare.SystemFieldKey.title] = trip.displayName as CKRecordValue
        share.publicPermission = .none

        let controller = UICloudSharingController(share: share, container: ckContainer)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = ShareDelegate.shared
        ShareDelegate.shared.title = trip.displayName
        controller.modalPresentationStyle = .formSheet
        topViewController()?.present(controller, animated: true)
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    enum SharingError: LocalizedError {
        case iCloudOff
        var errorDescription: String? {
            "Sharing needs iCloud. Sign in to iCloud in Settings, turn on iCloud for Race Day Ready, then try again."
        }
    }
}

final class ShareDelegate: NSObject, UICloudSharingControllerDelegate {
    static let shared = ShareDelegate()
    var title = "Race weekend"

    func itemTitle(for csc: UICloudSharingController) -> String? { title }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("Share failed: \(error)")
    }
}

// MARK: - App and scene delegates (accepting invitations)

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Persistence.shared.acceptShare(cloudKitShareMetadata)
    }
}

// MARK: - Share sheet for files (the .ics export)

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Wraps a file URL so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}
