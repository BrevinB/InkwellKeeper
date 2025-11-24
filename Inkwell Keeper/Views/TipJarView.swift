//
//  TipJarView.swift
//  Inkwell Keeper
//
//  Tip jar UI for supporting app development
//

import SwiftUI
import RevenueCat
import Combine

struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tipManager = TipJarManager.shared

    @State private var selectedPackage: Package?
    @State private var purchasingPackageId: String?
    @State private var showThankYou = false
    @State private var purchaseError: String?

    var body: some View {
        navigationWrapper {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Tip Options
                    if tipManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        tipOptionsSection
                    }

                    // Footer Message
                    footerSection
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle("Support Development")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await tipManager.loadOfferings()
            }
            .alert("Thank You! 🎉", isPresented: $showThankYou) {
                Button("You're Welcome!") { }
            } message: {
                Text("Your support means the world and helps keep Ink Well Keeper free for everyone!")
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
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold)

            Text("Support Ink Well Keeper")
                .font(.title2)
                .fontWeight(.bold)

            Text("Ink Well Keeper is free with no ads. If you find it useful, consider leaving a tip to support development!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    private var tipOptionsSection: some View {
        VStack(spacing: 16) {
            ForEach(TipProduct.tiers) { product in
                if let package = tipManager.offerings.first(where: { package in
                    package.storeProduct.productIdentifier.contains(product.id) ||
                    product.id.contains(package.identifier)
                }) {
                    TipOptionCard(
                        product: product,
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
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Tips are optional and do not unlock any features.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Text("All Lorcana content remains free per Ravensburger's Community Code Policy.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    private func purchasePackage(_ package: Package) async {
        purchasingPackageId = package.storeProduct.productIdentifier
        defer { purchasingPackageId = nil }

        do {
            let success = try await tipManager.purchase(package)
            if success {
                showThankYou = true
            }
            // If not success, user cancelled - no message needed
        } catch {
            // Show error for purchase failures
            purchaseError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        } else {
            NavigationView {
                content()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                dismiss()
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Tip Option Card

struct TipOptionCard: View {
    let product: TipProduct
    let package: Package
    let isPurchasing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Emoji icon
                Text(product.emoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.message)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(product.title)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Price
                if isPurchasing {
                    ProgressView()
                        .tint(.lorcanaGold)
                } else {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.lorcanaGold)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6).opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isPurchasing)
    }
}

#Preview {
    TipJarView()
}
