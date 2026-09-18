//
//  RulesPaywallView.swift
//  Inkwell Keeper
//
//  Subscription paywall. What it leads with depends on where it was opened
//  from — see PaywallContext — while the full feature list stays visible so
//  the whole subscription is always on show.
//

import SwiftUI
import RevenueCat

struct RulesPaywallView: View {
    /// Which surface showed the paywall ("rulesTab", "cardAsk", "deckBuilder", …) so
    /// conversion can be attributed per funnel.
    var source: String = "rulesPro"

    private var context: PaywallContext { .forSource(source) }

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var showingPrivacyPolicy = false
    @State private var restoreMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            pitch

            PaywallPurchaseFooter(
                offering: subscriptionManager.currentOffering,
                isLoadingOffering: subscriptionManager.isLoading,
                isPurchasing: isPurchasing,
                selectedPackage: $selectedPackage,
                onSubscribe: {
                    guard let package = selectedPackage else { return }
                    Task { await purchase(package) }
                },
                onRestore: { Task { await restore() } },
                onPrivacyPolicy: { showingPrivacyPolicy = true }
            )
        }
        .background(LorcanaBackground())
        .onAppear {
            Analytics.send(.paywallShown(source: source))
        }
        .task {
            await subscriptionManager.loadOfferings()
            // Auto-select the first package if available
            if selectedPackage == nil,
               let first = subscriptionManager.currentOffering?.availablePackages.first {
                selectedPackage = first
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .alert(
            "Restore Purchases",
            isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )
        ) {
            Button("OK") { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { subscriptionManager.error = nil }
        } message: {
            Text(subscriptionManager.error ?? "An unknown error occurred.")
        }
    }

    /// Everything above the pinned pricing: the hero, the features this context
    /// leads with, the rest of the subscription, and the legal text.
    private var pitch: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer().frame(height: 8)

                // Hero icon
                Image(systemName: context.heroIcon)
                    .font(.system(size: 62))
                    .foregroundStyle(.lorcanaGold)

                // Title and description
                VStack(spacing: 12) {
                    Text(context.headline)
                        .font(.title)
                        .bold()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(context.subheadline)
                        .font(.body)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // What this surface is about, spelled out.
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(context.leadFeatures) { feature in
                        featureRow(
                            icon: feature.icon,
                            title: feature.title,
                            description: feature.description
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                // The rest of the subscription, compact — the pitch is
                // tailored but the value on offer is not.
                PaywallSupportingFeatures(features: context.supportingFeatures)
                    .padding(.horizontal, 24)

                // Official rules link
                Link(destination: URL(string: "https://www.disneylorcana.com/en-US/resources#checks-and-balances")!) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                        Text("Read the Official Rules")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                }

            }
            // Keeps the last row of the pitch clear of the pinned footer.
            .padding(.bottom, 16)
        }
        .scrollIndicators(.hidden)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.94),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.lorcanaGold)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.gray)
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
            // Restoring nothing is the common case and used to look like the
            // button was dead, which is a thing App Review checks.
            restoreMessage = subscriptionManager.isSubscribed
                ? "Your subscription has been restored."
                : "No previous purchases were found for this Apple Account."
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
                        .foregroundStyle(.white)

                    if let intro = package.storeProduct.introductoryDiscount {
                        Text(introText(for: intro))
                            .font(.caption)
                            .foregroundStyle(.lorcanaGold)
                    }
                }

                Spacer()

                Text(package.localizedPriceString)
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.4))
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

extension SubscriptionPeriod {
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
