//
//  PocketStackBadge.swift
//  Inkwell Keeper
//
//  How many copies share a binder pocket, with a sparkle when one is a foil.
//

import SwiftUI

struct PocketStackBadge: View {
    let count: Int
    let hasFoil: Bool

    var body: some View {
        HStack(spacing: 1) {
            if hasFoil {
                Image(systemName: "sparkles")
            }
            Text("×\(count)")
                .monospacedDigit()
        }
        .font(.caption2)
        .bold()
        .foregroundStyle(Color.lorcanaDark)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.lorcanaGold))
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        PocketStackBadge(count: 4, hasFoil: true)
        PocketStackBadge(count: 2, hasFoil: false)
    }
    .padding()
    .background(Color.lorcanaDark)
}
