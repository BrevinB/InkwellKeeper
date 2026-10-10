//
//  CardsRising.swift
//  Inkwell Keeper
//
//  A fan of card backs rising out of an open box as its lid lifts.
//

import SwiftUI

struct CardsRising: View {
    /// 0 = tucked below the rim, 1 = fanned up to the metrics' peak.
    var lift: Double
    let metrics: RenderedArtworkMetrics

    var body: some View {
        Canvas { context, size in
            guard lift > 0, let rimY = metrics.rimY else { return }
            let cardWidth = size.width * metrics.cardWidth
            let cardHeight = cardWidth * 88 / 63
            let restingTop = size.height * rimY + cardHeight * 0.05
            let fullRise = restingTop - size.height * metrics.cardPeakY
            for offset in [-0.9, 0.0, 0.9] {
                // The middle card rises highest; the outer two lean away from it.
                let rise = fullRise * lift * (offset == 0 ? 1 : 0.8)
                let cardRect = CGRect(
                    x: size.width / 2 - cardWidth / 2 + offset * cardWidth * 0.6,
                    y: restingTop - rise,
                    width: cardWidth,
                    height: cardHeight
                )
                var cardContext = context
                cardContext.translateBy(x: cardRect.midX, y: cardRect.maxY)
                cardContext.rotate(by: .degrees(offset * 9 * lift))
                cardContext.translateBy(x: -cardRect.midX, y: -cardRect.maxY)
                CardBackDrawing.draw(in: cardRect, context: &cardContext)
            }
        }
    }
}
