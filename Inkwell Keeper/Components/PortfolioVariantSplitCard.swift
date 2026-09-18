//
//  PortfolioVariantSplitCard.swift
//  Inkwell Keeper
//
//  How much of the collection's value sits in foils.
//

import SwiftUI
import Charts

struct PortfolioVariantSplitCard: View {
    let viewModel: PortfolioHistoryViewModel
    let isSubscribed: Bool
    let onUnlock: () -> Void

    private var split: PortfolioVariantSplit { viewModel.variantSplit }

    var body: some View {
        StatsCardContainer(
            title: "Foil Premium",
            subtitle: "Average value of a copy, foil against normal"
        ) {
            if !isSubscribed {
                PortfolioProTeaser(
                    icon: "sparkle",
                    headline: "See what your foils are worth",
                    detail: "Compare the value locked up in foils against the rest of your collection.",
                    onUnlock: onUnlock
                )
            } else if viewModel.isLoading && split.totalValue == 0 {
                ProgressView().tint(.lorcanaGold).frame(maxWidth: .infinity).frame(height: 100)
            } else if split.totalValue == 0 {
                StatsEmptyState(
                    message: viewModel.hasLoadedOnce
                        ? "No priced cards to compare yet."
                        : "Loading price history…"
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if let multiple = split.foilMultiple {
                        Text(
                            "Your foils are worth \(multiple, format: .number.precision(.fractionLength(1)))× a normal copy, on average."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.white)
                    }

                    // Bars plot the average per copy, not the totals: the
                    // sentence above claims foils are worth a multiple of a
                    // normal, and totals would draw two near-equal bars right
                    // next to it. The totals are in the legend instead.
                    Chart {
                        BarMark(
                            x: .value("Average value", split.averageFoilValue),
                            y: .value("Kind", "Foil")
                        )
                        .foregroundStyle(Color.lorcanaGold.gradient)
                        .cornerRadius(4)

                        BarMark(
                            x: .value("Average value", split.averageNormalValue),
                            y: .value("Kind", "Normal")
                        )
                        .foregroundStyle(Color.gray.gradient)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 3)) { value in
                            AxisGridLine().foregroundStyle(.white.opacity(0.1))
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount, format: .currency(code: PricingService.preferredCurrency)
                                        .precision(.fractionLength(amount < 10 ? 2 : 0)))
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { AxisValueLabel().foregroundStyle(.gray) }
                    }
                    .frame(height: 90)

                    PortfolioVariantLegend(split: split)
                }
            }
        }
    }
}

private struct PortfolioVariantLegend: View {
    let split: PortfolioVariantSplit

    var body: some View {
        HStack {
            legendItem(
                label: "\(split.foilCopies) foil",
                value: split.foilValue,
                tint: Color.lorcanaGold
            )
            Spacer()
            legendItem(
                label: "\(split.normalCopies) normal",
                value: split.normalValue,
                tint: .gray
            )
        }
    }

    private func legendItem(label: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(tint)
            Text(
                value,
                format: .currency(code: PricingService.preferredCurrency)
                    .precision(.fractionLength(2))
            )
            .font(.subheadline)
            .foregroundStyle(.white)
        }
    }
}
