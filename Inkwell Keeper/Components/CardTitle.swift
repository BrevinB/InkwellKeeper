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
    @State private var imageLoadTrigger = UUID() // Force image reload
    @EnvironmentObject var collectionManager: CollectionManager
    @ObservedObject private var motionManager = MotionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pricingService = PricingService.shared
    
    private var collectedCard: CollectedCard? {
        collectionManager.getCollectedCardData(for: card)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: card.bestImageUrl()) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .interactiveHolographicEffect(
                            pitch: reduceMotion ? 0 : motionManager.pitch,
                            roll: reduceMotion ? 0 : motionManager.roll,
                            variant: card.variant
                        )
                case .failure(let error):
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [card.rarity.color.opacity(0.3), card.rarity.color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.artframe")
                                    .font(.largeTitle)
                                    .foregroundColor(card.rarity.color)
                                Text(card.name)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .padding()
                        }
                        .onAppear {
                        }
                case .empty:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "photo")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                @unknown default:
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "questionmark")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                }
            }
            .id("\(imageLoadTrigger)")  // Force reload when trigger changes
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(card.rarity.color, lineWidth: 2)
            )
            .overlay(
                // Badges in top corners
                VStack {
                    HStack {
                        // Reprint badge in top-left
                        if let reprintCount = reprintCount, reprintCount > 1 {
                            HStack(spacing: 3) {
                                Image(systemName: "square.on.square")
                                    .font(.caption2)
                                Text("\(reprintCount)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.9))
                            )
                            .padding(6)
                        }

                        Spacer()

                        // Quantity badge in top-right corner
                        if let collected = collectedCard, collected.quantity > 1 {
                            Text("\(collected.quantity)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.lorcanaGold.opacity(0.9))
                                )
                                .padding(6)
                        }
                    }
                    Spacer()
                }
            )
            
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
            // Price is already loaded when card is added to collection
            // Just use the cached price from the card object
            if let price = card.price {
                self.marketPrice = price
            }
            // Force image reload by generating new trigger
            imageLoadTrigger = UUID()
            // Start motion updates for holographic effect
            if !reduceMotion {
                motionManager.start()
            }
        }
        .onDisappear {
            motionManager.stop()
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
