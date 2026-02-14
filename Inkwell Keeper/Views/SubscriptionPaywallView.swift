//
//  SubscriptionPaywallView.swift
//  Inkwell Keeper
//
//  Paywall UI for Rules Assistant subscription
//

import SwiftUI
import RevenueCat

struct SubscriptionPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var purchasingPackageId: String?
    @State private var purchaseError: String?
    @State private var showRestoreSuccess = false
    @State private var showRestoreFailure = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                headerSection
                featuresSection

                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.lorcanaGold)
                        .padding()
                } else {
                    packagesSection
                }

                restoreButton
                legalSection
            }
            .padding()
        }
        .background(LorcanaBackground())
        .task {
            await subscriptionManager.loadOfferings()
        }
        .alert("Purchase Failed", isPresented: .init(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK") { purchaseError = nil }
        } message: {
            if let error = purchaseError {
                Text(error)
            }
        }
        .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
            Button("OK") { }
        } message: {
            Text("Your subscription has been restored successfully.")
        }
        .alert("No Subscription Found", isPresented: $showRestoreFailure) {
            Button("OK") { }
        } message: {
            Text("No active subscription was found for your account.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.circle.fill")
                .font(.system(size: 70))
                .foregroundColor(.lorcanaGold)

            Text("Rules Assistant")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text("Get instant answers to your Lorcana rules questions powered by AI")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            featureRow(
                icon: "sparkles",
                title: "AI-Powered Rules Help",
                description: "Ask any question about Lorcana rules and get accurate answers instantly"
            )

            featureRow(
                icon: "rectangle.stack.badge.plus",
                title: "Card-Aware Analysis",
                description: "Attach cards to your questions for specific rulings on card interactions"
            )

            featureRow(
                icon: "clock.arrow.circlepath",
                title: "Conversation History",
                description: "Save, pin, and revisit past rules conversations"
            )

            featureRow(
                icon: "book.fill",
                title: "Comprehensive Rules",
                description: "Based on the official Disney Lorcana Comprehensive Rules"
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.6))
        )
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.lorcanaGold)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - Packages

    private var packagesSection: some View {
        VStack(spacing: 12) {
            ForEach(subscriptionManager.offerings, id: \.identifier) { package in
                SubscriptionPackageCard(
                    package: package,
                    isPurchasing: purchasingPackageId == package.storeProduct.productIdentifier,
                    onTap: {
                        Task {
                            await purchasePackage(package)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button(action: {
            Task {
                do {
                    try await subscriptionManager.restorePurchases()
                    if subscriptionManager.isSubscribed {
                        showRestoreSuccess = true
                    } else {
                        showRestoreFailure = true
                    }
                } catch {
                    purchaseError = error.localizedDescription
                }
            }
        }) {
            if subscriptionManager.isRestoring {
                ProgressView()
                    .tint(.lorcanaGold)
            } else {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.lorcanaGold)
            }
        }
        .disabled(subscriptionManager.isRestoring)
    }

    // MARK: - Legal

    private var legalSection: some View {
        VStack(spacing: 6) {
            Text("Subscriptions will be charged to your Apple ID account. Subscriptions automatically renew unless canceled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption2)
                    .foregroundColor(.lorcanaGold.opacity(0.8))

                Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
                    .font(.caption2)
                    .foregroundColor(.lorcanaGold.opacity(0.8))
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Purchase

    private func purchasePackage(_ package: Package) async {
        purchasingPackageId = package.storeProduct.productIdentifier
        defer { purchasingPackageId = nil }

        do {
            let success = try await subscriptionManager.purchase(package)
            if success {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}

// MARK: - Subscription Package Card

struct SubscriptionPackageCard: View {
    let package: Package
    let isPurchasing: Bool
    let onTap: () -> Void

    private var isMonthly: Bool {
        package.packageType == .monthly || package.identifier.contains("monthly")
    }

    private var periodLabel: String {
        switch package.packageType {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .sixMonth:
            return "6 Months"
        case .threeMonth:
            return "3 Months"
        case .twoMonth:
            return "2 Months"
        case .weekly:
            return "Weekly"
        case .lifetime:
            return "Lifetime"
        default:
            return package.storeProduct.subscriptionPeriod?.periodTitle ?? "Subscribe"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodLabel)
                        .font(.headline)
                        .foregroundColor(.white)

                    if package.packageType == .annual {
                        Text("Best Value")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.lorcanaGold)
                            )
                    }
                }

                Spacer()

                if isPurchasing {
                    ProgressView()
                        .tint(.lorcanaGold)
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(package.storeProduct.localizedPriceString)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.lorcanaGold)

                        if package.packageType == .annual {
                            Text(monthlyPriceFromAnnual)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        package.packageType == .annual ? Color.lorcanaGold : Color.lorcanaGold.opacity(0.3),
                        lineWidth: package.packageType == .annual ? 2 : 1
                    )
            )
        }
        .disabled(isPurchasing)
    }

    private var monthlyPriceFromAnnual: String {
        let monthlyPrice = package.storeProduct.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = package.storeProduct.priceFormatStyle?.locale ?? .current
        return "\(formatter.string(from: monthlyPrice as NSDecimalNumber) ?? "")/mo"
    }
}

// MARK: - SubscriptionPeriod Helper

extension StoreProduct.SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:
            return value == 7 ? "Weekly" : "\(value) Day\(value == 1 ? "" : "s")"
        case .week:
            return value == 1 ? "Weekly" : "\(value) Weeks"
        case .month:
            switch value {
            case 1: return "Monthly"
            case 3: return "3 Months"
            case 6: return "6 Months"
            default: return "\(value) Months"
            }
        case .year:
            return value == 1 ? "Annual" : "\(value) Years"
        }
    }
}

#Preview {
    SubscriptionPaywallView()
}
