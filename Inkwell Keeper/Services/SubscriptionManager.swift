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

    @Published var isSubscribed = false
    @Published var currentOffering: Offering?
    @Published var isLoading = false
    @Published var error: String?

    static let entitlementID = "Ink Well Keeper Pro"
    static let offeringID = "default"

    private init() {}

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
            let offerings = try await Purchases.shared.offerings()
            await MainActor.run {
                self.currentOffering = offerings.offering(identifier: Self.offeringID)
                    ?? offerings.current
            }
        } catch {
            print("[SubscriptionManager] Error fetching offerings: \(error)")
            await MainActor.run {
                self.error = "Unable to load subscription options. Please try again."
            }
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        await MainActor.run {
            error = nil
            isLoading = true
        }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let result = try await Purchases.shared.purchase(package: package)

            if result.userCancelled {
                print("[SubscriptionManager] Purchase cancelled by user")
                return false
            }

            // Log all entitlements so we can verify the entitlement ID is correct
            let entitlements = result.customerInfo.entitlements.all
            print("[SubscriptionManager] Purchase complete. Active entitlements: \(entitlements.keys.joined(separator: ", "))")
            for (key, info) in entitlements {
                print("[SubscriptionManager]   '\(key)' — isActive: \(info.isActive), productID: \(info.productIdentifier)")
            }

            var isNowSubscribed = result.customerInfo.entitlements[Self.entitlementID]?.isActive == true

            // If the entitlement isn't showing yet (can happen in sandbox), invalidate
            // the cache and re-fetch once to give RevenueCat a chance to sync.
            if !isNowSubscribed {
                print("[SubscriptionManager] Entitlement '\(Self.entitlementID)' not active in purchase result — forcing refresh...")
                Purchases.shared.invalidateCustomerInfoCache()
                let refreshed = try await Purchases.shared.customerInfo()
                isNowSubscribed = refreshed.entitlements[Self.entitlementID]?.isActive == true
                print("[SubscriptionManager] After refresh — isSubscribed: \(isNowSubscribed)")
            }

            await MainActor.run {
                self.isSubscribed = isNowSubscribed
            }
            return isNowSubscribed
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }

    func restorePurchases() async throws {
        await MainActor.run {
            error = nil
            isLoading = true
        }
        defer { Task { @MainActor in isLoading = false } }

        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            await MainActor.run {
                self.isSubscribed = customerInfo.entitlements[Self.entitlementID]?.isActive == true
                if !self.isSubscribed {
                    self.error = "No active subscription found."
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Unable to restore purchases. Please try again."
            }
            throw error
        }
    }
}
