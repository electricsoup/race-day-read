//
//  StoreManager.swift
//  Race Day Ready
//
//  StoreKit 2, one non-consumable: Race Day Ready Pro (content ideas + shot lists).
//  Family Sharing is turned on for it, so one purchase covers everyone in an Apple family.
//

import StoreKit
import SwiftUI

enum ProductID {
    /// Must EXACTLY match the product you create in App Store Connect > In-App Purchases.
    static let pro = "com.electricsoup.racedayready.pro"
}

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isWorking = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    var priceLabel: String { product?.displayPrice ?? "" }

    func loadProducts() async {
        do {
            product = try await Product.products(for: [ProductID.pro]).first
        } catch {
            lastError = "Couldn't reach the App Store. Try again in a moment."
        }
    }

    func purchase() async {
        if product == nil { await loadProducts() }
        guard let product else {
            lastError = "Pro isn't available right now. Try again in a moment."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase didn't go through. You weren't charged."
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { lastError = "No Pro purchase found for this Apple ID." }
        } catch {
            lastError = "Couldn't restore purchases. Check your connection and try again."
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if let t = try? checkVerified(result), t.productID == ProductID.pro, t.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? await self.checkVerified(result) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreError.failedVerification
        case .verified(let safe): return safe
        }
    }

    enum StoreError: Error { case failedVerification }
}
