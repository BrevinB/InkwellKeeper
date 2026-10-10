//
//  StorageChip.swift
//  Inkwell Keeper
//
//  Capsule choice chip used by the storage editor pickers.
//

import SwiftUI

struct StorageChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    var showsProPill = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
            if showsProPill {
                ProPill()
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isSelected ? Color.lorcanaDark : Color.white)
        .background(Capsule().fill(isSelected ? Color.lorcanaGold : Color.white.opacity(0.08)))
    }
}
