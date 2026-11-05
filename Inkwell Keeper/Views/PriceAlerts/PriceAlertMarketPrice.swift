//
//  PriceAlertMarketPrice.swift
//  Inkwell Keeper
//
//  Today's USD market price in the alert editor, or why there isn't one.
//

import SwiftUI

struct PriceAlertMarketPrice: View {
    let price: Double?
    let isLoading: Bool

    var body: some View {
        if let price {
            Text(price, format: .currency(code: "USD"))
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(.lorcanaGold)
                .contentTransition(.numericText(value: price))
        } else if isLoading {
            ProgressView()
                .tint(.lorcanaGold)
        } else {
            Text("Unavailable")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }
}
