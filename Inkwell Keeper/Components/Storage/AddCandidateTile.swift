//
//  AddCandidateTile.swift
//  Inkwell Keeper
//
//  A card in the picker, with a gold count badge for copies selected.
//

import SwiftUI

struct AddCandidateTile: View {
    let card: LorcanaCard
    let selected: Int
    let available: Int
    /// Choosing this foil replaces the normal copy already in its checklist pocket.
    var isUpgrade = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                StorageCardThumbnail(card: card)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.lorcanaGold, lineWidth: selected > 0 ? 3 : 0)
                    }
                    .overlay(alignment: .topTrailing) {
                        if selected > 0 {
                            Text("\(selected)")
                                .font(.caption)
                                .bold()
                                .monospacedDigit()
                                .foregroundStyle(Color.lorcanaDark)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.lorcanaGold))
                                .padding(4)
                                .contentTransition(.numericText())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .scaleEffect(selected > 0 ? 0.95 : 1)

                Text(card.name)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if isUpgrade {
                    Label("Upgrade", systemImage: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(.lorcanaGold)
                } else {
                    Text("\(available) unsorted")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.name), \(card.variant.displayName)")
        .accessibilityValue(selected > 0 ? "\(selected) of \(available) selected" : "\(available) unsorted")
        .accessibilityHint(isUpgrade ? "Replaces the normal copy in its pocket" : "")
        .accessibilityAddTraits(selected > 0 ? .isSelected : [])
    }
}
