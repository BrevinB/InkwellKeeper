//
//  RarityBadge.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct RarityBadge: View {
    let rarity: CardRarity
    
    var body: some View {
        Text(rarity.displayName)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(rarity.color.opacity(0.8))
            )
            .foregroundColor(.white)
    }
}
