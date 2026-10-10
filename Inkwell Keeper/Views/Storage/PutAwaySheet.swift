//
//  PutAwaySheet.swift
//  Inkwell Keeper
//
//  Put unsorted copies of one card into a binder or box.
//

import SwiftUI

struct PutAwaySheet: View {
    let card: LorcanaCard

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = 1
    @State private var showingCreate = false
    @State private var showingPaywall = false
    @State private var storedInto: UUID?

    private let subscriptionManager = SubscriptionManager.shared

    var body: some View {
        let unsorted = storageManager.unsortedQuantity(for: card)

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        StorageCardThumbnail(card: card)
                            .frame(width: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(card.name)
                                .font(.headline)
                            Text("^[\(unsorted) unsorted copy](inflect: true)")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                    if unsorted > 1 {
                        Stepper(value: $quantity, in: 1...unsorted) {
                            LabeledContent("Put away", value: "\(quantity)")
                        }
                    }
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))

                Section("Put into") {
                    ForEach(storageManager.containers) { container in
                        let canUpgrade = storageManager.upgradeTarget(for: card, in: container) != nil
                        let refusal = canUpgrade ? nil : storageManager.refusal(for: card, in: container)
                        Button {
                            if canUpgrade {
                                upgrade(in: container)
                            } else {
                                putAway(into: container)
                            }
                        } label: {
                            PutAwayContainerRow(
                                container: container,
                                isChosen: storedInto == container.id,
                                freeSpace: storageManager.freeSpace(in: container),
                                refusal: storedInto == container.id ? nil : refusal,
                                upgradeNote: canUpgrade && storedInto == nil
                                    ? String(localized: "Upgrade to foil · the normal copy goes to Unsorted")
                                    : nil
                            )
                        }
                        .disabled(storedInto != nil || refusal != nil)
                        .accessibilityHint(refusal ?? "")
                    }

                    Button("New Binder or Box", systemImage: "plus") {
                        if storageManager.canCreateContainer(isSubscribed: subscriptionManager.isSubscribed) {
                            showingCreate = true
                        } else {
                            showingPaywall = true
                        }
                    }
                    .foregroundStyle(.lorcanaGold)
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }
            .scrollContentBackground(.hidden)
            .background(LorcanaBackground())
            .navigationTitle("Put Away")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: storedInto)
            .sheet(isPresented: $showingCreate) {
                ContainerEditorSheet(container: nil)
            }
            .sheet(isPresented: $showingPaywall) {
                RulesPaywallView(source: "storageLimit")
            }
        }
        .tint(.lorcanaGold)
    }

    private func upgrade(in container: StorageContainer) {
        guard storageManager.upgradeToFoil(card, in: container) else { return }
        withAnimation(.bouncy) { storedInto = container.id }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            dismiss()
        }
    }

    private func putAway(into container: StorageContainer) {
        let stored = storageManager.store(card, quantity: quantity, in: container, source: "detail")
        guard stored > 0 else { return }
        withAnimation(.bouncy) { storedInto = container.id }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            dismiss()
        }
    }
}
