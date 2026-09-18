//
//  TradeSideSection.swift
//  Inkwell Keeper
//
//  One half of a trade: its cards and a way to add more.
//

import SwiftUI

struct TradeSideSection: View {
    let side: TradeCalculatorViewModel.Side
    let tradeSide: TradeSide
    let isPricing: Bool
    let onAdd: () -> Void
    let onScan: () -> Void
    let onRemove: (String) -> Void

    var body: some View {
        StatsCardContainer(title: side.title) {
            VStack(alignment: .leading, spacing: 12) {
                if tradeSide.lines.isEmpty {
                    StatsEmptyState(message: "Nothing on this side yet.")
                } else {
                    ForEach(tradeSide.lines) { line in
                        TradeLineRow(line: line, isPricing: isPricing) { onRemove(line.id) }
                    }
                }

                HStack {
                    Button("Add card", systemImage: "plus", action: onAdd)
                        .buttonStyle(.bordered)
                        .tint(.lorcanaGold)

                    Button("Scan", systemImage: "viewfinder", action: onScan)
                        .buttonStyle(.bordered)
                        .tint(.lorcanaGold)
                }
            }
        }
    }
}

private struct TradeLineRow: View {
    let line: TradeLine
    let isPricing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack {
            TradeCardThumbnail(card: line.card)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.card.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(line.quantity)×")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                    Text(line.card.setName)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    if line.card.variant != .normal {
                        Text(line.card.variant.displayName)
                            .font(.caption2)
                            .foregroundStyle(Color.lorcanaGold)
                    }
                }
            }

            Spacer(minLength: 8)

            if let total = line.total {
                Text(
                    total,
                    format: .currency(code: PricingService.preferredCurrency)
                        .precision(.fractionLength(2))
                )
                .font(.subheadline)
                .foregroundStyle(.white)
            } else if isPricing {
                ProgressView()
                    .controlSize(.small)
                    .tint(.lorcanaGold)
            } else {
                Text("No price")
                    .font(.caption2)
                    .foregroundStyle(.gray)
            }

            Button("Remove \(line.card.name)", systemImage: "minus.circle", action: onRemove)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
        }
    }
}
