//
//  DeckShareCardView.swift
//  Inkwell Keeper
//
//  Share-card template for a deck: name, format, ink pips, a compact mana curve, and a row of
//  headline card thumbnails. Takes a plain `DeckShareData` snapshot (built at the call site from
//  the SwiftData `Deck`) plus preloaded artwork, so it renders cleanly off-screen.
//

import SwiftUI
import UIKit

/// Immutable snapshot of the deck data a share card needs. Built at the call site so the
/// template never touches the live `@Model`.
struct DeckShareData {
    let name: String
    let formatName: String
    let totalCards: Int
    let inkColors: [InkColor]
    /// Cost → number of cards at that cost.
    let costDistribution: [Int: Int]
    /// Ordered headline cards to feature (highest-impact first).
    let headlineCards: [HeadlineCard]

    struct HeadlineCard: Identifiable {
        let id: String
        let name: String
        let rarity: CardRarity
    }

    var subtitle: String {
        "\(formatName) • \(totalCards) cards"
    }

    /// Curve buckets for costs 1…7, where 7 aggregates everything 7+.
    var curveBuckets: [(cost: Int, count: Int)] {
        (1...7).map { cost in
            if cost == 7 {
                let count = costDistribution.filter { $0.key >= 7 }.values.reduce(0, +)
                return (7, count)
            }
            return (cost, costDistribution[cost] ?? 0)
        }
    }
}

struct DeckShareCardView: View {
    let deck: DeckShareData
    /// Headline card artwork keyed by card id (preloaded by `ShareCardPresenter`).
    var images: [String: UIImage] = [:]

    private var maxCurveCount: Int {
        max(1, deck.curveBuckets.map(\.count).max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(deck.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InkPips(inkColors: deck.inkColors)
                }
            }

            if !deck.headlineCards.isEmpty {
                HStack(spacing: 8) {
                    ForEach(deck.headlineCards.prefix(4)) { card in
                        CardThumbnail(card: card, image: images[card.id])
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mana Curve")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(deck.curveBuckets, id: \.cost) { bucket in
                        CurveBar(
                            label: bucket.cost == 7 ? "7+" : "\(bucket.cost)",
                            count: bucket.count,
                            fraction: Double(bucket.count) / Double(maxCurveCount)
                        )
                    }
                }
                .frame(height: 70)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Row of small ink-color dots.
private struct InkPips: View {
    let inkColors: [InkColor]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(inkColors, id: \.self) { ink in
                Circle()
                    .fill(ink.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
            }
        }
    }
}

/// A single featured card image (or a branded placeholder when art is missing).
private struct CardThumbnail: View {
    let card: DeckShareData.HeadlineCard
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [card.rarity.color.opacity(0.6), .lorcanaDark],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Text(card.name.prefix(1))
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: 68, height: 95)
        .clipShape(.rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(card.rarity.color.opacity(0.7), lineWidth: 1)
        }
    }
}

/// One vertical mana-curve bar.
private struct CurveBar: View {
    let label: String
    let count: Int
    let fraction: Double

    var body: some View {
        VStack(spacing: 3) {
            Text(count > 0 ? "\(count)" : "")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Capsule()
                .fill(.lorcanaGold.opacity(count > 0 ? 0.9 : 0.15))
                .frame(height: max(3, 48 * fraction))
                .frame(maxHeight: .infinity, alignment: .bottom)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
