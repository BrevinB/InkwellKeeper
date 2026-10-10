//
//  CardHeap.swift
//  Inkwell Keeper
//
//  Loose card backs heaped in an open bin, poking up above its rim.
//

import SwiftUI

struct CardHeap: View {
    let metrics: RenderedArtworkMetrics

    /// Across the opening (0–1), each card's tilt in degrees.
    private static let pile: [(across: Double, tilt: Double)] = [(0.15, -18), (0.38, 8), (0.62, -6), (0.85, 16)]

    var body: some View {
        Canvas { context, size in
            guard let rimY = metrics.rimY else { return }
            let cardWidth = size.width * metrics.cardWidth
            let cardHeight = cardWidth * 88 / 63
            let left = size.width * metrics.openingLeft
            let span = size.width * (metrics.openingRight - metrics.openingLeft)
            for (index, card) in Self.pile.enumerated() {
                let rect = CGRect(
                    x: left + span * card.across - cardWidth / 2,
                    y: size.height * rimY - cardHeight * (index.isMultiple(of: 2) ? 0.55 : 0.7),
                    width: cardWidth,
                    height: cardHeight
                )
                var cardContext = context
                cardContext.translateBy(x: rect.midX, y: rect.midY)
                cardContext.rotate(by: .degrees(card.tilt))
                cardContext.translateBy(x: -rect.midX, y: -rect.midY)
                CardBackDrawing.draw(in: rect, context: &cardContext)
            }
        }
    }
}
