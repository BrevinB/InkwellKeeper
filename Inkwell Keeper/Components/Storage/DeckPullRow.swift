//
//  DeckPullRow.swift
//  Inkwell Keeper
//
//  One card to pull: what, how many, and exactly where (binder page and pocket).
//  Tap the circle once the card is in your hand.
//

import SwiftUI

struct DeckPullRow: View {
    let pull: DeckPullPlan.Pull
    let onPull: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            StorageCardThumbnail(card: pull.card)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(pull.card.name)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if pull.card.variant != .normal {
                        Text(pull.card.variant.displayName)
                            .foregroundStyle(.purple)
                    }
                    if let location = pocketText {
                        Text(location)
                            .foregroundStyle(.gray)
                    }
                }
                .font(.caption)
            }

            Spacer()

            Text("×\(pull.quantity)")
                .monospacedDigit()
                .foregroundStyle(.gray)

            Button(action: onPull) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.lorcanaGold)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Pulled \(pull.card.name)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Mark as pulled", onPull)
    }

    /// "p.3, pocket 5" or "p.3 pockets 5, 6" — where to reach in the binder.
    private var pocketText: String? {
        guard let first = pull.pockets.first else { return nil }
        let samePage = pull.pockets.allSatisfy { $0.page == first.page }
        if pull.pockets.count == 1 {
            return "p.\(first.page), pocket \(first.pocket)"
        }
        if samePage {
            return "p.\(first.page), pockets \(pull.pockets.map { String($0.pocket) }.joined(separator: ", "))"
        }
        return pull.pockets.map { "p.\($0.page)/\($0.pocket)" }.joined(separator: ", ")
    }
}
