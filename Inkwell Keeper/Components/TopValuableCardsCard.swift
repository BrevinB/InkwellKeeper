//
//  TopValuableCardsCard.swift
//  Inkwell Keeper
//

import SwiftUI

struct TopValuableCardsCard: View {
    let cards: [TopValuableCard]

    var body: some View {
        StatsCardContainer(
            title: "Top 10 Most Valuable",
            subtitle: "Highest stack value based on live market pricing"
        ) {
            if cards.isEmpty {
                StatsEmptyState(message: "No priced cards yet — refresh prices from Settings to populate this list.")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, entry in
                        TopValuableRow(rank: index + 1, entry: entry)
                    }
                }
            }
        }
    }
}

private struct TopValuableRow: View {
    let rank: Int
    let entry: TopValuableCard

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.caption)
                .bold()
                .foregroundStyle(Color.lorcanaGold)
                .frame(width: 20, alignment: .leading)

            AsyncImage(url: entry.card.bestImageUrl()) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 32, height: 44)
            .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.card.name)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if entry.card.variant != .normal {
                        Text(entry.card.variant.shortName)
                            .font(.caption2)
                            .bold()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule().fill(variantBadgeColor(entry.card.variant))
                            )
                    }
                }
                HStack(spacing: 6) {
                    Text(entry.card.setName)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                    if entry.quantity > 1 {
                        Text("× \(entry.quantity)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(PricingService.formatPrice(entry.stackValue))
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(Color.lorcanaGold)
                if entry.quantity > 1 {
                    Text("\(PricingService.formatPrice(entry.unitPrice)) ea.")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private func variantBadgeColor(_ variant: CardVariant) -> Color {
        switch variant {
        case .normal: return .gray
        case .foil: return Color(red: 0.45, green: 0.55, blue: 0.95)
        case .borderless: return Color(red: 0.4, green: 0.4, blue: 0.5)
        case .promo: return Color(red: 0.85, green: 0.4, blue: 0.2)
        case .enchanted: return Color(red: 0.65, green: 0.4, blue: 0.85)
        case .epic: return Color(red: 0.9, green: 0.3, blue: 0.5)
        case .iconic: return Color(red: 1.0, green: 0.75, blue: 0.0)
        }
    }
}
