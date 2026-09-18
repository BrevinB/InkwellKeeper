//
//  PortfolioMoverRow.swift
//  Inkwell Keeper
//
//  One card's movement in a Stats list.
//

import SwiftUI

struct PortfolioMoverRow: View {
    let mover: PortfolioMover

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mover.name)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if mover.isFoil {
                        Text("Foil")
                            .font(.caption2)
                            .foregroundStyle(Color.lorcanaGold)
                    }
                    if mover.quantity > 1 {
                        Text("\(mover.quantity) copies")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 2) {
                PriceChangeBadge(change: mover.change)
                if let percent = mover.percentChange {
                    Text(percent / 100, format: .percent.precision(.fractionLength(1)))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
