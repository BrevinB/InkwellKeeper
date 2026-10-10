//
//  BoxCardCell.swift
//  Inkwell Keeper
//
//  A card inside a box, with its copy count.
//

import SwiftUI

struct BoxCardCell: View {
    let item: StoredCard
    /// Whether it's chosen while selecting cards to move; nil when not selecting.
    var isSelected: Bool?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                StorageCardThumbnail(card: item.toLorcanaCard)
                    .overlay(alignment: .topTrailing) {
                        if item.quantity > 1 {
                            Text("×\(item.quantity)")
                                .font(.caption)
                                .bold()
                                .monospacedDigit()
                                .foregroundStyle(Color.lorcanaDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.lorcanaGold))
                                .padding(4)
                                .contentTransition(.numericText())
                        }
                    }
                    .selectionMark(isSelected)
                Text(item.name)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.cardVariant == .normal ? item.name : "\(item.name), \(item.variant)")
        .accessibilityValue("\(item.quantity) copies")
        .accessibilityHint(isSelected == nil ? "Shows card details" : "Selects or deselects this card")
        .accessibilityAddTraits(isSelected == true ? .isSelected : [])
    }
}
