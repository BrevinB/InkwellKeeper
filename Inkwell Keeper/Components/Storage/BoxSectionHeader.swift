//
//  BoxSectionHeader.swift
//  Inkwell Keeper
//
//  Pinned set name above each group of cards in a box.
//

import SwiftUI

struct BoxSectionHeader: View {
    let setName: String
    let count: Int

    var body: some View {
        HStack {
            Text(setName)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.lorcanaGold)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.gray)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
