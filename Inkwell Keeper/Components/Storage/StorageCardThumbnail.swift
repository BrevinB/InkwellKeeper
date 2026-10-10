//
//  StorageCardThumbnail.swift
//  Inkwell Keeper
//
//  A lightweight card image for pockets and box grids. Deliberately skips the
//  motion-driven holographic effect: a binder page shows up to a dozen cards at
//  once and must stay smooth while pages turn. Foils get the static sheen.
//

import SwiftUI

struct StorageCardThumbnail: View {
    let card: LorcanaCard

    var body: some View {
        CachedAsyncImage(url: card.bestImageUrl()) { image in
            if card.variant == .normal {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                image
                    .resizable()
                    .scaledToFit()
                    .modifier(StaticFoilEffect())
            }
        } placeholder: {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.gray.opacity(0.5))
                }
        }
        .aspectRatio(63 / 88, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 6))
    }
}
