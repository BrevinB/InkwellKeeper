//
//  PortfolioHistoryCard.swift
//  Inkwell Keeper
//
//  Collection value over time — the Pro entry point on the Stats tab, where
//  collectors already are.
//

import SwiftUI

struct PortfolioHistoryCard: View {
    let viewModel: PortfolioHistoryViewModel
    let isSubscribed: Bool
    let onUnlock: () -> Void

    private var subtitle: String {
        guard isSubscribed, let change = viewModel.weeklyChange else {
            return "How your collection's value has moved"
        }
        let formatted = PricingService.formatPrice(abs(change))
        return change >= 0 ? "Up \(formatted) this week" : "Down \(formatted) this week"
    }

    var body: some View {
        StatsCardContainer(title: "Collection Value", subtitle: subtitle) {
            if !isSubscribed {
                PortfolioLockedPreview(
                    points: viewModel.points,
                    since: viewModel.points.first?.date,
                    onUnlock: onUnlock
                )
            } else if viewModel.isLoading && viewModel.points.isEmpty {
                ProgressView()
                    .tint(.lorcanaGold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
            } else if viewModel.points.count < 2 {
                StatsEmptyState(
                    message: viewModel.hasLoadedOnce
                        ? "No price history yet for the cards in your collection."
                        : "Loading price history…"
                )
            } else {
                PortfolioSummaryHeader(
                    summary: viewModel.summary,
                    since: viewModel.points.first?.date
                )
                PortfolioValueChart(points: viewModel.points)
            }
        }
    }
}
