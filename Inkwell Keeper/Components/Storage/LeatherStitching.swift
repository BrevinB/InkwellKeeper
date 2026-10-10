//
//  LeatherStitching.swift
//  Inkwell Keeper
//
//  Stitched border and grain for the leather cover finish.
//

import SwiftUI

struct LeatherStitching: View {
    let color: StorageCoverColor

    var body: some View {
        Canvas { context, size in
            let inset = min(size.width, size.height) * 0.07
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
            context.stroke(
                Path(roundedRect: rect, cornerRadius: inset),
                with: .color(color.trim.opacity(0.55)),
                style: StrokeStyle(lineWidth: max(1, size.width * 0.012), dash: [size.width * 0.03, size.width * 0.02])
            )
            // Grain: a fixed scatter of faint specks.
            var generator = SeededGenerator(seed: 7)
            for _ in 0..<90 {
                let point = CGPoint(
                    x: Double.random(in: 0...size.width, using: &generator),
                    y: Double.random(in: 0...size.height, using: &generator)
                )
                let speck = CGRect(x: point.x, y: point.y, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: speck), with: .color(.black.opacity(0.18)))
            }
        }
        .blendMode(.multiply)
    }
}
