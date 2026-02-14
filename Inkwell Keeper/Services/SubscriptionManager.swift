//
//  SubscriptionManager.swift
//  Inkwell Keeper
//
//  Manages RevenueCat subscription state for premium features
//

import RevenueCat
import SwiftUI
import Combine

class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let entitlementID = "rules_assistant"
    static let offeringID = "rules_assistant"

    @Published var isSubscribed = false
    @Published var offerings: [Package] = []
    @Published var isLoading = false
    @Published var isRestoring = false

    private init() {
        checkSubscriptionStatus()
    }

    func checkSubscriptionStatus() {
        Task {
            do {
                let customerInfo = try await Purchases.shared.customerInfo()
                await MainActor.run {
                    self.isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
                }
            } catch {
                print("[SubscriptionManager] Error checking status: \(error)")
            }
        }
    }

    func loadOfferings() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let allOfferings = try await Purchases.shared.offerings()
            if let offering = allOfferings.offering(identifier: Self.offeringID) ?? allOfferings.current {
                await MainActor.run {
                    self.offerings = offering.availablePackages
                }
            }
        } catch {
            print("[SubscriptionManager] Error fetching offerings: \(error)")
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)

        if result.userCancelled {
            return false
        }

        let isActive = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true
        await MainActor.run {
            self.isSubscribed = isActive
        }

        return isActive
    }

    func restorePurchases() async throws {
        await MainActor.run { isRestoring = true }
        defer { Task { @MainActor in isRestoring = false } }

        let customerInfo = try await Purchases.shared.restorePurchases()
        let isActive = customerInfo.entitlements[Self.entitlementID]?.isActive == true
        await MainActor.run {
            self.isSubscribed = isActive
        }
    }
}
