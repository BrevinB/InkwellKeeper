//
//  PriceAlertDistanceBadge.swift
//  Inkwell Keeper
//
//  How far the target sits from today's price — "18% below today".
//

import SwiftUI

struct PriceAlertDistanceBadge: View {
    /// The target's distance from today's price, as a fraction.
    let distance: Double

    private var isBelow: Bool { distance < 0 }

    var body: some View {
        Group {
            if abs(distance) < 0.005 {
                Text("At today's price")
            } else {
                Text(
                    isBelow ? "\(abs(distance), format: .percent.precision(.fractionLength(0))) below today"
                        : "\(abs(distance), format: .percent.precision(.fractionLength(0))) above today"
                )
            }
        }
        .font(.caption.bold())
        .monospacedDigit()
        .foregroundStyle(isBelow ? PriceAlertDirection.below.tint : PriceAlertDirection.above.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.06), in: .capsule)
        .contentTransition(.numericText())
    }
}
