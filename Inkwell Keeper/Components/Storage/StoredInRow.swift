//
//  StoredInRow.swift
//  Inkwell Keeper
//
//  One "Stored In" location: the container's little artwork, its name, and where.
//

import SwiftUI

struct StoredInRow: View {
    let location: StorageAllocation
    let container: StorageContainer
    /// Set when the container is a deck box holding a built deck.
    var deckName: String?

    var body: some View {
        HStack(spacing: 10) {
            ContainerArtwork(kind: container.kind, color: container.coverColor, style: .classic)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(location.containerName)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                if let deckName {
                    Label("In deck \(deckName)", systemImage: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold.opacity(0.8))
                } else if let pockets = location.pocketSummary {
                    Text(pockets)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            Text("×\(location.quantity)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.gray)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.lorcanaGold.opacity(0.6))
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(container.kind.usesSlots ? "Opens the binder at this card" : "Opens this \(container.kind.displayName.lowercased())")
    }
}
