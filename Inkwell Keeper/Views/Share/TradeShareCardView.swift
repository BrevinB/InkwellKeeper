//
//  TradeShareCardView.swift
//  Inkwell Keeper
//
//  Share-card template for a confirmed trade. Presentation-only and rendered
//  off-screen by `ShareImageRenderer`.
//

import SwiftUI

struct TradeShareCardView: View {
    let yours: TradeSide
    let theirs: TradeSide
    let difference: Double
    /// Preloaded card art keyed by trade-line id.
    var images: [String: UIImage] = [:]

    private var verdict: String {
        if abs(difference) < 0.01 { return "Even trade" }
        let amount = PricingService.formatPrice(abs(difference))
        return difference > 0 ? "Up \(amount)" : "Down \(amount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Trade")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(verdict)
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
            }

            TradeShareSide(
                title: "Gave",
                side: yours,
                images: images
            )

            Divider().overlay(Color.lorcanaGold.opacity(0.4))

            TradeShareSide(
                title: "Got",
                side: theirs,
                images: images
            )
        }
    }
}

private struct TradeShareSide: View {
    let title: String
    let side: TradeSide
    let images: [String: UIImage]

    /// Keeps the card fitting a share image rather than growing without bound.
    private static let maxShown = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(side.total, format: .currency(code: PricingService.preferredCurrency)
                    .precision(.fractionLength(2)))
                    .font(.headline)
                    .bold()
            }

            HStack(spacing: 6) {
                ForEach(side.lines.prefix(Self.maxShown)) { line in
                    TradeShareThumbnail(image: images[line.id], quantity: line.quantity)
                }
                if side.lines.count > Self.maxShown {
                    Text("+\(side.lines.count - Self.maxShown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct TradeShareThumbnail: View {
    let image: UIImage?
    let quantity: Int

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                }
            }
            .frame(width: 52, height: 73)
            .clipShape(.rect(cornerRadius: 4))

            if quantity > 1 {
                Text("\(quantity)")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .background(Color.lorcanaGold, in: .capsule)
                    .offset(x: 3, y: 3)
            }
        }
    }
}
