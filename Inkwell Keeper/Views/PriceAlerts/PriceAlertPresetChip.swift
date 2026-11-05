//
//  PriceAlertPresetChip.swift
//  Inkwell Keeper
//
//  A one-tap target: "−20% · $36".
//

import SwiftUI

struct PriceAlertPresetChip: View {
    /// Distance from today's price, as a fraction.
    let distance: Double
    let price: Double
    let direction: PriceAlertDirection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(direction == .below ? "−\(distance, format: .percent)" : "+\(distance, format: .percent)")
                    .font(.caption.bold())
                Text(price, format: .currency(code: "USD"))
                    .font(.caption2)
                    .monospacedDigit()
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? direction.tint : .white.opacity(0.06), in: .rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
