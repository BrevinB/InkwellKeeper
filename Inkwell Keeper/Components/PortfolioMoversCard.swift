//
//  PortfolioMoversCard.swift
//  Inkwell Keeper
//
//  What gained and lost the most value in the collection this week.
//

import SwiftUI

struct PortfolioMoversCard: View {
    let viewModel: PortfolioHistoryViewModel
    let isSubscribed: Bool
    let onUnlock: () -> Void

    /// Enough to see a pattern without turning the card into a table.
    private static let perSide = 3

    var body: some View {
        StatsCardContainer(
            title: "Biggest Movers",
            subtitle: "What gained and lost the most in the past week"
        ) {
            if !isSubscribed {
                PortfolioProTeaser(
                    icon: "arrow.up.arrow.down",
                    headline: "See what moved this week",
                    detail: "The cards driving your collection's value up — and down.",
                    onUnlock: onUnlock
                )
            } else if viewModel.isLoading && viewModel.movers.isEmpty {
                ProgressView().tint(.lorcanaGold).frame(maxWidth: .infinity).frame(height: 120)
            } else if viewModel.movers.isEmpty {
                StatsEmptyState(
                    message: viewModel.hasLoadedOnce
                        ? "Nothing in your collection changed price this week."
                        : "Loading price history…"
                )
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.gainers.isEmpty {
                        PortfolioMoverSection(
                            title: "Gainers",
                            movers: Array(viewModel.gainers.prefix(Self.perSide))
                        )
                    }
                    if !viewModel.losers.isEmpty {
                        PortfolioMoverSection(
                            title: "Losers",
                            movers: Array(viewModel.losers.prefix(Self.perSide))
                        )
                    }
                }
            }
        }
    }
}

private struct PortfolioMoverSection: View {
    let title: String
    let movers: [PortfolioMover]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.lorcanaGold)

            ForEach(movers) { mover in
                PortfolioMoverRow(mover: mover)
            }
        }
    }
}
