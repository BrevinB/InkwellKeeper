//
//  TradeVerdictCard.swift
//  Inkwell Keeper
//
//  The bottom line of a trade: each side's value and who comes out ahead.
//

import SwiftUI

struct TradeVerdictCard: View {
    let viewModel: TradeCalculatorViewModel

    private var verdict: String {
        let difference = viewModel.difference
        if abs(difference) < 0.01 { return "Even trade" }
        let amount = PricingService.formatPrice(abs(difference))
        return difference > 0 ? "You gain \(amount)" : "You lose \(amount)"
    }

    private var verdictColor: Color {
        let difference = viewModel.difference
        if abs(difference) < 0.01 { return .white }
        return difference > 0 ? .green : .red
    }

    var body: some View {
        StatsCardContainer(title: "Trade Value") {
            if viewModel.isEmpty {
                StatsEmptyState(message: "Add cards to each side to compare their value.")
            } else {
                VStack(spacing: 12) {
                    HStack {
                        TradeTotal(title: "You give", side: viewModel.yours)
                        Spacer()
                        Image(systemName: "arrow.left.arrow.right")
                            .foregroundStyle(.gray)
                        Spacer()
                        TradeTotal(title: "You get", side: viewModel.theirs)
                    }

                    Text(verdict)
                        .font(.headline)
                        .foregroundStyle(verdictColor)

                    if viewModel.isPricing {
                        ProgressView().tint(.lorcanaGold)
                    } else if viewModel.unpricedCount > 0 {
                        Text("\(viewModel.unpricedCount) card\(viewModel.unpricedCount == 1 ? "" : "s") has no market price and is not counted.")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}

private struct TradeTotal: View {
    let title: String
    let side: TradeSide

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(
                side.total,
                format: .currency(code: PricingService.preferredCurrency)
                    .precision(.fractionLength(2))
            )
            .font(.headline)
            .foregroundStyle(.white)
            Text("\(side.cardCount) card\(side.cardCount == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.gray)
        }
        .accessibilityElement(children: .combine)
    }
}
