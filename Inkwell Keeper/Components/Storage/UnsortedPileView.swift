//
//  UnsortedPileView.swift
//  Inkwell Keeper
//
//  The loose pile at the start of the shelf: every copy not yet put away.
//  Tapping it filters the collection to those cards.
//

import SwiftUI

struct UnsortedPileView: View {
    let count: Int
    let isSelected: Bool

    var body: some View {
        ShelfSlot(
            title: String(localized: "Unsorted"),
            subtitle: "^[\(count) card](inflect: true)",
            isHighlighted: isSelected
        ) {
            Canvas { context, size in
                // Leave margin so the tilted cards stay inside the canvas.
                let cardHeight = size.height * 0.84
                let cardWidth = cardHeight * 63 / 88
                for (index, tilt) in [-12.0, 7.0, -2.0].enumerated() {
                    let rect = CGRect(
                        x: size.width / 2 - cardWidth / 2 + CGFloat(index - 1) * cardWidth * 0.22,
                        y: size.height - cardHeight,
                        width: cardWidth,
                        height: cardHeight
                    )
                    var cardContext = context
                    cardContext.translateBy(x: rect.midX, y: rect.maxY)
                    cardContext.rotate(by: .degrees(tilt))
                    cardContext.translateBy(x: -rect.midX, y: -rect.maxY)
                    CardBackDrawing.draw(in: rect, context: &cardContext)
                }
            }
            .frame(width: 84, height: 66)
            .shadow(color: isSelected ? .lorcanaGold.opacity(0.7) : .clear, radius: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Unsorted cards")
        .accessibilityValue("\(count) cards")
        .accessibilityHint(isSelected ? "Shows your whole collection" : "Shows only cards that aren't put away")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
