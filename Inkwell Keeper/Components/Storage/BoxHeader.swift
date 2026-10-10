//
//  BoxHeader.swift
//  Inkwell Keeper
//
//  The open box at the top of a box view, with its fill meter and value.
//

import SwiftUI

struct BoxHeader: View {
    let container: StorageContainer
    let lidLift: Double
    let value: Double

    var body: some View {
        VStack(spacing: 12) {
            AnimatableContainerArtwork(container: container, lidLift: lidLift)
                .frame(height: 130)
                .shadow(color: container.coverColor.highlight.opacity(0.35), radius: 16, y: 8)

            if let capacity = container.capacity {
                CapacityMeter(count: container.cardCount, capacity: capacity)
                    .padding(.horizontal, 40)
            } else {
                Text("^[\(container.cardCount) card](inflect: true)")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .contentTransition(.numericText())
            }

            if value > 0 {
                Text(value, format: .currency(code: "USD"))
                    .font(.headline)
                    .foregroundStyle(.lorcanaGold)
                    .contentTransition(.numericText())
            }
        }
        .padding(.top, 8)
        .animation(.snappy, value: container.cardCount)
    }
}
