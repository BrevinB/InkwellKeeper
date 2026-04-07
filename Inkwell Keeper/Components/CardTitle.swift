//
//  CardTitle.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CardTile: View {
    let card: LorcanaCard
    let isWishlist: Bool
    var reprintCount: Int? = nil // Optional: number of sets this card appears in
    @State private var showingDetail = false
    @State private var showingCollectionDetail = false
    @State private var showingWishlistDetail = false
    @State private var marketPrice: Double?
    @State private var loadingPrice = false
    @State private var priceChange: Double?
    @State private var priceConfidence: PricingService.PriceConfidence?
    @State private var cachedCollectedCard: CollectedCard?
    @State private var cachedDeckAllocation: Int = 0
    @EnvironmentObject var collectionManager: CollectionManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pricingService = PricingService.shared

    private var availableQuantity: Int {
        guard let collected = cachedCollectedCard else { return 0 }
        return max(0, collected.quantity - cachedDeckAllocation)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HolographicCardImage(card: card, reduceMotion: reduceMotion)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(card.rarity.color, lineWidth: 2)
                )
                .overlay(alignment: .top) {
                    cardBadgeOverlay
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack {
                    RarityBadge(rarity: card.rarity)
                    
                    // Show variant badge for non-normal variants
                    if card.variant != .normal {
                        Text(card.variant.shortName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.purple.opacity(0.8))
                            )
                    }
                    
                    Spacer()
                    CostBadge(cost: card.cost)
                }
                
                // Price/buy button removed from tile view - available in detail view
            }
        }
        .onAppear {
            if let price = card.price {
                self.marketPrice = price
            }
            refreshCardData()
        }
        .onChange(of: collectionManager.collectedCards.count) {
            refreshCardData()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: card.rarity.color.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(showingDetail ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showingDetail = true
            }

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showingDetail = false
                }
                if isWishlist {
                    showingWishlistDetail = true
                } else {
                    showingCollectionDetail = true
                }
            }
        }
        .sheet(isPresented: $showingCollectionDetail) {
            CollectionCardDetailView(card: card, isPresented: $showingCollectionDetail)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingWishlistDetail) {
            WishlistCardDetailView(card: card, isPresented: $showingWishlistDetail)
                .environmentObject(collectionManager)
        }
    }
    
    @ViewBuilder
    private var cardBadgeOverlay: some View {
        HStack {
            if let reprintCount = reprintCount, reprintCount > 1 {
                HStack(spacing: 3) {
                    Image(systemName: "square.on.square")
                        .font(.caption2)
                    Text("\(reprintCount)")
                        .font(.caption2)
                        .bold()
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.blue.opacity(0.9)))
                .padding(6)
            }

            Spacer()

            if let collected = cachedCollectedCard, (collected.quantity > 1 || cachedDeckAllocation > 0) {
                VStack(spacing: 2) {
                    if collected.quantity > 1 {
                        Text("\(collected.quantity)")
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.lorcanaGold.opacity(0.9)))
                    }

                    if cachedDeckAllocation > 0 {
                        Text("\(availableQuantity) free")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(availableQuantity > 0 ? .green : .red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                }
                .padding(6)
            }
        }
    }

    private func refreshCardData() {
        if card.variant == .normal || card.variant == .foil {
            cachedCollectedCard = collectionManager.getCollectedCardDataForVariant(card)
        } else {
            cachedCollectedCard = collectionManager.getCollectedCardData(for: card)
        }
        cachedDeckAllocation = collectionManager.getTotalDeckAllocation(for: card)
    }

    private func loadMarketPrice() async {
        loadingPrice = true

        let priceData = await pricingService.getPriceWithConfidence(for: card)
        let priceChangeInfo = pricingService.getRecentPriceChange(for: card)

        await MainActor.run {
            self.marketPrice = priceData.price
            self.priceConfidence = priceData.confidence
            self.priceChange = priceChangeInfo.changePercent
            self.loadingPrice = false
        }
    }
}
