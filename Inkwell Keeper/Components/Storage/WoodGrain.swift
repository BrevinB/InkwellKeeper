//
//  WoodGrain.swift
//  Inkwell Keeper
//
//  Faint, fixed streaks of grain for the shelf's front edge.
//

import SwiftUI

struct WoodGrain: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 11)
            for _ in 0..<Int(size.width / 18) {
                let y = Double.random(in: 1...max(1.5, size.height - 1), using: &generator)
                let x = Double.random(in: 0...size.width, using: &generator)
                let length = Double.random(in: 30...120, using: &generator)
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addQuadCurve(
                    to: CGPoint(x: x + length, y: y + Double.random(in: -1.5...1.5, using: &generator)),
                    control: CGPoint(x: x + length / 2, y: y + Double.random(in: -2...2, using: &generator))
                )
                context.stroke(streak, with: .color(.black.opacity(0.5)), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}
