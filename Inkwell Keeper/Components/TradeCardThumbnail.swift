//
//  TradeCardThumbnail.swift
//  Inkwell Keeper
//
//  Small piece of card art, used in trade rows and the scan tray.
//

import SwiftUI

struct TradeCardThumbnail: View {
    let card: LorcanaCard
    var width: CGFloat = 38

    /// Lorcana cards are 2.5 × 3.5 inches.
    private var height: CGFloat { width * 3.5 / 2.5 }

    var body: some View {
        AsyncImage(url: card.bestImageUrl()) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.25))
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: 4))
        .overlay {
            if card.variant != .normal {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.lorcanaGold.opacity(0.8), lineWidth: 1)
            }
        }
        .accessibilityLabel(card.name)
    }
}
