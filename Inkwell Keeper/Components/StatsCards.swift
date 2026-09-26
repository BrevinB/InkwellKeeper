//
//  StatsCards.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct RecentAdditionsCard: View {
    let recentCards: [LorcanaCard]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Additions")
                .font(.headline)
                .foregroundStyle(.white)
            
            if recentCards.isEmpty {
                Text("No recent additions")
                    .foregroundStyle(.gray)
                    .padding(.vertical)
            } else {
                ForEach(recentCards.prefix(3)) { card in
                    HStack {
                        AsyncImage(url: card.bestImageUrl()) { image in
                            image
                                .resizable().scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 30, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Text(card.name)
                            .font(.subheadline)
                            .foregroundStyle(.white)
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
    @Environment(CollectionManager.self) var collectionManager
    private let dataManager = SetsDataManager.shared
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
        "Winterspell",
        "Wilds Unknown"
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
    @State private var showingShare = false

    private var percentage: Double {
        total > 0 ? Double(current) / Double(total) : 0
    }

    /// A completed set is a bigger flex than partial progress.
    private var milestone: ShareMilestone {
        current >= total && total > 0
            ? .setCompleted(name: setName)
            : .setProgress(name: setName, percentage: percentage)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(setName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(current)/\(total)")
                    .font(.caption)
                    .foregroundStyle(.gray)
                Button("Share \(setName) progress", systemImage: "square.and.arrow.up") {
                    showingShare = true
                }
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.lorcanaGold)
                .buttonStyle(.plain)
            }

            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .lorcanaGold))
                .scaleEffect(x: 1, y: 0.5)
        }
        .sheet(isPresented: $showingShare) {
            ShareCardPresenter(
                analyticsType: "milestone",
                qrPayload: AppLinks.appStoreURLString,
                fileName: "InkwellKeeper-\(setName)"
            ) { _ in
                MilestoneShareCardView(milestone: milestone)
            }
        }
    }
}

struct CollectionStatsButton: View {
    @Environment(CollectionManager.self) var collectionManager

    private var stats: (totalValue: Double, cardCount: Int, rarityBreakdown: [CardRarity: Int]) {
        collectionManager.getCollectionStats()
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if stats.totalValue > 0 {
                Text(PricingService.formatPrice(stats.totalValue))
                    .font(.headline)
                    .foregroundStyle(Color.lorcanaGold)
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(.gray)
            }
            Text("\(stats.cardCount) cards")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }
}
