//
//  PortfolioHolding.swift
//  Inkwell Keeper
//
//  One priced printing in the collection, reduced to what the portfolio chart
//  needs: which series values it, and how many copies are held.
//

import Foundation

struct PortfolioHolding: Hashable, Sendable {
    /// The card's `variantAwareId` — the key `PricingService.fetchBulkHistory`
    /// returns series under.
    let cardKey: String
    let quantity: Int
    /// Carried so per-card insights can name a printing without a second
    /// lookup; the value chart itself does not need it.
    let name: String
    let isFoil: Bool

    init(cardKey: String, quantity: Int, name: String = "", isFoil: Bool = false) {
        self.cardKey = cardKey
        self.quantity = max(0, quantity)
        self.name = name
        self.isFoil = isFoil
    }
}
