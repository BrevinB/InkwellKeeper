//
//  TipJarManager.swift
//  Inkwell Keeper
//
//  Manages RevenueCat tip jar functionality
//

import RevenueCat
import SwiftUI
import Combine

class TipJarManager: ObservableObject {
    static let shared = TipJarManager()

    @Published var offerings: [Package] = []
    @Published var isLoading = false
    @Published var hasPurchasedAnyTip = false

    private init() {}

    func configure() {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "appl_meltaNqtZPKjwzOqVmqtrwXVAwM")

        // Check if user has purchased any tips before
        checkPurchaseHistory()
    }

    func loadOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            if let defaultOffering = offerings.current {
                await MainActor.run {
                    self.offerings = defaultOffering.availablePackages
                }
            }
        } catch {
            print("Error fetching offerings: \(error)")
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)

        if result.userCancelled {
            return false
        }

        await MainActor.run {
            hasPurchasedAnyTip = true
        }

        return true
    }

    private func checkPurchaseHistory() {
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                // Check if user has any non-subscription purchases
                await MainActor.run {
                    hasPurchasedAnyTip = !customerInfo.nonSubscriptions.isEmpty
                }
            } catch {
                print("Error checking purchase history: \(error)")
            }
        }
    }
}
