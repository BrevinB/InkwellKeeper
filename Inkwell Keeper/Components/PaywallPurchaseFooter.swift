//
//  PaywallPurchaseFooter.swift
//  Inkwell Keeper
//
//  Pricing and the subscribe button, pinned below the paywall's scrolling
//  pitch.
//
//  It used to scroll with everything else, which left the price and the
//  Subscribe button below the fold on arrival — and on the surfaces that render
//  the paywall inline inside a tab, behind the floating tab bar. Someone
//  deciding whether to pay should never have to go looking for the price.
//

import SwiftUI
import RevenueCat

struct PaywallPurchaseFooter: View {
    let offering: Offering?
    let isLoadingOffering: Bool
    let isPurchasing: Bool
    @Binding var selectedPackage: Package?
    let onSubscribe: () -> Void
    let onRestore: () -> Void
    let onPrivacyPolicy: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if isLoadingOffering && offering == nil {
                ProgressView()
                    .tint(.lorcanaGold)
                    .padding(.vertical, 8)
            } else if let offering {
                ForEach(offering.availablePackages, id: \.identifier) { package in
                    SubscriptionOptionCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        onTap: { selectedPackage = package }
                    )
                }
            }

            Button(action: onSubscribe) {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.black)
                    } else {
                        Text("Subscribe Now").bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selectedPackage != nil ? Color.lorcanaGold : Color.gray.opacity(0.4))
                )
                .foregroundStyle(selectedPackage != nil ? .black : .gray)
            }
            .disabled(selectedPackage == nil || isPurchasing)

            // App Review 3.1.2 wants the renewal terms and the Terms/Privacy
            // links on the purchase screen. They used to live at the end of the
            // scrolling pitch, which put them behind this footer; beside the
            // price they are always on screen, which is also where a reader
            // looking for them would expect them.
            //
            // Restore sits on the same row to keep this footer short — it was
            // tall enough to clip the pitch above it.
            PaywallSecondaryActions(
                isPurchasing: isPurchasing,
                onRestore: onRestore,
                onPrivacyPolicy: onPrivacyPolicy
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

/// Caption-sized labels keep the footer short, so each control has to claim the
/// 44pt minimum touch target itself — putting it on the row that holds them
/// left three 14pt targets.
private struct PaywallTapTarget: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .frame(minHeight: 44)
            .contentShape(.rect)
    }
}

/// Restore, Privacy and Terms on one row, then the renewal terms.
///
/// The row is held at the 44pt minimum touch target: the labels are caption-sized
/// so the footer stays short, which would otherwise leave three 13pt tap targets.
private struct PaywallSecondaryActions: View {
    let isPurchasing: Bool
    let onRestore: () -> Void
    let onPrivacyPolicy: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 8) {
                Button("Restore", action: onRestore)
                    .disabled(isPurchasing)
                    .modifier(PaywallTapTarget())

                Button("Privacy Policy", action: onPrivacyPolicy)
                    .modifier(PaywallTapTarget())

                Link(
                    "Terms of Use",
                    destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
                )
                .modifier(PaywallTapTarget())
            }
            .font(.caption)
            .foregroundStyle(.lorcanaGold.opacity(0.85))
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            Text("Auto-renews until cancelled at least 24 hours before the period ends. Manage in Settings.")
                .font(.caption2)
                .foregroundStyle(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
    }
}
