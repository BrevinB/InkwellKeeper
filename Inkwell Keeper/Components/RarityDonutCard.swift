//
//  RarityDonutCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct RarityDonutCard: View {
    let counts: [CardRarity: Int]

    private var entries: [Entry] {
        CardRarity.allCases.compactMap { rarity in
            guard let count = counts[rarity], count > 0 else { return nil }
            return Entry(rarity: rarity, count: count)
        }
    }

    private var totalCount: Int {
        entries.map(\.count).reduce(0, +)
    }

    var body: some View {
        StatsCardContainer(title: "Rarity Breakdown", subtitle: "How your collection splits by rarity") {
            if entries.isEmpty {
                StatsEmptyState(message: "No cards collected yet.")
            } else {
                HStack(alignment: .center, spacing: 16) {
                    chart
                        .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(entry.rarity.color)
                                    .frame(width: 10, height: 10)
                                Text(entry.rarity.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Spacer(minLength: 8)
                                Text("\(entry.count)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
    }

    private var chart: some View {
        Chart(entries) { entry in
            SectorMark(
                angle: .value("Count", entry.count),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(entry.rarity.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .overlay {
            VStack(spacing: 2) {
                Text("\(totalCount)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(.white)
                Text("cards")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }
        }
    }

    private struct Entry: Identifiable {
        let rarity: CardRarity
        let count: Int
        var id: CardRarity { rarity }
    }
}
