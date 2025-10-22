//
//  FilterChip.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.lorcanaGold : Color.clear)
                        .overlay(
                            Capsule()
                                .stroke(Color.lorcanaGold, lineWidth: 1)
                        )
                )
                .foregroundColor(isSelected ? .black : .lorcanaGold)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
