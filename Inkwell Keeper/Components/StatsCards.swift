//
//  StatsCards.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CollectionOverviewCard: View {
    let totalCards: Int
    let totalValue: Double
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Collection Overview")
                .font(.headline)
                .foregroundColor(.white)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(totalCards)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.lorcanaGold)
                    Text("Cards")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                VStack {
                    Text(PricingService.formatPrice(totalValue))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.lorcanaGold)
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RarityBreakdownCard: View {
    let cardsByRarity: [(CardRarity, Int)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rarity Breakdown")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(cardsByRarity, id: \.0) { rarity, count in
                HStack {
                    RarityBadge(rarity: rarity)
                    Spacer()
                    Text("\(count)")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct RecentAdditionsCard: View {
    let recentCards: [LorcanaCard]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Additions")
                .font(.headline)
                .foregroundColor(.white)
            
            if recentCards.isEmpty {
                Text("No recent additions")
                    .foregroundColor(.gray)
                    .padding(.vertical)
            } else {
                ForEach(recentCards.prefix(3)) { card in
                    HStack {
                        AsyncImage(url: card.bestImageUrl()) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 30, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(card.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        RarityBadge(rarity: card.rarity)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct SetCompletionCard: View {
    let cards: [LorcanaCard]
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var cachedProgress: [(name: String, collected: Int, total: Int)] = []

    private static let allSets = [
        "The First Chapter",
        "Rise of the Floodborn",
        "Into the Inklands",
        "Ursula's Return",
        "Shimmering Skies",
        "Azurite Sea",
        "Archazia's Island",
        "Reign of Jafar",
        "Fabled",
        "Whispers in the Well",
        "Winterspell"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set Completion")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                ForEach(cachedProgress, id: \.name) { progress in
                    SetProgressRow(
                        setName: progress.name,
                        current: progress.collected,
                        total: progress.total
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear { recomputeProgress() }
        .onChange(of: collectionManager.collectedCards.count) { recomputeProgress() }
    }

    private func recomputeProgress() {
        cachedProgress = Self.allSets.enumerated().compactMap { index, setName in
            let totalCards = dataManager.hasLocalCards(for: setName) ?
                dataManager.getLocalCardCount(for: setName) : 204
            let progress = collectionManager.getSetProgress(setName, totalCardsInSet: totalCards)

            guard progress.collected > 0 || index < 3 else {
                return nil
            }

            return (name: setName, collected: progress.collected, total: progress.total)
        }
    }
}

struct SetProgressRow: View {
    let setName: String
    let current: Int
    let total: Int
    
    private var percentage: Double {
        Double(current) / Double(total)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(setName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .lorcanaGold))
                .scaleEffect(x: 1, y: 0.5)
        }
    }
}

struct CollectionStatsButton: View {
    @EnvironmentObject var collectionManager: CollectionManager
    
    private var stats: (totalValue: Double, cardCount: Int, rarityBreakdown: [CardRarity: Int]) {
        collectionManager.getCollectionStats()
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(PricingService.formatPrice(stats.totalValue))
                .font(.headline)
                .foregroundColor(.lorcanaGold)
            Text("\(stats.cardCount) cards")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}
