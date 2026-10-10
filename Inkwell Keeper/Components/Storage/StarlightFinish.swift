//
//  StarlightFinish.swift
//  Inkwell Keeper
//
//  Twinkling gold sparkles for the Starlight cover finish.
//

import SwiftUI

struct StarlightFinish: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: !animated)) { timeline in
            let time = animated ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, size in
                var generator = SeededGenerator(seed: 42)
                for index in 0..<16 {
                    let point = CGPoint(
                        x: Double.random(in: 0...size.width, using: &generator),
                        y: Double.random(in: 0...size.height, using: &generator)
                    )
                    let phase = Double.random(in: 0...(2 * .pi), using: &generator)
                    let twinkle = (sin(time * 1.8 + phase) + 1) / 2
                    let base = min(size.width, size.height) * (index.isMultiple(of: 4) ? 0.09 : 0.04)
                    let starSize = base * (0.6 + 0.4 * twinkle)
                    context.fill(
                        SparkleShape().path(in: CGRect(
                            x: point.x - starSize / 2,
                            y: point.y - starSize / 2,
                            width: starSize,
                            height: starSize
                        )),
                        with: .color(Color.lorcanaGold.opacity(0.35 + 0.55 * twinkle))
                    )
                }
            }
        }
    }
}
