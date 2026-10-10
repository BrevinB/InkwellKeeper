//
//  StoredInSection.swift
//  Inkwell Keeper
//
//  "Where is it?" on a card's detail: each binder or box holding copies (tap to go
//  straight to the pocket), how many are still unsorted, and a Put Away button.
//  The host navigation stack registers the `StorageRoute` destination.
//

import SwiftUI

struct StoredInSection: View {
    let card: LorcanaCard

    @Environment(StorageManager.self) private var storageManager
    @State private var showingPutAway = false

    var body: some View {
        let locations = storageManager.locations(for: card)
        let unsorted = storageManager.unsortedQuantity(for: card)

        if !locations.isEmpty || unsorted > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(card.variant == .foil ? "Stored In (Foil)" : "Stored In")
                        .font(.headline)
                        .foregroundStyle(.lorcanaGold)
                    Spacer()
                    if unsorted > 0 {
                        Button("Put Away", systemImage: "tray.and.arrow.down.fill") {
                            showingPutAway = true
                        }
                        .font(.subheadline)
                        .buttonStyle(.bordered)
                        .tint(.lorcanaGold)
                    }
                }

                ForEach(locations) { location in
                    if let container = storageManager.containers.first(where: { $0.id == location.containerId }) {
                        NavigationLink(value: StorageRoute(container: container, focusSlot: firstSlot(of: location, in: container))) {
                            StoredInRow(
                                location: location,
                                container: container,
                                deckName: container.linkedDeckId.flatMap(storageManager.deckName(for:))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if unsorted > 0 {
                    HStack {
                        Image(systemName: "square.stack.3d.down.right")
                            .font(.caption)
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                        Text("Unsorted")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        Spacer()
                        Text("×\(unsorted)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.gray)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 4)
            .sheet(isPresented: $showingPutAway) {
                PutAwaySheet(card: card)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func firstSlot(of location: StorageAllocation, in container: StorageContainer) -> Int? {
        guard let pocket = location.pockets.first else { return nil }
        return container.binderLayout.slot(page: pocket.page - 1, pocket: pocket.pocket - 1)
    }
}
