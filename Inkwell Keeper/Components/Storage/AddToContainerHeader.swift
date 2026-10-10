//
//  AddToContainerHeader.swift
//  Inkwell Keeper
//
//  The container at the top of the card picker. Its lid opens while cards are
//  selected and it bounces as they go in.
//

import SwiftUI

struct AddToContainerHeader: View {
    let container: StorageContainer
    let storedCount: Int
    let selectedCount: Int
    /// Room left after the selection; nil for containers without a limit.
    let roomLeft: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            ContainerArtwork(
                kind: container.kind,
                color: container.coverColor,
                style: container.cover,
                lidLift: selectedCount > 0 && !reduceMotion ? 0.6 : 0
            )
            .frame(height: 64)
            .animation(.bouncy, value: selectedCount > 0)
            .modifier(PopEffect(trigger: storedCount, isEnabled: !reduceMotion, peak: 1.2))

            VStack(alignment: .leading, spacing: 2) {
                Text(container.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(storedCount > 0 ? "Added ^[\(storedCount) card](inflect: true)" : "Choose unsorted cards to put here")
                    .font(.subheadline)
                    .foregroundStyle(storedCount > 0 ? .green : .gray)
                    .contentTransition(.numericText())
                if let roomLeft, storedCount == 0 {
                    Text(roomLeft == 0 ? "No room left" : "Room for \(roomLeft) more")
                        .font(.caption)
                        .foregroundStyle(roomLeft == 0 ? .orange : .gray)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: roomLeft)
                }
            }
            Spacer()
        }
        .padding()
    }
}
