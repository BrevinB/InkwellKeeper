//
//  CardBackDrawing.swift
//  Inkwell Keeper
//
//  Canvas drawing of a card back, for cards peeking out of boxes and bins.
//

import SwiftUI

/// The back of a Lorcana-style card: dark navy with a gold frame and oval.
enum CardBackDrawing {
    static func draw(in rect: CGRect, context: inout GraphicsContext) {
        let radius = rect.width * 0.08
        let card = Path(roundedRect: rect, cornerRadius: radius)
        context.fill(card, with: .linearGradient(
            Gradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.28), Color.lorcanaDark]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
        context.stroke(card, with: .color(Color.lorcanaGold.opacity(0.9)), lineWidth: max(1, rect.width * 0.04))
        let oval = rect.insetBy(dx: rect.width * 0.22, dy: rect.height * 0.25)
        context.stroke(Path(ellipseIn: oval), with: .color(Color.lorcanaGold.opacity(0.6)), lineWidth: max(0.5, rect.width * 0.025))
    }
}
