//
//  TradeSide.swift
//  Inkwell Keeper
//
//  One half of a proposed trade.
//

import Foundation

struct TradeLine: Identifiable, Hashable, Sendable {
    let card: LorcanaCard
    var quantity: Int
    /// Nil until the price lookup returns, so the UI can distinguish "still
    /// loading" from "no market price for this printing".
    var unitPrice: Double?

    var id: String { card.variantAwareId }

    var total: Double? {
        guard let unitPrice else { return nil }
        return unitPrice * Double(quantity)
    }
}

struct TradeSide: Hashable, Sendable {
    var lines: [TradeLine] = []

    var cardCount: Int { lines.reduce(0) { $0 + $1.quantity } }

    /// Sum of the lines that have a price. Lines still without one are
    /// reported separately rather than counted as zero.
    var total: Double {
        lines.compactMap(\.total).reduce(0, +)
    }

    var unpricedCount: Int {
        lines.filter { $0.unitPrice == nil }.reduce(0) { $0 + $1.quantity }
    }

    mutating func add(_ card: LorcanaCard) {
        if let index = lines.firstIndex(where: { $0.id == card.variantAwareId }) {
            lines[index].quantity += 1
        } else {
            lines.append(TradeLine(card: card, quantity: 1, unitPrice: nil))
        }
    }

    mutating func remove(_ lineID: String) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }) else { return }
        if lines[index].quantity > 1 {
            lines[index].quantity -= 1
        } else {
            lines.remove(at: index)
        }
    }

    /// Prices are keyed by `variantAwareId`, so a foil and its normal printing
    /// take their own market price rather than sharing one.
    mutating func applyPrices(_ prices: [String: Double]) {
        for index in lines.indices {
            if let price = prices[lines[index].id] {
                lines[index].unitPrice = price
            }
        }
    }
}
