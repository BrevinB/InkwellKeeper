//
//  PocketContentsSheet.swift
//  Inkwell Keeper
//
//  What's in one binder pocket. Collectors who keep several copies in one pocket —
//  say three normals and a foil — set how many of each printing are in it here.
//

import SwiftUI

struct PocketContentsSheet: View {
    let container: StorageContainer
    let slot: Int
    /// The card the pocket held when opened. Kept so its steppers stay put even if
    /// every copy is taken out.
    let card: LorcanaCard

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss
    @State private var detailCard: LorcanaCard?
    @State private var changeFeedback = 0

    var body: some View {
        let position = container.binderLayout.position(of: slot)
        let printings = storageManager.stackPrintings(of: card, atSlot: slot, in: container)
        let total = storageManager.items(atSlot: slot, in: container).count

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        StorageCardThumbnail(card: card)
                            .frame(width: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.headline)
                            Text("Page \(position.page + 1), pocket \(position.pocket + 1)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))

                Section {
                    ForEach(printings, id: \.variant) { printing in
                        PocketCopyStepper(
                            variant: printing.variant,
                            count: storageManager.stackCount(of: printing, atSlot: slot, in: container),
                            unsorted: storageManager.unsortedQuantity(for: printing)
                        ) { newCount in
                            withAnimation(.snappy) {
                                storageManager.setStackCount(newCount, of: printing, atSlot: slot, in: container)
                            }
                            changeFeedback += 1
                        }
                    }
                } header: {
                    Text("In this pocket")
                } footer: {
                    Text("Copies come from your unsorted cards, and go back to Unsorted when you take them out.")
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))

                Section {
                    Button("Card Details", systemImage: "info.circle") {
                        detailCard = card
                    }
                    if total > 0 {
                        Button("Take All Out of Binder", systemImage: "tray.and.arrow.up", role: .destructive) {
                            storageManager.emptyPocket(atSlot: slot, in: container)
                            dismiss()
                        }
                    }
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }
            .scrollContentBackground(.hidden)
            .background(LorcanaBackground())
            .navigationTitle("Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: changeFeedback)
            .sheet(item: $detailCard) { card in
                CollectionCardDetailView(
                    card: card,
                    isPresented: Binding(get: { detailCard != nil }, set: { if !$0 { detailCard = nil } })
                )
                .presentationSizing(.page)
            }
        }
        .tint(.lorcanaGold)
    }
}
