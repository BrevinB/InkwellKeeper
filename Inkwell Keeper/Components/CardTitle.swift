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
    @State private var showingDetail = false
    @State private var showingCollectionDetail = false
    @State private var showingWishlistDetail = false
    @State private var marketPrice: Double?
    @State private var loadingPrice = false
    @State private var priceChange: Double?
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var pricingService = PricingService()
    
    private var collectedCard: CollectedCard? {
        collectionManager.getCollectedCardData(for: card)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            AsyncImage(url: URL(string: card.imageUrl)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
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
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(card.rarity.color, lineWidth: 2)
            )
            .overlay(
                // Quantity badge in top-right corner
                Group {
                    if let collected = collectedCard, collected.quantity > 1 {
                        VStack {
                            HStack {
                                Spacer()
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
                            Spacer()
                        }
                    }
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
                
                if let _ = marketPrice {
                    Button(action: {
                        openEbayListing()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "cart")
                                .font(.caption)
                            Text("Buy on eBay")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.8))
                        )
                    }
                }
                
                HStack {
                    if loadingPrice {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .foregroundColor(.lorcanaGold)
                            Text("Loading price...")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    } else if let price = marketPrice {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)
                                .fontWeight(.semibold)
                            
                            if let change = priceChange {
                                HStack(spacing: 2) {
                                    Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                                        .font(.caption2)
                                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : .gray)
                                    Text("\(abs(change), specifier: "%.1f")%")
                                        .font(.caption2)
                                        .foregroundColor(change > 0 ? .green : change < 0 ? .red : .gray)
                                }
                            }
                        }
                    } else if let price = card.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                            .fontWeight(.semibold)
                    } else {
                        Text("Price unavailable")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            // Price is already loaded when card is added to collection
            // Just use the cached price from the card object
            if let price = card.price {
                self.marketPrice = price
            }
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
        
        do {
            let price = await pricingService.getMarketPrice(for: card)
            let priceChangeInfo = pricingService.getRecentPriceChange(for: card)
            
            await MainActor.run {
                self.marketPrice = price
                self.priceChange = priceChangeInfo.changePercent
                self.loadingPrice = false
                
                if let changePercent = priceChangeInfo.changePercent {
                }
            }
        } catch {
            await MainActor.run {
                self.loadingPrice = false
            }
        }
    }
    
    private func openEbayListing() {
        if let affiliateLink = pricingService.generateEbayAffiliateLink(for: card) {
            if let url = URL(string: affiliateLink) {
                UIApplication.shared.open(url)
            }
        } else {
            // Fallback to regular eBay search if no affiliate setup
            let searchQuery = "\(card.name) Lorcana \(card.setName)"
            let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let regularLink = "https://www.ebay.com/sch/i.html?_nkw=\(encodedQuery)&_sacat=183454"
            
            if let url = URL(string: regularLink) {
                UIApplication.shared.open(url)
            }
        }
    }
}
