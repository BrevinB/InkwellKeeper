//
//  CostBasisCalculator.swift
//  Inkwell Keeper
//
//  Compares what was paid with what the cards are worth now. Pure functions so
//  the arithmetic is testable without a model container.
//

import Foundation

enum CostBasisCalculator {
    /// A card's market value, preferring the live series the portfolio cards
    /// already hold and falling back to the price stored on the record.
    typealias PriceLookup = (_ cardKey: String, _ stored: Double?) -> Double?

    /// Totals across every copy with a recorded purchase price.
    ///
    /// Copies without one are counted separately rather than assumed free: a
    /// missing purchase price is unknown, not zero, and treating it as zero
    /// would report the whole market value as profit.
    static func summary(
        for cards: [CollectedCard],
        price: PriceLookup
    ) -> CostBasisSummary {
        var costBasis = 0.0
        var marketValue = 0.0
        var recordedCopies = 0
        var unrecordedCopies = 0

        for card in cards {
            let quantity = max(0, card.quantity)
            guard quantity > 0 else { continue }
            let key = card.toLorcanaCard.variantAwareId

            guard let paid = card.purchasePrice else {
                unrecordedCopies += quantity
                continue
            }
            recordedCopies += quantity
            costBasis += paid * Double(quantity)
            if let current = price(key, card.price) {
                marketValue += current * Double(quantity)
            } else {
                // No market price for this printing, so it contributes what it
                // cost. Leaving it out of one side only would skew the gain.
                marketValue += paid * Double(quantity)
            }
        }

        return CostBasisSummary(
            costBasis: costBasis,
            marketValue: marketValue,
            recordedCopies: recordedCopies,
            unrecordedCopies: unrecordedCopies
        )
    }

    /// Per-printing gains and losses, ordered by the size of the move.
    static func entries(
        for cards: [CollectedCard],
        price: PriceLookup
    ) -> [CostBasisEntry] {
        var merged: [String: CostBasisEntry] = [:]

        for card in cards {
            let quantity = max(0, card.quantity)
            guard quantity > 0, let paid = card.purchasePrice else { continue }
            let lorcanaCard = card.toLorcanaCard
            let key = lorcanaCard.variantAwareId
            let current = price(key, card.price) ?? paid

            let existing = merged[key]
            merged[key] = CostBasisEntry(
                cardKey: key,
                name: lorcanaCard.name,
                isFoil: lorcanaCard.variant != .normal,
                quantity: (existing?.quantity ?? 0) + quantity,
                costBasis: (existing?.costBasis ?? 0) + paid * Double(quantity),
                marketValue: (existing?.marketValue ?? 0) + current * Double(quantity)
            )
        }

        return merged.values.sorted { abs($0.gain) > abs($1.gain) }
    }
}
