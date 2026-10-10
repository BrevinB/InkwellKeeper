//
//  AddToContainerSheet.swift
//  Inkwell Keeper
//
//  Pick unsorted cards to put into a container. Tap a card to add a copy (again for
//  more); with a target pocket, one tap places that card and closes.
//

import SwiftUI

struct AddToContainerSheet: View {
    let container: StorageContainer
    /// When set, the chosen card goes into exactly this binder pocket.
    let targetSlot: Int?
    /// In a set binder, the card that belongs in the target pocket.
    let suggestedCard: LorcanaCard?

    @Environment(StorageManager.self) private var storageManager
    @Environment(CollectionManager.self) private var collectionManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var searchText = ""
    @State private var unsortedByIdentity: [String: Int] = [:]
    @State private var selection: [String: Int] = [:]
    @State private var storedCount = 0
    @State private var hitRoomLimit = 0

    private var isSetBinder: Bool { container.linkedSetName != nil }

    private var candidates: [LorcanaCard] {
        // Set checklist binders only list their set's cards whose numbered pocket is
        // still empty — and, when filling one pocket, only the card that belongs there.
        let occupied = isSetBinder ? storageManager.occupiedSlots(in: container) : []
        let unsorted = collectionManager.collectedCards.filter { card in
            guard (unsortedByIdentity[CollectionManager.identityKey(for: card)] ?? 0) > 0,
                  storageManager.accepts(card, in: container) else { return false }
            guard isSetBinder else { return true }
            guard let pocket = storageManager.setPocket(for: card, in: container) else { return false }
            if occupied.contains(pocket) {
                // A foil can still upgrade the normal copy holding its pocket.
                return targetSlot == nil && storageManager.upgradeTarget(for: card, in: container) != nil
            }
            return targetSlot == nil || pocket == targetSlot
        }
        let matching = searchText.isEmpty ? unsorted : unsorted.filter {
            $0.name.localizedStandardContains(searchText) || $0.setName.localizedStandardContains(searchText)
        }
        return BinderSortOrder.setNumber.sorted(matching, setOrder: BinderSortOrder.catalogSetOrder())
    }

    private var suggestion: LorcanaCard? {
        guard let suggestedCard else { return nil }
        return candidates.first {
            $0.setName == suggestedCard.setName && $0.cardNumber == suggestedCard.cardNumber
        }
    }

    private var selectedTotal: Int { selection.values.reduce(0, +) }

    /// Room left after the current selection; nil when the container has no limit.
    private var roomLeft: Int? {
        storageManager.freeSpace(in: container).map { max(0, $0 - selectedTotal) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AddToContainerHeader(
                    container: container,
                    storedCount: storedCount,
                    selectedCount: selectedTotal,
                    roomLeft: targetSlot == nil ? roomLeft : nil
                )

                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if candidates.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if let suggestedCard, targetSlot != nil {
                        ContentUnavailableView(
                            "No \(suggestedCard.name) to Put Here",
                            systemImage: "rectangle.portrait.slash",
                            description: Text("This pocket is for #\(suggestedCard.cardNumber ?? 0). You don't have an unsorted copy yet.")
                        )
                    } else if let setName = container.linkedSetName {
                        ContentUnavailableView(
                            "Nothing to Add",
                            systemImage: "checkmark.seal",
                            description: Text("You have no unsorted \(setName) cards for the empty pockets.")
                        )
                    } else {
                        ContentUnavailableView(
                            "Everything's Put Away",
                            systemImage: "checkmark.seal",
                            description: Text("Every card you own already has a home.")
                        )
                    }
                } else {
                    ScrollView {
                        if let suggestion {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Belongs in this pocket")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(.lorcanaGold)
                                AddCandidateTile(
                                    card: suggestion,
                                    selected: 0,
                                    available: unsortedByIdentity[CollectionManager.identityKey(for: suggestion)] ?? 0
                                ) { choose(suggestion) }
                                .frame(width: 110)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 12) {
                            ForEach(candidates, id: \.variantAwareId) { card in
                                let key = CollectionManager.identityKey(for: card)
                                AddCandidateTile(
                                    card: card,
                                    selected: selection[key] ?? 0,
                                    available: unsortedByIdentity[key] ?? 0,
                                    isUpgrade: isSetBinder && storageManager.upgradeTarget(for: card, in: container) != nil
                                ) { choose(card) }
                                .contextMenu {
                                    if (selection[key] ?? 0) > 0 {
                                        Button("Clear Selection", systemImage: "xmark") {
                                            selection[key] = nil
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle(targetSlot == nil ? "Add Cards" : "Fill Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if targetSlot == nil, selectedTotal > 0 {
                    Button(action: putAway) {
                        Text("Put Away ^[\(selectedTotal) Card](inflect: true)")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.lorcanaGold)
                    .foregroundStyle(Color.lorcanaDark)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: selectedTotal > 0)
            .sensoryFeedback(.selection, trigger: selectedTotal)
            .sensoryFeedback(.success, trigger: storedCount)
            .sensoryFeedback(.warning, trigger: hitRoomLimit)
            .onAppear {
                unsortedByIdentity = storageManager.unsortedQuantitiesByIdentity()
            }
        }
        .tint(.lorcanaGold)
    }

    private func choose(_ card: LorcanaCard) {
        if let targetSlot {
            if storageManager.place(card, atSlot: targetSlot, in: container) {
                storedCount += 1
                closeSoon()
            }
            return
        }
        let key = CollectionManager.identityKey(for: card)
        // A checklist pocket holds one card, so a foil and a normal of the same number
        // compete for it: choosing one clears the other.
        let available = isSetBinder ? min(1, unsortedByIdentity[key] ?? 0) : unsortedByIdentity[key] ?? 0
        let current = selection[key] ?? 0
        if isSetBinder, current == 0, let pocket = storageManager.setPocket(for: card, in: container) {
            for other in candidates where CollectionManager.identityKey(for: other) != key
                && storageManager.setPocket(for: other, in: container) == pocket {
                selection[CollectionManager.identityKey(for: other)] = nil
            }
        }
        // Tapping past the last unsorted copy clears the card; tapping when the
        // container has no room left does nothing but warn.
        if current < available, roomLeft == 0 {
            hitRoomLimit += 1
            return
        }
        withAnimation(.bouncy) {
            selection[key] = current < available ? current + 1 : nil
        }
    }

    private func putAway() {
        var total = 0
        for card in candidates {
            let key = CollectionManager.identityKey(for: card)
            guard let count = selection[key], count > 0 else { continue }
            if storageManager.upgradeTarget(for: card, in: container) != nil {
                total += storageManager.upgradeToFoil(card, in: container) ? 1 : 0
            } else {
                total += storageManager.store(card, quantity: count, in: container, source: "picker")
            }
        }
        withAnimation(reduceMotion ? nil : .bouncy) {
            storedCount += total
            selection = [:]
        }
        closeSoon()
    }

    private func closeSoon() {
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 700))
            dismiss()
        }
    }
}
