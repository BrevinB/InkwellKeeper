//
//  BookshelfSummary.swift
//  Inkwell Keeper
//
//  The brass placard across the top of the bookcase: how many binders and boxes,
//  how many cards are put away in them, and what they're worth.
//

import SwiftUI

struct BookshelfSummary: View {
    let containerCount: Int
    let cardCount: Int
    let value: Double

    var body: some View {
        HStack(spacing: 0) {
            BookshelfStat(value: Text(containerCount, format: .number), label: "Binders & Boxes")
            Divider().frame(height: 28).overlay(Color.lorcanaGold.opacity(0.4))
            BookshelfStat(value: Text(cardCount, format: .number), label: "Cards Stored")
            Divider().frame(height: 28).overlay(Color.lorcanaGold.opacity(0.4))
            BookshelfStat(value: Text(value, format: .currency(code: "USD").precision(.fractionLength(0))), label: "Value")
        }
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.35))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.lorcanaGold.opacity(0.35), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }
}
