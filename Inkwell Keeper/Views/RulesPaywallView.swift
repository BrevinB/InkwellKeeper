//
//  RulesPaywallView.swift
//  Inkwell Keeper
//
//  Subscription paywall for the Rules Assistant feature
//

import SwiftUI
import RevenueCat

struct RulesPaywallView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 20)

                // Hero icon
                Image(systemName: "book.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.lorcanaGold)

                // Title and description
                VStack(spacing: 12) {
                    Text("Rules Assistant Pro")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Get instant, AI-powered answers to any Disney Lorcana rules question.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "sparkles", title: "AI Rules Expert", description: "Ask any rules question and get accurate answers with rule citations")
                    featureRow(icon: "rectangle.stack.badge.plus", title: "Card Analysis", description: "Attach up to 4 cards to ask about specific interactions")
                    featureRow(icon: "bubble.left.and.bubble.right", title: "Chat History", description: "Save, pin, and revisit your past conversations")
                    featureRow(icon: "bolt.fill", title: "Streaming Responses", description: "See answers as they're generated in real time")
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // Subscription options
                if subscriptionManager.isLoading && subscriptionManager.currentOffering == nil {
                    ProgressView()
                        .tint(.lorcanaGold)
                        .padding()
                } else if let offering = subscriptionManager.currentOffering {
                    VStack(spacing: 12) {
                        ForEach(offering.availablePackages, id: \.identifier) { package in
                            SubscriptionOptionCard(
                                package: package,
                                isSelected: selectedPackage?.identifier == package.identifier,
                                onTap: { selectedPackage = package }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Subscribe button
                Button(action: {
                    guard let package = selectedPackage else { return }
                    Task { await purchase(package) }
                }) {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Subscribe Now")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedPackage != nil ? Color.lorcanaGold : Color.gray.opacity(0.4))
                    )
                    .foregroundColor(selectedPackage != nil ? .black : .gray)
                }
                .disabled(selectedPackage == nil || isPurchasing)
                .padding(.horizontal, 24)

                // Restore purchases
                Button(action: {
                    Task { await restore() }
                }) {
                    Text("Restore Purchases")
                        .font(.subheadline)
                        .foregroundColor(.lorcanaGold.opacity(0.8))
                }
                .disabled(isPurchasing)

                // Legal
                VStack(spacing: 6) {
                    Text("Subscriptions auto-renew unless cancelled at least 24 hours before the end of the current period. Manage subscriptions in Settings.")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 16) {
                        Link("Privacy Policy", destination: URL(string: "https://inkwellkeeper.app/privacy")!)
                            .font(.caption2)
                            .foregroundColor(.lorcanaGold.opacity(0.6))

                        Link("Terms of Use", destination: URL(string: "https://inkwellkeeper.app/terms")!)
                            .font(.caption2)
                            .foregroundColor(.lorcanaGold.opacity(0.6))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
        .background(LorcanaBackground())
        .task {
            await subscriptionManager.loadOfferings()
            // Auto-select the first package if available
            if selectedPackage == nil,
               let first = subscriptionManager.currentOffering?.availablePackages.first {
                selectedPackage = first
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { subscriptionManager.error = nil }
        } message: {
            Text(subscriptionManager.error ?? "An unknown error occurred.")
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.lorcanaGold)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
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

    private func purchase(_ package: Package) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let success = try await subscriptionManager.purchase(package)
            if !success {
                // User cancelled — no error needed
            }
        } catch {
            showError = true
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            showError = true
        }
    }
}

// MARK: - Subscription Option Card

struct SubscriptionOptionCard: View {
    let package: Package
    let isSelected: Bool
    let onTap: () -> Void

    private var periodLabel: String {
        switch package.packageType {
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .twoMonth:
            return "2 Months"
        case .threeMonth:
            return "3 Months"
        case .sixMonth:
            return "6 Months"
        case .annual:
            return "Yearly"
        case .lifetime:
            return "Lifetime"
        default:
            return package.storeProduct.subscriptionPeriod?.periodTitle ?? "Subscription"
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodLabel)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let intro = package.storeProduct.introductoryDiscount {
                        Text(introText(for: intro))
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                    }
                }

                Spacer()

                Text(package.localizedPriceString)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.lorcanaGold)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.lorcanaGold : Color.lorcanaGold.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }

    private func introText(for discount: StoreProductDiscount) -> String {
        switch discount.paymentMode {
        case .freeTrial:
            return "Free trial included"
        case .payUpFront:
            return "Introductory offer"
        case .payAsYouGo:
            return "Special introductory price"
        @unknown default:
            return ""
        }
    }
}

// MARK: - Subscription Period Title

extension StoreProduct.SubscriptionPeriod {
    var periodTitle: String {
        switch unit {
        case .day:
            return value == 7 ? "Weekly" : "\(value)-Day"
        case .week:
            return value == 1 ? "Weekly" : "\(value)-Week"
        case .month:
            switch value {
            case 1: return "Monthly"
            case 2: return "2 Months"
            case 3: return "3 Months"
            case 6: return "6 Months"
            default: return "\(value)-Month"
            }
        case .year:
            return value == 1 ? "Yearly" : "\(value)-Year"
        @unknown default:
            return "Subscription"
        }
    }
}

#Preview {
    RulesPaywallView()
}
