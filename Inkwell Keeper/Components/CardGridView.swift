//
//  CardGridView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CardGridView: View {
    let cards: [LorcanaCard]
    let isWishlist: Bool

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var gridHelper: AdaptiveGridHelper {
        AdaptiveGridHelper(horizontalSizeClass: horizontalSizeClass)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridHelper.cardGridColumns(), spacing: gridHelper.gridSpacing) {
                ForEach(cards) { card in
                    CardTile(card: card, isWishlist: isWishlist )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(gridHelper.viewPadding)
        }
        .animation(.easeInOut(duration: 0.3), value: cards.count)
    }
}
