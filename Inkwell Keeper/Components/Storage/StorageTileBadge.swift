//
//  StorageTileBadge.swift
//  Inkwell Keeper
//
//  Small corner badge on a collection tile: gold when every copy is put away,
//  a "stored/owned" count when only some are.
//

import SwiftUI

struct StorageTileBadge: View {
    let stored: Int
    let owned: Int

    private var allStored: Bool { stored >= owned }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "archivebox.fill")
            if !allStored {
                Text("\(stored)/\(owned)")
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .bold()
        .foregroundStyle(allStored ? Color.lorcanaDark : .white)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Capsule().fill(allStored ? Color.lorcanaGold.opacity(0.95) : Color.black.opacity(0.7)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(allStored ? "All copies put away" : "\(stored) of \(owned) copies put away")
    }
}
