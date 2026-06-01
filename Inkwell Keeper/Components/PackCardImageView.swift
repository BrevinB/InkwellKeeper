//
//  PackCardImageView.swift
//  Inkwell Keeper
//
//  Renders a single pack card image, applying a foil shimmer to foil slots.
//

import SwiftUI

struct PackCardImageView: View {
    let slot: PackSlot
    /// Use the animated foil shimmer (reveal screen) vs. the static one (grids).
    var animatedFoil = false

    var body: some View {
        cardImage
            .clipShape(.rect(cornerRadius: 10))
    }

    @ViewBuilder
    private var cardImage: some View {
        AsyncImage(url: slot.card.bestImageUrl()) { phase in
            switch phase {
            case .success(let image):
                foiled(image.resizable().aspectRatio(contentMode: .fit))
            case .empty:
                placeholder.overlay(ProgressView().tint(Color.lorcanaGold))
            case .failure:
                placeholder.overlay(
                    Image(systemName: "photo.artframe")
                        .font(.title)
                        .foregroundStyle(slot.card.rarity.color)
                )
            @unknown default:
                placeholder
            }
        }
    }

    @ViewBuilder
    private func foiled(_ content: some View) -> some View {
        if slot.isFoil {
            content.foilEffect(isAnimated: animatedFoil)
        } else {
            content
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(slot.card.rarity.color.opacity(0.18))
            .aspectRatio(0.717, contentMode: .fit)
    }
}
