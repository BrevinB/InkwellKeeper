//
//  CapacityMeter.swift
//  Inkwell Keeper
//
//  How full a box is: a bar that shifts from gold to orange to red as it fills.
//

import SwiftUI

struct CapacityMeter: View {
    let count: Int
    let capacity: Int

    private var fraction: Double {
        min(1, Double(count) / Double(max(1, capacity)))
    }

    private var tint: Color {
        switch fraction {
        case ..<0.8: .lorcanaGold
        case ..<1: .orange
        default: .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            ProgressView(value: fraction)
                .tint(tint)
                .animation(.spring(duration: 0.6), value: fraction)

            Text("\(count) of \(capacity) cards")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(count > capacity ? .red : .gray)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capacity")
        .accessibilityValue("\(count) of \(capacity) cards")
    }
}
