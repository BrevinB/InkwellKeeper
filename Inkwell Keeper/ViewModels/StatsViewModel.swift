//
//  StatsViewModel.swift
//  Inkwell Keeper
//
//  Aggregates the user's collection into chart-ready metrics for StatsView.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class StatsViewModel {
    private(set) var snapshot: CollectionStatsSnapshot = .empty

    /// Recompute the snapshot from the SwiftData model context.
    func refresh(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false }
            )
            let records = try context.fetch(descriptor)
            snapshot = Self.buildSnapshot(from: records)
        } catch {
            snapshot = .empty
        }
    }

    private static func buildSnapshot(from records: [CollectedCard]) -> CollectionStatsSnapshot {
        // Build a name→inkable lookup from the bundled card data so we can compute
        // inkable/non-inkable ratios even though CollectedCard doesn't persist the flag.
        let inkableLookup: [String: Bool] = {
            var lookup: [String: Bool] = [:]
            for card in SetsDataManager.shared.getAllCards() {
                guard let inkwell = card.inkwell else { continue }
                lookup[Self.inkableKey(name: card.name, setName: card.setName)] = inkwell
            }
            return lookup
        }()

        var totalCards = 0
        var uniqueCards = 0
        var totalValue: Double = 0
        var pricedCardCount = 0
        var rarityCounts: [CardRarity: Int] = [:]
        var inkColorCounts: [String: Int] = [:]
        var costCounts: [Int: Int] = [:]
        var typeCounts: [String: Int] = [:]
        var inkableCount = 0
        var nonInkableCount = 0
        var valueBySet: [String: Double] = [:]
        var topValuable: [TopValuableCard] = []
        var recentRecords: [(card: LorcanaCard, dateAdded: Date)] = []

        for record in records {
            let quantity = max(1, record.quantity)
            let card = record.toLorcanaCard
            totalCards += quantity
            uniqueCards += 1

            rarityCounts[record.cardRarity, default: 0] += quantity

            if let inkColor = record.inkColor, !inkColor.isEmpty {
                inkColorCounts[inkColor, default: 0] += quantity
            }

            let bucketedCost = min(record.cost, 10)
            costCounts[bucketedCost, default: 0] += quantity

            let typeKey = Self.primaryType(record.type)
            typeCounts[typeKey, default: 0] += quantity

            if let inkable = inkableLookup[Self.inkableKey(name: record.name, setName: record.setName)] {
                if inkable {
                    inkableCount += quantity
                } else {
                    nonInkableCount += quantity
                }
            }

            if let price = record.price, price > 0 {
                pricedCardCount += quantity
                let stackValue = price * Double(quantity)
                totalValue += stackValue
                valueBySet[record.setName, default: 0] += stackValue
                topValuable.append(TopValuableCard(card: card, unitPrice: price, quantity: quantity))
            }

            recentRecords.append((card: card, dateAdded: record.dateAdded))
        }

        let top10 = topValuable
            .sorted { $0.stackValue > $1.stackValue }
            .prefix(10)
            .map { $0 }

        let recentCards = recentRecords
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(5)
            .map(\.card)

        return CollectionStatsSnapshot(
            totalCards: totalCards,
            uniqueCards: uniqueCards,
            totalValue: totalValue,
            pricedCardCount: pricedCardCount,
            rarityCounts: rarityCounts,
            inkColorCounts: inkColorCounts,
            costCounts: costCounts,
            typeCounts: typeCounts,
            inkableCount: inkableCount,
            nonInkableCount: nonInkableCount,
            valueBySet: valueBySet,
            topValuable: Array(top10),
            recentCards: Array(recentCards)
        )
    }

    private static func inkableKey(name: String, setName: String) -> String {
        "\(name)||\(setName)"
    }

    private static func primaryType(_ raw: String) -> String {
        // Lorcana card types can be comma-separated (e.g. "Character - Storyborn").
        // We collapse to the first segment so counts stay coarse.
        let trimmed = raw.split(separator: ",").first.map(String.init) ?? raw
        let head = trimmed.split(separator: "-").first.map(String.init) ?? trimmed
        return head.trimmingCharacters(in: .whitespaces).capitalized
    }
}

struct CollectionStatsSnapshot {
    let totalCards: Int
    let uniqueCards: Int
    let totalValue: Double
    let pricedCardCount: Int
    let rarityCounts: [CardRarity: Int]
    let inkColorCounts: [String: Int]
    let costCounts: [Int: Int]
    let typeCounts: [String: Int]
    let inkableCount: Int
    let nonInkableCount: Int
    let valueBySet: [String: Double]
    let topValuable: [TopValuableCard]
    let recentCards: [LorcanaCard]

    static let empty = CollectionStatsSnapshot(
        totalCards: 0,
        uniqueCards: 0,
        totalValue: 0,
        pricedCardCount: 0,
        rarityCounts: [:],
        inkColorCounts: [:],
        costCounts: [:],
        typeCounts: [:],
        inkableCount: 0,
        nonInkableCount: 0,
        valueBySet: [:],
        topValuable: [],
        recentCards: []
    )

    var hasPricedCards: Bool { pricedCardCount > 0 }
    var unpricedCardCount: Int { max(0, totalCards - pricedCardCount) }

    var averageValuePerPricedCard: Double {
        guard pricedCardCount > 0 else { return 0 }
        return totalValue / Double(pricedCardCount)
    }

    var hasInkableData: Bool { inkableCount + nonInkableCount > 0 }
}

struct TopValuableCard: Identifiable, Hashable {
    let card: LorcanaCard
    let unitPrice: Double
    let quantity: Int

    var id: String { card.id }
    var stackValue: Double { unitPrice * Double(quantity) }
}
