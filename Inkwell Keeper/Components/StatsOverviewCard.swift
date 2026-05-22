//
//  StatsOverviewCard.swift
//  Inkwell Keeper
//

import SwiftUI

struct StatsOverviewCard: View {
    let snapshot: CollectionStatsSnapshot
    @State private var showingPricingInfo = false

    var body: some View {
        StatsCardContainer(title: "Collection Overview") {
            HStack(alignment: .top, spacing: 16) {
                StatTile(value: "\(snapshot.totalCards)", label: "Cards")
                StatTile(value: "\(snapshot.uniqueCards)", label: "Unique")
                valueTile
            }

            Button {
                showingPricingInfo = true
            } label: {
                Label {
                    Text(pricingSummary)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.leading)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.lorcanaGold)
                }
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPricingInfo) {
            PricingInfoView()
        }
    }

    private var pricingSummary: String {
        if snapshot.totalCards == 0 {
            return "Pricing data is sourced from Cardmarket — tap to learn more."
        }
        if snapshot.unpricedCardCount > 0 {
            return "\(snapshot.pricedCardCount) of \(snapshot.totalCards) cards have market data — tap to learn why."
        }
        return "Pricing data is sourced from Cardmarket — tap to learn more."
    }

    @ViewBuilder
    private var valueTile: some View {
        if snapshot.hasPricedCards {
            VStack(alignment: .center, spacing: 4) {
                Text(PricingService.formatPrice(snapshot.totalValue))
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Color.lorcanaGold)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Value")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .center, spacing: 4) {
                Text("—")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.gray)
                Text("No price data")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(Color.lorcanaGold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
