//
//  WishlistComponents.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct WishlistCardRow: View {
    let card: LorcanaCard
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var showingDetail = false
    
    var body: some View {
        HStack {
            AsyncImage(url: card.bestImageUrl()) { image in
                Group {
                    if card.variant == .foil {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foilEffect(isAnimated: true)
                    } else {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 60, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(card.rarity.color, lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
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
                    
                    CostBadge(cost: card.cost)
                    Spacer()
                }
                
                if let price = card.price {
                    PriceWithConfidenceView(
                        price: price,
                        confidence: .estimated,
                        style: .inline
                    )
                }

                // Buy button for wishlist cards
                CompactBuyButton(card: card)
                    .padding(.top, 4)
            }

            Spacer()
            
            VStack(spacing: 8) {
                Button(action: {
                    collectionManager.addCard(card, quantity: 1)
                    collectionManager.removeFromWishlist(card)
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    collectionManager.removeFromWishlist(card)
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            WishlistCardDetailView(card: card, isPresented: $showingDetail)
                .environmentObject(collectionManager)
        }
    }
}
