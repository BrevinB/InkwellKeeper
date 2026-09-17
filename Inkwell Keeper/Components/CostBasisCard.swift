//
//  CostBasisCard.swift
//  Inkwell Keeper
//
//  What the collection cost against what it is worth now.
//

import SwiftUI

struct CostBasisCard: View {
    let summary: CostBasisSummary
    let entries: [CostBasisEntry]
    let isSubscribed: Bool
    let onUnlock: () -> Void

    private static let perSide = 3

    var body: some View {
        StatsCardContainer(
            title: "Cost vs Value",
            subtitle: "What you paid against what it's worth"
        ) {
            if !isSubscribed {
                PortfolioProTeaser(
                    icon: "tag",
                    headline: "Track what you actually made",
                    detail: "Record what you paid and see the gain or loss on every card.",
                    onUnlock: onUnlock
                )
            } else if !summary.hasRecordedCost {
                StatsEmptyState(
                    message: "Add what you paid for a card — open any card and tap Paid — to see your gain or loss here."
                )
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    CostBasisHeader(summary: summary)

                    if summary.isPartial {
                        Text("Covers the \(summary.recordedCopies) copies with a recorded price; \(summary.unrecordedCopies) have none yet.")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }

                    if !entries.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biggest positions")
                                .font(.caption)
                                .foregroundStyle(Color.lorcanaGold)

                            ForEach(entries.prefix(Self.perSide)) { entry in
                                CostBasisEntryRow(entry: entry)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct CostBasisHeader: View {
    let summary: CostBasisSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Paid")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(
                    summary.costBasis,
                    format: .currency(code: PricingService.preferredCurrency)
                        .precision(.fractionLength(2))
                )
                .font(.headline)
                .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 2) {
                Text("Those worth now")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                Text(
                    summary.marketValue,
                    format: .currency(code: PricingService.preferredCurrency)
                        .precision(.fractionLength(2))
                )
                .font(.headline)
                .foregroundStyle(.white)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                PriceChangeBadge(change: summary.gain)
                if let percent = summary.percentGain {
                    Text(percent / 100, format: .percent.precision(.fractionLength(1)))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

private struct CostBasisEntryRow: View {
    let entry: CostBasisEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if entry.isFoil {
                        Text("Foil")
                            .font(.caption2)
                            .foregroundStyle(Color.lorcanaGold)
                    }
                    Text("\(entry.quantity) × paid \(PricingService.formatPrice(entry.costBasis / Double(max(1, entry.quantity))))")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                PriceChangeBadge(change: entry.gain)
                if let percent = entry.percentGain {
                    Text(percent / 100, format: .percent.precision(.fractionLength(1)))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
