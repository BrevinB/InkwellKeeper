//
//  ArrangeHint.swift
//  Inkwell Keeper
//
//  The banner explaining arrange mode.
//

import SwiftUI

struct ArrangeHint: View {
    let hasPickedUp: Bool

    var body: some View {
        Label(
            hasPickedUp
                ? "Tap a pocket to put the card there. Turn pages to move it further."
                : "Tap a card to pick it up, or drag it to another pocket.",
            systemImage: hasPickedUp ? "hand.point.up.left.fill" : "hand.draw.fill"
        )
        .font(.footnote)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.lorcanaDark.opacity(0.9)).stroke(Color.lorcanaGold.opacity(0.4)))
        .contentTransition(.opacity)
        .animation(.snappy, value: hasPickedUp)
    }
}
