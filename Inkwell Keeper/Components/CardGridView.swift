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
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(cards) { card in
                    CardTile(card: card, isWishlist: isWishlist )
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
        }
        .animation(.easeInOut(duration: 0.3), value: cards.count)
    }
}
