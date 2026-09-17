//
//  TradeExchangeAnimation.swift
//  Inkwell Keeper
//
//  Both halves of a trade sweeping past each other as it is confirmed.
//

import SwiftUI

struct TradeExchangeAnimation: View {
    let yours: [TradeLine]
    let theirs: [TradeLine]
    let phase: TradeConfirmationView.Phase

    /// Enough to read as a hand of cards without crowding the fan.
    private static let maxShown = 4

    private var yourCards: [LorcanaCard] {
        Array(yours.prefix(Self.maxShown).map(\.card))
    }

    private var theirCards: [LorcanaCard] {
        Array(theirs.prefix(Self.maxShown).map(\.card))
    }

    private var travel: CGFloat {
        switch phase {
        case .ready: 0
        case .sending: 70
        case .done: 46
        }
    }

    var body: some View {
        ZStack {
            if phase != .ready {
                TradeExchangeGlow(isPeaking: phase == .sending)
            }

            HStack(spacing: phase == .ready ? 32 : 8) {
                TradeCardFan(cards: yourCards, tilt: -8)
                    .offset(x: travel)
                    .rotationEffect(.degrees(phase == .sending ? 6 : 0))

                TradeCardFan(cards: theirCards, tilt: 8)
                    .offset(x: -travel)
                    .rotationEffect(.degrees(phase == .sending ? -6 : 0))
            }
            .scaleEffect(phase == .sending ? 0.92 : 1)

            if phase == .done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Color.lorcanaGold)
                    .shadow(color: .black.opacity(0.5), radius: 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 170)
        .accessibilityHidden(true)
    }
}

/// A small overlapping fan of card art.
private struct TradeCardFan: View {
    let cards: [LorcanaCard]
    let tilt: Double

    var body: some View {
        ZStack {
            if cards.isEmpty {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                    .frame(width: 60, height: 84)
            } else {
                ForEach(cards.enumerated(), id: \.element.variantAwareId) { index, card in
                    TradeCardThumbnail(card: card, width: 60)
                        .rotationEffect(.degrees(tilt * Double(index)))
                        .offset(x: CGFloat(index) * 10, y: CGFloat(index) * -4)
                        .zIndex(Double(cards.count - index))
                }
            }
        }
    }
}

/// The gold bloom behind the exchange.
private struct TradeExchangeGlow: View {
    let isPeaking: Bool

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.lorcanaGold.opacity(isPeaking ? 0.5 : 0.22), .clear],
                    center: .center,
                    startRadius: 4,
                    endRadius: isPeaking ? 150 : 100
                )
            )
            .frame(width: 280, height: 280)
            .blur(radius: 12)
    }
}
