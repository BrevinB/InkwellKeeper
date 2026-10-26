//
//  PocketCopyStepper.swift
//  Inkwell Keeper
//
//  How many copies of one printing (Normal, Foil, …) are in a binder pocket.
//

import SwiftUI

struct PocketCopyStepper: View {
    let variant: CardVariant
    let count: Int
    /// Copies of this printing not stored anywhere, which can go in the pocket.
    let unsorted: Int
    let onChange: (Int) -> Void

    var body: some View {
        Stepper(
            value: Binding(get: { count }, set: onChange),
            in: 0...(count + unsorted)
        ) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(variant.displayName)
                    if variant == .foil {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.lorcanaGold)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    Text("\(count)")
                        .monospacedDigit()
                        .bold()
                }
                Text(unsorted == 0 ? String(localized: "None unsorted") : String(localized: "\(unsorted) more unsorted"))
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
        .accessibilityValue("\(count)")
        .accessibilityHint(unsorted == 0 ? "No more unsorted copies to add" : "\(unsorted) more unsorted copies can go in")
    }
}
