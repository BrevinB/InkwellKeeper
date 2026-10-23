//
//  AddToContainerSheet.swift
//  Inkwell Keeper
//
//  Pick cards to put into a container. Tap a card to add a copy (again for more);
//  with a target pocket, one tap places that card and closes. Picks come from
//  unsorted copies, or from every card in the catalog — catalog picks the collector
//  doesn't have unsorted are added to the collection as they go in.
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
    @State private var source: AddCardsSource = .unsorted
    /// All Cards mode: list foil printings instead of normal ones.
    @State private var showsFoil = false
    @State private var unsortedByIdentity: [String: Int] = [:]
    @State private var ownedByIdentity: [String: Int] = [:]
    @State private var selection: [String: Int] = [:]
    @State private var storedCount = 0
    @State private var hitRoomLimit = 0

    private var isSetBinder: Bool { container.linkedSetName != nil }
    private var isBrowsingAllCards: Bool { source == .allCards }

    private var candidates: [LorcanaCard] {
        let pool = isBrowsingAllCards ? catalogCandidates : unsortedCandidates
        guard !searchText.isEmpty else { return pool }
        return pool.filter {
            $0.name.localizedStandardContains(searchText) || $0.setName.localizedStandardContains(searchText)
        }
    }

    private var unsortedCandidates: [LorcanaCard] {
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
        return BinderSortOrder.setNumber.sorted(unsorted, setOrder: BinderSortOrder.catalogSetOrder())
    }

    /// Every printing that could go in right now, in catalog (set → number) order.
    /// Foil upgrades stay with unsorted picks; here a set binder only lists empty pockets.
    private var catalogCandidates: [LorcanaCard] {
        let cards = container.linkedSetName.map { SetsDataManager.shared.getCardsForSet($0) }
            ?? SetsDataManager.shared.getAllCards()
        let printings = cards.map { card in
            showsFoil && card.availableVariants().contains(.foil) ? card.withVariant(.foil) : card
        }
        guard isSetBinder else { return printings }
        let occupied = storageManager.occupiedSlots(in: container)
        return printings.filter { card in
            guard let pocket = storageManager.setPocket(for: card, in: container),
                  !occupied.contains(pocket) else { return false }
            return targetSlot == nil || pocket == targetSlot
        }
    }

    private var suggestion: LorcanaCard? {
        guard let suggestedCard else { return nil }
        return candidates.first {
            $0.setName == suggestedCard.setName && $0.cardNumber == suggestedCard.cardNumber
        }
    }

    private var selectedTotal: Int { selection.values.reduce(0, +) }

    /// Copies the collection will gain when the selection is put away.
    private var copiesToAdd: Int {
        AddCardsSource.copiesToAdd(selection: selection, unsorted: unsortedByIdentity)
    }

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
                    roomLeft: targetSlot == nil ? roomLeft : nil,
                    isBrowsingAllCards: isBrowsingAllCards
                )

                HStack {
                    Picker("Cards", selection: $source) {
                        ForEach(AddCardsSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)

                    if isBrowsingAllCards {
                        Toggle("Foil", systemImage: "sparkles", isOn: $showsFoil)
                            .toggleStyle(.button)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .animation(.snappy, value: isBrowsingAllCards)

                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                if candidates.isEmpty {
                    if !searchText.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else if isBrowsingAllCards {
                        ContentUnavailableView {
                            Label("Nothing to Add", systemImage: "checkmark.seal")
                        } description: {
                            if targetSlot == nil {
                                Text("Every pocket already has its card.")
                            } else if showsFoil {
                                Text("This pocket holds the normal printing. Turn off Foil to see it.")
                            } else {
                                Text("This pocket holds the foil printing. Turn on Foil to see it.")
                            }
                        }
                    } else if let suggestedCard, targetSlot != nil {
                        ContentUnavailableView {
                            Label("No \(suggestedCard.name) to Put Here", systemImage: "rectangle.portrait.slash")
                        } description: {
                            Text("This pocket is for #\(suggestedCard.cardNumber ?? 0). You don't have an unsorted copy yet.")
                        } actions: {
                            BrowseAllCardsButton { source = .allCards }
                        }
                    } else {
                        ContentUnavailableView {
                            Label(isSetBinder ? "Nothing to Add" : "Everything's Put Away", systemImage: "checkmark.seal")
                        } description: {
                            if let setName = container.linkedSetName {
                                Text("You have no unsorted \(setName) cards for the empty pockets.")
                            } else {
                                Text("Every card you own already has a home.")
                            }
                        } actions: {
                            BrowseAllCardsButton { source = .allCards }
                        }
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
                                    available: unsortedByIdentity[CollectionManager.identityKey(for: suggestion)] ?? 0,
                                    owned: owned(suggestion)
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
                                    owned: owned(card),
                                    isUpgrade: !isBrowsingAllCards && isSetBinder
                                        && storageManager.upgradeTarget(for: card, in: container) != nil
                                ) { choose(card) }
                                .contextMenu {
                                    if (selection[key] ?? 0) > 1 {
                                        Button("Remove One", systemImage: "minus") {
                                            selection[key, default: 1] -= 1
                                        }
                                    }
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
                    VStack(spacing: 6) {
                        if copiesToAdd > 0 {
                            Text("^[\(copiesToAdd) copy](inflect: true) will also be added to your collection")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .contentTransition(.numericText())
                        }
                        Button(action: putAway) {
                            Text("Put Away ^[\(selectedTotal) Card](inflect: true)")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.lorcanaGold)
                        .foregroundStyle(Color.lorcanaDark)
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: selectedTotal > 0)
            .animation(.snappy, value: copiesToAdd > 0)
            .sensoryFeedback(.selection, trigger: selectedTotal)
            .sensoryFeedback(.success, trigger: storedCount)
            .sensoryFeedback(.warning, trigger: hitRoomLimit)
            .onChange(of: source) {
                // Picks from one source don't carry over: an unsorted copy and a catalog
                // copy of the same card mean different things for the collection.
                selection = [:]
            }
            .onAppear {
                // A master set's foil pocket wants the foil printing.
                showsFoil = suggestedCard?.variant == .foil
                unsortedByIdentity = storageManager.unsortedQuantitiesByIdentity()
                ownedByIdentity = storageManager.ownedQuantitiesByIdentity() ?? [:]
            }
        }
        .tint(.lorcanaGold)
    }

    /// Copies owned, for catalog tiles; nil in unsorted mode so tiles show the unsorted count.
    private func owned(_ card: LorcanaCard) -> Int? {
        isBrowsingAllCards ? ownedByIdentity[CollectionManager.identityKey(for: card)] ?? 0 : nil
    }

    private func choose(_ card: LorcanaCard) {
        if let targetSlot {
            let placed = isBrowsingAllCards
                ? storageManager.placeAddingToCollection(card, atSlot: targetSlot, in: container, collection: collectionManager)
                : storageManager.place(card, atSlot: targetSlot, in: container)
            if placed {
                storedCount += 1
                closeSoon()
            }
            return
        }
        let key = CollectionManager.identityKey(for: card)
        let unsorted = unsortedByIdentity[key] ?? 0
        // A checklist pocket holds one card, so a foil and a normal of the same number
        // compete for it: choosing one clears the other. The catalog has no ceiling
        // beyond the container's room.
        let available = isSetBinder ? (isBrowsingAllCards ? 1 : min(1, unsorted))
            : isBrowsingAllCards ? Int.max : unsorted
        let current = selection[key] ?? 0
        if isSetBinder, current == 0, let pocket = storageManager.setPocket(for: card, in: container) {
            for other in candidates where CollectionManager.identityKey(for: other) != key
                && storageManager.setPocket(for: other, in: container) == pocket {
                selection[CollectionManager.identityKey(for: other)] = nil
            }
        }
        // Tapping past the last available copy clears the card; tapping when the
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
        if isBrowsingAllCards {
            let picks = candidates.compactMap { card -> (card: LorcanaCard, quantity: Int)? in
                guard let count = selection[CollectionManager.identityKey(for: card)], count > 0 else { return nil }
                return (card, count)
            }
            total = storageManager.storeAddingToCollection(picks, in: container, collection: collectionManager).stored
        } else {
            for card in candidates {
                let key = CollectionManager.identityKey(for: card)
                guard let count = selection[key], count > 0 else { continue }
                if storageManager.upgradeTarget(for: card, in: container) != nil {
                    total += storageManager.upgradeToFoil(card, in: container) ? 1 : 0
                } else {
                    total += storageManager.store(card, quantity: count, in: container, source: "picker")
                }
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
