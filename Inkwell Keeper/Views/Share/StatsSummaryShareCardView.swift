//
//  StatsSummaryShareCardView.swift
//  Inkwell Keeper
//
//  "My Collection in Review" share-card template, driven entirely by a CollectionStatsSnapshot.
//  Presentation-only and rendered off-screen by `ShareImageRenderer`.
//

import SwiftUI

struct StatsSummaryShareCardView: View {
    let snapshot: CollectionStatsSnapshot
    var currencyCode: String = "USD"

    /// Rarities present in the collection, ordered common → enchanted, with their counts.
    private var rarityRows: [(rarity: CardRarity, count: Int)] {
        CardRarity.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { rarity in
                guard let count = snapshot.rarityCounts[rarity], count > 0 else { return nil }
                return (rarity, count)
            }
    }

    private var maxRarityCount: Int {
        max(1, rarityRows.map(\.count).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Collection")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("in Review")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
            }

            HStack(spacing: 10) {
                StatTile(value: snapshot.totalCards.formatted(.number), label: "Cards")
                StatTile(value: snapshot.uniqueCards.formatted(.number), label: "Unique")
                if snapshot.hasPricedCards {
                    StatTile(
                        value: snapshot.totalValue.formatted(
                            .currency(code: currencyCode).precision(.fractionLength(0))
                        ),
                        label: "Value"
                    )
                }
            }

            if !rarityRows.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("By Rarity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(rarityRows, id: \.rarity) { row in
                        RarityBar(
                            rarity: row.rarity,
                            count: row.count,
                            fraction: Double(row.count) / Double(maxRarityCount)
                        )
                    }
                }
            }

            if let top = snapshot.topValuable.first {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.lorcanaGold)
                    Text("Top card: \(top.card.name)")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One of the three headline metric tiles.
private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
    }
}

/// A single horizontal rarity bar. The card canvas is a fixed width, so the bar track width
/// is deterministic — no GeometryReader needed.
private struct RarityBar: View {
    let rarity: CardRarity
    let count: Int
    let fraction: Double

    /// Track width that fits within the fixed 360pt card after labels and padding.
    private let trackWidth: CGFloat = 168

    var body: some View {
        HStack(spacing: 8) {
            Text(rarity.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(width: trackWidth, height: 10)
                Capsule()
                    .fill(rarity.color)
                    .frame(width: max(4, trackWidth * fraction), height: 10)
            }

            Text(count.formatted(.number))
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 32, alignment: .trailing)
        }
    }
}
