//
//  PriceTrendChart.swift
//  Inkwell Keeper
//
//  A card's market price trend in the gold of the card detail screen. Used by the
//  card detail price history section and the price trend share card.
//

import SwiftUI

struct PriceTrendChart: View {
    let points: [PricingService.RemotePricePoint]
    /// Drag to scrub. Off for the share image.
    var isInteractive = true

    var body: some View {
        ValueHistoryChart(
            points: points.map { PortfolioPoint(date: $0.date, value: $0.price) },
            tint: .lorcanaGold,
            // Backend price history is USD only.
            currencyCode: "USD",
            isInteractive: isInteractive
        )
    }
}
