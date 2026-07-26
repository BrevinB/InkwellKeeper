//
//  PricingSelectionTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for variant-aware price-row selection — the backend returns
//  separate normal and foil market rows under one unique id, and each
//  printing must be priced from its own market.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct PricingSelectionTests {
    private func row(_ marketplace: String, price: Double) -> PricingService.PriceData {
        PricingService.PriceData(
            price: price,
            condition: .nearMint,
            currency: "USD",
            marketplace: marketplace,
            url: nil,
            confidence: 0.9
        )
    }

    @Test func normalCardUsesNormalRowOnly() {
        let rows = [row("Lorcast (USD)", price: 1.0), row("Lorcast (USD Foil)", price: 5.0)]
        let selected = PricingService.pricesMatching(variant: .normal, in: rows)
        #expect(selected.count == 1)
        #expect(selected.first?.price == 1.0)
    }

    @Test func foilCardUsesFoilRowOnly() {
        let rows = [row("Lorcast (USD)", price: 1.0), row("Lorcast (USD Foil)", price: 5.0)]
        let selected = PricingService.pricesMatching(variant: .foil, in: rows)
        #expect(selected.count == 1)
        #expect(selected.first?.price == 5.0)
    }

    /// Special printings (own unique id) only exist foiled — prefer the foil market
    @Test func enchantedPrefersFoilRow() {
        let rows = [row("Lorcast (USD)", price: 80.0), row("Lorcast (USD Foil)", price: 120.0)]
        let selected = PricingService.pricesMatching(variant: .enchanted, in: rows)
        #expect(selected.first?.price == 120.0)
    }

    /// A printing with only one market row must still price, whatever the variant
    @Test func fallsBackWhenPreferredMarketMissing() {
        let foilOnly = [row("Lorcast (USD Foil)", price: 5.0)]
        #expect(PricingService.pricesMatching(variant: .normal, in: foilOnly).count == 1)

        let normalOnly = [row("Lorcast (USD)", price: 1.0)]
        #expect(PricingService.pricesMatching(variant: .foil, in: normalOnly).count == 1)
    }

    // MARK: - Market vs lowest-listing separation

    private var fourRowPayload: [PricingService.PriceData] {
        [
            row("Lorcast (USD)", price: 1.0),
            row("Lorcast (USD Foil)", price: 5.0),
            row("TCGplayer (USD Low)", price: 0.4),
            row("TCGplayer (USD Low Foil)", price: 2.0)
        ]
    }

    /// Low rows must never enter the market average — that was the original
    /// mispricing bug in a new costume.
    @Test func marketRowsExcludeLowestListings() {
        let normal = PricingService.marketRows(variant: .normal, in: fourRowPayload)
        #expect(normal.map(\.price) == [1.0])

        let foil = PricingService.marketRows(variant: .foil, in: fourRowPayload)
        #expect(foil.map(\.price) == [5.0])
    }

    @Test func lowestListingPicksVariantLowRow() {
        #expect(PricingService.lowestListing(variant: .normal, in: fourRowPayload) == 0.4)
        #expect(PricingService.lowestListing(variant: .foil, in: fourRowPayload) == 2.0)
    }

    @Test func lowestListingNilWhenBackendHasNoLowRows() {
        let marketOnly = [row("Lorcast (USD)", price: 1.0), row("Lorcast (USD Foil)", price: 5.0)]
        #expect(PricingService.lowestListing(variant: .normal, in: marketOnly) == nil)
    }

    /// A card with only low rows (no market source) should still produce a price
    @Test func marketRowsFallBackToLowRowsWhenNothingElse() {
        let lowOnly = [row("TCGplayer (USD Low)", price: 0.4)]
        #expect(PricingService.marketRows(variant: .normal, in: lowOnly).map(\.price) == [0.4])
    }
}
