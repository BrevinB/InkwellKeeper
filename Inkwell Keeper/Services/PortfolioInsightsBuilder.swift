//
//  PortfolioInsightsBuilder.swift
//  Inkwell Keeper
//
//  Per-printing readings over the price series already fetched for the
//  collection value chart: what moved, what is sitting at an extreme, and how
//  value splits between foils and normals. Pure functions, so the maths is
//  testable without a network.
//

import Foundation

enum PortfolioInsightsBuilder {
    /// Printings whose held value changed over the trailing window, ordered by
    /// the size of the move.
    ///
    /// The change is in the value of the copies actually held, not of a single
    /// card: four copies of a card up 50c matters more to a collection than one
    /// copy up 80c, and the collector is being shown their own position.
    static func movers(
        holdings: [PortfolioHolding],
        series: [String: [PricingService.PortfolioPricePoint]],
        overTrailing days: Int
    ) -> [PortfolioMover] {
        guard let lastDay = series.values.compactMap({ $0.last?.day }).max() else { return [] }
        let targetDay = lastDay - days

        return holdings.compactMap { holding -> PortfolioMover? in
            guard holding.quantity > 0,
                  let cardSeries = series[holding.cardKey],
                  let current = price(in: cardSeries, onOrBefore: lastDay),
                  let opening = price(in: cardSeries, onOrBefore: targetDay),
                  current != opening else {
                return nil
            }
            let quantity = Double(holding.quantity)
            return PortfolioMover(
                cardKey: holding.cardKey,
                name: holding.name,
                isFoil: holding.isFoil,
                quantity: holding.quantity,
                change: (current - opening) * quantity,
                currentValue: current * quantity,
                percentChange: opening > 0 ? ((current - opening) / opening) * 100 : nil
            )
        }
        .sorted { abs($0.change) > abs($1.change) }
    }

    /// Printings whose latest price is the highest or lowest of their charted
    /// window.
    ///
    /// Two guards keep this from being noise. A penny common ticking from 1c to
    /// 2c is technically at a high, so anything below `minimumPrice` is
    /// ignored; and a price that has barely moved all window is trivially at
    /// both its high and its low, so the window has to have spanned at least
    /// `minimumRange` for the reading to mean anything.
    static let minimumExtremePrice = 0.25
    static let minimumExtremeRange = 1.15
    static let minimumExtremePoints = 8

    static func extremes(
        holdings: [PortfolioHolding],
        series: [String: [PricingService.PortfolioPricePoint]],
        minimumPrice: Double = minimumExtremePrice,
        minimumRange: Double = minimumExtremeRange
    ) -> [PortfolioExtreme] {
        holdings.compactMap { holding -> PortfolioExtreme? in
            guard holding.quantity > 0,
                  let cardSeries = series[holding.cardKey],
                  cardSeries.count >= minimumExtremePoints,
                  let current = cardSeries.last?.price,
                  current >= minimumPrice else {
                return nil
            }
            let prices = cardSeries.map(\.price)
            guard let high = prices.max(), let low = prices.min(),
                  low > 0, high >= low * minimumRange else {
                return nil
            }

            let kind: PortfolioExtreme.Kind
            if current >= high - 0.005 {
                kind = .high
            } else if current <= low + 0.005 {
                kind = .low
            } else {
                return nil
            }

            return PortfolioExtreme(
                cardKey: holding.cardKey,
                name: holding.name,
                isFoil: holding.isFoil,
                kind: kind,
                price: current,
                windowHigh: high,
                windowLow: low
            )
        }
        .sorted { $0.price > $1.price }
    }

    /// Current value split between foil and normal printings.
    static func variantSplit(
        holdings: [PortfolioHolding],
        series: [String: [PricingService.PortfolioPricePoint]]
    ) -> PortfolioVariantSplit {
        var foilValue = 0.0
        var normalValue = 0.0
        var foilCopies = 0
        var normalCopies = 0

        for holding in holdings where holding.quantity > 0 {
            guard let current = series[holding.cardKey]?.last?.price else { continue }
            let value = current * Double(holding.quantity)
            if holding.isFoil {
                foilValue += value
                foilCopies += holding.quantity
            } else {
                normalValue += value
                normalCopies += holding.quantity
            }
        }

        return PortfolioVariantSplit(
            foilValue: foilValue,
            normalValue: normalValue,
            foilCopies: foilCopies,
            normalCopies: normalCopies
        )
    }

    /// The price in effect on `day`.
    ///
    /// Series are change-point compressed, so a day with no point of its own
    /// carries the last price before it. A day earlier than the series starts
    /// takes its first price, matching how `PortfolioHistoryBuilder` carries a
    /// short series backwards rather than reading it as a gain.
    static func price(
        in series: [PricingService.PortfolioPricePoint],
        onOrBefore day: Int
    ) -> Double? {
        guard let first = series.first else { return nil }
        guard day >= first.day else { return first.price }

        var result = first.price
        for point in series {
            if point.day > day { break }
            result = point.price
        }
        return result
    }
}
