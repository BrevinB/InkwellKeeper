//
//  BuyCardButton.swift
//  Inkwell Keeper
//
//  Displays card pricing and buy options with affiliate links
//

import SwiftUI

struct BuyCardOptionsView: View {
    let card: LorcanaCard
    @State private var buyOptions: [AffiliateService.BuyOption] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Prices")
                .font(.headline)
                .foregroundColor(.lorcanaGold)

            ForEach(buyOptions.indices, id: \.self) { index in
                let option = buyOptions[index]

                Button(action: {
                    AffiliateService.shared.trackAffiliateClick(
                        platform: option.platform,
                        cardName: card.name
                    )
                    if let url = option.url as? URL {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.platform)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)

                            if let price = option.price {
                                Text("From $\(price, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("View Prices →")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.lorcanaGold)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.lorcanaDark.opacity(0.6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }

            if buyOptions.isEmpty {
                Text("Buy options loading...")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .onAppear {
            loadBuyOptions()
        }
    }

    private func loadBuyOptions() {
        buyOptions = AffiliateService.shared.getBuyOptions(for: card)
    }
}

/// Compact buy button for card tiles
struct CompactBuyButton: View {
    let card: LorcanaCard
    @State private var showingOptions = false

    var body: some View {
        Button(action: {
            showingOptions = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle")
                Text("Check Prices")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.lorcanaGold)
            .cornerRadius(8)
        }
        .sheet(isPresented: $showingOptions) {
            BuyCardSheet(card: card)
        }
    }
}

/// Full-screen buy options sheet
struct BuyCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let card: LorcanaCard

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Card preview
                HStack(spacing: 16) {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 80, height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        RarityBadge(rarity: card.rarity)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )

                BuyCardOptionsView(card: card)

                Spacer()

                Text("Prices shown are from affiliated retailers.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .background(LorcanaBackground())
            .navigationTitle("Check Prices")
            .navigationBarTitleDisplayMode(.inline)
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
