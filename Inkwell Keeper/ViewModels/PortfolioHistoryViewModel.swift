//
//  PortfolioHistoryViewModel.swift
//  Inkwell Keeper
//
//  Loads the collection's price history once and serves every portfolio card
//  on the Stats screen from it. The maths lives in PortfolioHistoryBuilder and
//  PortfolioInsightsBuilder; this type owns fetching, caching and state.
//
//  StatsView holds one instance and passes it to each card so the several
//  hundred KB of history is fetched once per visit rather than once per card.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class PortfolioHistoryViewModel {
    private(set) var points: [PortfolioPoint] = []
    private(set) var summary: PortfolioSummary = .empty
    private(set) var movers: [PortfolioMover] = []
    private(set) var extremes: [PortfolioExtreme] = []
    private(set) var variantSplit: PortfolioVariantSplit = .empty
    private(set) var costBasis: CostBasisSummary = .empty
    private(set) var costBasisEntries: [CostBasisEntry] = []
    private(set) var isLoading = false
    private(set) var hasLoadedOnce = false

    /// Window the chart covers. The backend holds daily prices from mid-May
    /// 2026, so a longer window simply starts where the data does.
    static let windowDays = 180
    /// Trailing window for "what moved", matching the card's weekly framing.
    static let moverDays = 7

    private let pricingService: PricingService
    private let cache: PortfolioHistoryCache
    private var lastHoldingsSignature: Int?

    init(
        pricingService: PricingService = .shared,
        cache: PortfolioHistoryCache = PortfolioHistoryCache()
    ) {
        self.pricingService = pricingService
        self.cache = cache
    }

    var weeklyChange: Double? {
        PortfolioHistoryBuilder.change(in: points, overTrailing: Self.moverDays)
    }

    var gainers: [PortfolioMover] { movers.filter(\.isGain) }
    var losers: [PortfolioMover] { movers.filter { !$0.isGain } }
    var highs: [PortfolioExtreme] { extremes.filter { $0.kind == .high } }
    var lows: [PortfolioExtreme] { extremes.filter { $0.kind == .low } }

    /// Collapses the collection to one holding per printing — the same card in
    /// two conditions is two rows but one series.
    static func holdings(from cards: [CollectedCard]) -> [PortfolioHolding] {
        var quantities: [String: Int] = [:]
        var details: [String: (name: String, isFoil: Bool)] = [:]
        for card in cards {
            let lorcanaCard = card.toLorcanaCard
            let key = lorcanaCard.variantAwareId
            quantities[key, default: 0] += card.quantity
            if details[key] == nil {
                details[key] = (lorcanaCard.name, lorcanaCard.variant != .normal)
            }
        }
        return quantities.map { key, quantity in
            PortfolioHolding(
                cardKey: key,
                quantity: quantity,
                name: details[key]?.name ?? "",
                isFoil: details[key]?.isFoil ?? false
            )
        }
    }

    func load(cards: [CollectedCard], force: Bool = false) async {
        guard !isLoading else { return }

        let holdings = Self.holdings(from: cards)
        let signature = holdings.sorted { $0.cardKey < $1.cardKey }.hashValue

        // Re-fetching costs a few seconds of backend time, so only do it when
        // the collection actually changed or the cached series went stale.
        if !force, signature == lastHoldingsSignature, hasLoadedOnce { return }

        if !force, let cached = cache.load(signature: signature) {
            apply(series: cached, holdings: holdings)
            applyCostBasis(cards: cards, series: cached)
            lastHoldingsSignature = signature
            return
        }

        isLoading = true
        defer { isLoading = false }

        let printings = uniquePrintings(from: cards)
        let series = await pricingService.fetchBulkHistory(for: printings, days: Self.windowDays)
        guard !series.isEmpty else {
            // Cost basis only needs the price already stored on each record, so
            // it still works when the history fetch comes back empty.
            applyCostBasis(cards: cards, series: [:])
            hasLoadedOnce = true
            return
        }

        apply(series: series, holdings: holdings)
        applyCostBasis(cards: cards, series: series)
        lastHoldingsSignature = signature
        cache.save(series: series, signature: signature)
    }

    private func apply(
        series: [String: [PricingService.PortfolioPricePoint]],
        holdings: [PortfolioHolding]
    ) {
        points = PortfolioHistoryBuilder.dailyValues(holdings: holdings, series: series)
        summary = PortfolioHistoryBuilder.summary(for: points)
        movers = PortfolioInsightsBuilder.movers(
            holdings: holdings, series: series, overTrailing: Self.moverDays
        )
        extremes = PortfolioInsightsBuilder.extremes(holdings: holdings, series: series)
        variantSplit = PortfolioInsightsBuilder.variantSplit(holdings: holdings, series: series)
        hasLoadedOnce = true
    }

    /// Values cost basis from the live series where available, falling back to
    /// the price stored on the record.
    private func applyCostBasis(
        cards: [CollectedCard],
        series: [String: [PricingService.PortfolioPricePoint]]
    ) {
        let lookup: CostBasisCalculator.PriceLookup = { cardKey, stored in
            series[cardKey]?.last?.price ?? stored
        }
        costBasis = CostBasisCalculator.summary(for: cards, price: lookup)
        costBasisEntries = CostBasisCalculator.entries(for: cards, price: lookup)
    }

    private func uniquePrintings(from cards: [CollectedCard]) -> [LorcanaCard] {
        var seen: Set<String> = []
        var printings: [LorcanaCard] = []
        for card in cards {
            let lorcanaCard = card.toLorcanaCard
            if seen.insert(lorcanaCard.variantAwareId).inserted {
                printings.append(lorcanaCard)
            }
        }
        return printings
    }
}
