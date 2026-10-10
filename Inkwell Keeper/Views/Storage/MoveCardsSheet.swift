//
//  MoveCardsSheet.swift
//  Inkwell Keeper
//
//  Where to send the cards selected in a binder or box: back to Unsorted, or into
//  any other binder or box. Shows how much room each has; full ones can't be picked.
//

import SwiftUI

struct MoveCardsSheet: View {
    let items: [StoredCard]
    let source: StorageContainer
    let onMoved: (StorageManager.BulkMoveResult) -> Void

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss

    private var copies: Int { items.reduce(0) { $0 + $1.quantity } }

    private var destinations: [StorageContainer] {
        storageManager.containers.filter { $0.id != source.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { move(to: nil) } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unsorted")
                                    .foregroundStyle(.white)
                                Text("Take them out of this \(source.kind.displayName.lowercased())")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        } icon: {
                            Image(systemName: "tray.and.arrow.up")
                                .foregroundStyle(.lorcanaGold)
                        }
                    }
                }

                if !destinations.isEmpty {
                    Section {
                        ForEach(destinations) { destination in
                            let isFull = storageManager.isFull(destination)
                            Button { move(to: destination) } label: {
                                PutAwayContainerRow(
                                    container: destination,
                                    isChosen: false,
                                    freeSpace: storageManager.freeSpace(in: destination),
                                    refusal: isFull ? String(localized: "Full") : nil
                                )
                            }
                            .disabled(isFull)
                        }
                    } header: {
                        Text("Move To")
                    } footer: {
                        Text("Cards that don't fit stay where they are. Set checklist binders only take cards from their set, each in its numbered pocket.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LorcanaBackground())
            .navigationTitle(Text("Move ^[\(copies) Card](inflect: true)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.lorcanaGold)
    }

    private func move(to destination: StorageContainer?) {
        let result = withAnimation(.snappy) {
            storageManager.moveItems(items, to: destination)
        }
        onMoved(result)
        dismiss()
    }
}
