//
//  PortfolioExtremesCard.swift
//  Inkwell Keeper
//
//  Cards sitting at the top or bottom of their charted price range — the
//  closest the app comes to a "look at this one" signal.
//

import SwiftUI

struct PortfolioExtremesCard: View {
    let viewModel: PortfolioHistoryViewModel
    let isSubscribed: Bool
    let onUnlock: () -> Void

    private static let perSide = 3

    private var windowMonths: Int {
        max(1, PortfolioHistoryViewModel.windowDays / 30)
    }

    var body: some View {
        StatsCardContainer(
            title: "Highs & Lows",
            subtitle: "Cards at the edge of their \(windowMonths)-month range"
        ) {
            if !isSubscribed {
                PortfolioProTeaser(
                    icon: "arrow.up.right.and.arrow.down.left.rectangle",
                    headline: "Spot cards at their peak",
                    detail: "See which of your cards are at their highest — or lowest — price in months.",
                    onUnlock: onUnlock
                )
            } else if viewModel.isLoading && viewModel.extremes.isEmpty {
                ProgressView().tint(.lorcanaGold).frame(maxWidth: .infinity).frame(height: 120)
            } else if viewModel.extremes.isEmpty {
                StatsEmptyState(
                    message: viewModel.hasLoadedOnce
                        ? "None of your cards are at a notable high or low right now."
                        : "Loading price history…"
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.highs.isEmpty {
                        PortfolioExtremeSection(
                            title: "At a high",
                            extremes: Array(viewModel.highs.prefix(Self.perSide))
                        )
                    }
                    if !viewModel.lows.isEmpty {
                        PortfolioExtremeSection(
                            title: "At a low",
                            extremes: Array(viewModel.lows.prefix(Self.perSide))
                        )
                    }
                }
            }
        }
    }
}

private struct PortfolioExtremeSection: View {
    let title: String
    let extremes: [PortfolioExtreme]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.lorcanaGold)

            ForEach(extremes) { extreme in
                PortfolioExtremeRow(extreme: extreme)
            }
        }
    }
}

private struct PortfolioExtremeRow: View {
    let extreme: PortfolioExtreme

    private var rangeCaption: String {
        let low = PricingService.formatPrice(extreme.windowLow)
        let high = PricingService.formatPrice(extreme.windowHigh)
        return "range \(low)–\(high)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(extreme.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if extreme.isFoil {
                        Text("Foil")
                            .font(.caption2)
                            .foregroundStyle(Color.lorcanaGold)
                    }
                    Text(rangeCaption)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 4) {
                Image(systemName: extreme.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line")
                    .font(.caption2)
                Text(
                    extreme.price,
                    format: .currency(code: PricingService.preferredCurrency)
                        .precision(.fractionLength(2))
                )
                .font(.subheadline)
                .bold()
            }
            .foregroundStyle(extreme.kind == .high ? .green : .red)
        }
        .accessibilityElement(children: .combine)
    }
}
