//
//  PortfolioInsights.swift
//  Inkwell Keeper
//
//  Per-printing readings derived from the same price series that feeds the
//  collection value chart. They cost no extra network: the series is already
//  in hand once the chart has loaded.
//

import Foundation

/// A printing whose value moved over the window being reported.
struct PortfolioMover: Identifiable, Hashable, Sendable {
    /// The card's `variantAwareId`.
    let cardKey: String
    let name: String
    let isFoil: Bool
    let quantity: Int
    /// Change in the value of the held copies, not of a single card.
    let change: Double
    let currentValue: Double
    let percentChange: Double?

    var id: String { cardKey }
    var isGain: Bool { change >= 0 }
}

/// Where a printing's current price sits against its own charted range.
struct PortfolioExtreme: Identifiable, Hashable, Sendable {
    enum Kind: Sendable {
        case high
        case low
    }

    let cardKey: String
    let name: String
    let isFoil: Bool
    let kind: Kind
    let price: Double
    let windowHigh: Double
    let windowLow: Double

    var id: String { cardKey }
}

/// How the collection's value splits between foil and normal printings.
struct PortfolioVariantSplit: Hashable, Sendable {
    let foilValue: Double
    let normalValue: Double
    let foilCopies: Int
    let normalCopies: Int

    static let empty = Self(foilValue: 0, normalValue: 0, foilCopies: 0, normalCopies: 0)

    var totalValue: Double { foilValue + normalValue }

    var averageFoilValue: Double {
        foilCopies > 0 ? foilValue / Double(foilCopies) : 0
    }

    var averageNormalValue: Double {
        normalCopies > 0 ? normalValue / Double(normalCopies) : 0
    }

    /// How many times more a foil copy is worth than a normal one, on average.
    /// Nil when either side is missing, where the comparison has no meaning.
    var foilMultiple: Double? {
        guard foilCopies > 0, normalCopies > 0 else { return nil }
        let foilAverage = foilValue / Double(foilCopies)
        let normalAverage = normalValue / Double(normalCopies)
        guard normalAverage > 0 else { return nil }
        return foilAverage / normalAverage
    }

    var foilShare: Double? {
        guard totalValue > 0 else { return nil }
        return foilValue / totalValue
    }
}
