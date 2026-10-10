//
//  StorageManager.swift
//  Inkwell Keeper
//
//  Owns the collector's physical storage: binders, troves, boxes and bins, and which
//  copies of each card live where.
//
//  Invariant: for any card, the copies stored across all containers never exceed the
//  copies owned. Copies that aren't stored anywhere are "Unsorted" — that is derived,
//  never persisted.
//

import Foundation
import SwiftData
import SwiftUI
import CoreData

@MainActor
@Observable
final class StorageManager {
    /// Containers a free user may create; Pro removes the limit.
    static let freeContainerLimit = 3

    private var modelContext: ModelContext?

    @ObservationIgnored private var remoteChangeObserver: NSObjectProtocol?
    @ObservationIgnored private var remoteChangeReloadTask: Task<Void, Never>?

    /// For each set, which printing each card number is (Normal for #1–204, Epic /
    /// Enchanted / Iconic after that). Injectable for tests; defaults to the catalog.
    @ObservationIgnored var catalogPrintings: (String) -> [Int: CardVariant] = SetChecklistLayout.catalogPrintings(for:)
    @ObservationIgnored private var printingsCache: [String: [Int: CardVariant]] = [:]

    /// All containers, in the collector's shelf order.
    private(set) var containers: [StorageContainer] = []

    /// Identity key → every stored row for that card, across all containers.
    private var itemsByIdentity: [String: [StoredCard]] = [:]

    /// Total copies stored anywhere, keyed by identity. Drives filters and tile badges.
    private(set) var storedQuantityByIdentity: [String: Int] = [:]

    // MARK: - Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        mergeDuplicateStoredCards()
        loadContainers()
        reconcileAll()
        startObservingRemoteChanges()
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
        remoteChangeReloadTask?.cancel()
    }

    func loadContainers() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<StorageContainer>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdDate)]
        )
        containers = (try? context.fetch(descriptor)) ?? []
        rebuildIndex()
    }

    private func rebuildIndex() {
        var byIdentity: [String: [StoredCard]] = [:]
        var quantities: [String: Int] = [:]
        for container in containers {
            for item in container.items ?? [] {
                byIdentity[item.identityKey, default: []].append(item)
                quantities[item.identityKey, default: 0] += item.quantity
            }
        }
        itemsByIdentity = byIdentity
        storedQuantityByIdentity = quantities
    }

    private func save() {
        guard let context = modelContext else { return }
        try? context.save()
        rebuildIndex()
    }

    /// Same debounce as `CollectionManager`: CloudKit posts bursts of remote-change
    /// notifications while one import lands, so coalesce them into a single reload.
    private func startObservingRemoteChanges() {
        guard remoteChangeObserver == nil else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleRemoteChangeReload()
            }
        }
    }

    private func scheduleRemoteChangeReload() {
        remoteChangeReloadTask?.cancel()
        remoteChangeReloadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            self.loadContainers()
        }
    }

    // MARK: - Containers

    /// Deck boxes holding a built deck don't count: building decks is never paywalled.
    func canCreateContainer(isSubscribed: Bool) -> Bool {
        isSubscribed || containers.filter { $0.linkedDeckId == nil }.count < Self.freeContainerLimit
    }

    @discardableResult
    func createContainer(
        name: String,
        kind: StorageKind,
        configure: (StorageContainer) -> Void = { _ in }
    ) -> StorageContainer? {
        guard let context = modelContext else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let container = StorageContainer(
            name: trimmed.isEmpty ? kind.displayName : trimmed,
            kind: kind,
            sortOrder: (containers.map(\.sortOrder).max() ?? -1) + 1
        )
        configure(container)
        context.insert(container)
        containers.append(container)
        save()
        Analytics.send(.storageContainerCreated(kind: kind.rawValue))
        return container
    }

    func rename(_ container: StorageContainer, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        container.name = trimmed
        save()
    }

    /// Saves edits made directly to a container's properties (settings sheet).
    func containerDidChange(_ container: StorageContainer) {
        if container.kind.usesSlots {
            // Shrinking a binder must not strand cards in pockets that no longer exist.
            relocateOutOfRangeItems(in: container)
        }
        save()
    }

    /// Deletes the container. Its cards are not removed from the collection — with no
    /// stored rows left they simply show as Unsorted again.
    func delete(_ container: StorageContainer) {
        guard let context = modelContext else { return }
        context.delete(container)
        containers.removeAll { $0.id == container.id }
        save()
    }

    func moveContainers(from source: IndexSet, to destination: Int) {
        containers.move(fromOffsets: source, toOffset: destination)
        for (index, container) in containers.enumerated() {
            container.sortOrder = index
        }
        save()
    }

    // MARK: - Queries

    func storedQuantity(for card: LorcanaCard) -> Int {
        storedQuantityByIdentity[CollectionManager.identityKey(for: card)] ?? 0
    }

    func unsortedQuantity(for card: LorcanaCard) -> Int {
        max(0, ownedQuantity(for: card) - storedQuantity(for: card))
    }

    /// Every container holding this card, in shelf order, with binder pockets resolved.
    func locations(for card: LorcanaCard) -> [StorageAllocation] {
        let items = itemsByIdentity[CollectionManager.identityKey(for: card)] ?? []
        guard !items.isEmpty else { return [] }

        return containers.compactMap { container in
            let held = items.filter { $0.container?.id == container.id }
            guard !held.isEmpty else { return nil }
            let layout = container.binderLayout
            let pockets = held.compactMap(\.slotIndex).sorted().map { slot in
                let position = layout.position(of: slot)
                return StorageAllocation.BinderPocket(page: position.page + 1, pocket: position.pocket + 1)
            }
            return StorageAllocation(
                containerId: container.id,
                containerName: container.name,
                kind: container.kind,
                quantity: held.reduce(0) { $0 + $1.quantity },
                pockets: pockets
            )
        }
    }

    /// Identity keys stored in one container — used by the Collection location filter.
    func identityKeys(in container: StorageContainer) -> Set<String> {
        Set((container.items ?? []).map(\.identityKey))
    }

    /// Market value of a container, from the prices snapshotted when cards were stored.
    func value(of container: StorageContainer) -> Double {
        (container.items ?? []).reduce(0) { $0 + ($1.price ?? 0) * Double($1.quantity) }
    }

    /// Owned copies of every card, keyed by identity, from a single fetch. Nil if the
    /// fetch fails, so callers can tell "unknown" from "owns nothing".
    func ownedQuantitiesByIdentity() -> [String: Int]? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<CollectedCard>(predicate: #Predicate { $0.isWishlisted == false })
        guard let rows = try? context.fetch(descriptor) else { return nil }
        var owned: [String: Int] = [:]
        for row in rows {
            owned[Self.identityKey(for: row), default: 0] += row.quantity
        }
        return owned
    }

    /// Unsorted copies of every card that has any, keyed by identity. One fetch, so the
    /// Collection "Unsorted" filter doesn't query per card.
    func unsortedQuantitiesByIdentity() -> [String: Int] {
        var unsorted: [String: Int] = [:]
        for (key, owned) in ownedQuantitiesByIdentity() ?? [:] {
            let remaining = owned - (storedQuantityByIdentity[key] ?? 0)
            if remaining > 0 { unsorted[key] = remaining }
        }
        return unsorted
    }

    /// Copies of this card the collector owns (every non-wishlist row for its identity).
    func ownedQuantity(for card: LorcanaCard) -> Int {
        guard let context = modelContext else { return 0 }
        let variant = card.variant.rawValue
        let descriptor: FetchDescriptor<CollectedCard>
        if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
            descriptor = FetchDescriptor(predicate: #Predicate<CollectedCard> {
                $0.uniqueId == uniqueId && $0.variant == variant && $0.isWishlisted == false
            })
        } else {
            let name = card.name
            let setName = card.setName
            descriptor = FetchDescriptor(predicate: #Predicate<CollectedCard> {
                $0.name == name && $0.setName == setName && $0.variant == variant && $0.isWishlisted == false
            })
        }
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.reduce(0) { $0 + $1.quantity }
    }

    // MARK: - Storing cards

    // MARK: - Room

    /// Copies that still fit: free pockets in a binder, remaining capacity in a box.
    /// Nil means the container has no limit (a box without a capacity set).
    func freeSpace(in container: StorageContainer) -> Int? {
        if container.kind.usesSlots {
            return max(0, container.binderLayout.totalSlots - occupiedSlots(in: container).count)
        }
        guard let capacity = container.capacity else { return nil }
        return max(0, capacity - container.cardCount)
    }

    /// A full container accepts nothing more until cards come out (or it's made bigger).
    func isFull(_ container: StorageContainer) -> Bool {
        freeSpace(in: container) == 0
    }

    /// Puts up to `quantity` copies into the container, capped by how many are still
    /// unsorted and by the room left in the container. Returns how many were stored.
    @discardableResult
    func store(
        _ card: LorcanaCard,
        quantity: Int = 1,
        in container: StorageContainer,
        source: String = "detail"
    ) -> Int {
        let stored = insert(card, quantity: min(quantity, unsortedQuantity(for: card)), into: container)
        guard stored > 0 else { return 0 }
        save()
        Analytics.send(.storageCardsStored(count: stored, kind: container.kind.rawValue, source: source))
        return stored
    }

    /// Inserts without the owned-quantity check or a save; callers must validate that.
    /// Room is enforced here, so no path can overfill a binder or box.
    private func insert(_ card: LorcanaCard, quantity requested: Int, into container: StorageContainer) -> Int {
        let quantity = min(requested, freeSpace(in: container) ?? requested)
        guard let context = modelContext, quantity > 0, accepts(card, in: container) else { return 0 }

        if container.kind.usesSlots {
            var occupied = occupiedSlots(in: container)
            var stored = 0
            for _ in 0..<quantity {
                guard let slot = preferredSlot(for: card, in: container, occupied: occupied) else { break }
                let item = StoredCard(from: card, quantity: 1, slotIndex: slot)
                context.insert(item)
                item.container = container
                occupied.insert(slot)
                stored += 1
            }
            return stored
        }

        let key = CollectionManager.identityKey(for: card)
        if let existing = (container.items ?? []).first(where: {
            $0.identityKey == key && $0.originContainerId == nil && $0.originSlot == nil
        }) {
            existing.quantity += quantity
            existing.price = card.price ?? existing.price
        } else {
            let item = StoredCard(from: card, quantity: quantity)
            context.insert(item)
            item.container = container
        }
        return quantity
    }

    /// Takes copies of a card out of a container (they become Unsorted).
    func unstore(_ card: LorcanaCard, quantity: Int = 1, from container: StorageContainer) {
        let key = CollectionManager.identityKey(for: card)
        let held = (container.items ?? [])
            .filter { $0.identityKey == key }
            .sorted { ($0.slotIndex ?? 0) > ($1.slotIndex ?? 0) }
        removeCopies(quantity, from: held)
        save()
    }

    /// Moves copies from one container to another without passing through Unsorted.
    func move(_ card: LorcanaCard, quantity: Int = 1, from source: StorageContainer, to destination: StorageContainer) {
        guard source.id != destination.id else { return }
        let key = CollectionManager.identityKey(for: card)
        let held = (source.items ?? []).filter { $0.identityKey == key }
        let available = held.reduce(0) { $0 + $1.quantity }
        let toMove = min(quantity, available)
        guard toMove > 0 else { return }

        let moved = insert(card, quantity: toMove, into: destination)
        removeCopies(moved, from: held.sorted { ($0.slotIndex ?? 0) > ($1.slotIndex ?? 0) })
        save()
    }

    /// What a bulk move did.
    struct BulkMoveResult: Equatable {
        /// Copies that reached the destination.
        var moved = 0
        /// Copies that didn't fit (or don't belong there) and stayed where they were.
        var leftBehind = 0
    }

    /// Moves every copy in `items` to `destination`, or back to Unsorted when it's
    /// nil, saving once. Each card goes where the destination would put it (a free
    /// pocket, or its numbered pocket in a set binder); anything that doesn't fit
    /// stays exactly where it was.
    @discardableResult
    func moveItems(_ items: [StoredCard], to destination: StorageContainer?) -> BulkMoveResult {
        var result = BulkMoveResult()
        // Binder pockets first-to-last, so they arrive in the same order.
        let ordered = items.sorted { ($0.slotIndex ?? 0) < ($1.slotIndex ?? 0) }
        for item in ordered where item.container?.id != destination?.id {
            let copies = item.quantity
            let moved = destination.map { insert(item.toLorcanaCard, quantity: copies, into: $0) } ?? copies
            removeCopies(moved, from: [item])
            result.moved += moved
            result.leftBehind += copies - moved
        }
        guard result.moved > 0 else { return result }
        save()
        if let destination {
            Analytics.send(.storageCardsStored(count: result.moved, kind: destination.kind.rawValue, source: "bulkMove"))
        }
        return result
    }

    /// Removes one row entirely (e.g. "Remove from pocket").
    func remove(_ item: StoredCard) {
        guard let context = modelContext else { return }
        item.container?.items?.removeAll { $0.id == item.id }
        context.delete(item)
        save()
    }

    private func removeCopies(_ count: Int, from rows: [StoredCard]) {
        guard let context = modelContext else { return }
        var remaining = count
        for row in rows where remaining > 0 {
            if row.quantity > remaining {
                row.quantity -= remaining
                remaining = 0
            } else {
                remaining -= row.quantity
                row.container?.items?.removeAll { $0.id == row.id }
                context.delete(row)
            }
        }
    }

    // MARK: - Binder pockets

    func occupiedSlots(in binder: StorageContainer) -> Set<Int> {
        Set((binder.items ?? []).compactMap(\.slotIndex))
    }

    func item(atSlot slot: Int, in binder: StorageContainer) -> StoredCard? {
        (binder.items ?? []).first { $0.slotIndex == slot }
    }

    /// Set binders reserve pocket (number − 1) for each card of their set; everything
    /// else takes the first free pocket.
    private func preferredSlot(for card: LorcanaCard, in binder: StorageContainer, occupied: Set<Int>) -> Int? {
        if binder.linkedSetName != nil {
            // Checklist binders: a card goes in its own numbered pocket or not at all.
            guard let slot = setPocket(for: card, in: binder), !occupied.contains(slot) else { return nil }
            return slot
        }
        return binder.binderLayout.firstEmptySlot(occupied: occupied)
    }

    // MARK: - Set checklist binders

    /// The numbered pocket a card belongs in, for a set checklist binder. Nil when the
    /// binder isn't a set binder, the card is from another set, or has no pocket.
    func setPocket(for card: LorcanaCard, in binder: StorageContainer) -> Int? {
        guard let setName = binder.linkedSetName,
              card.setName == setName,
              let number = card.cardNumber,
              // The pocket must be for this printing: collections saved by older versions
              // can hold an Enchanted copy under its base card's number, which would
              // otherwise take the normal card's pocket.
              let slot = checklistLayout(for: binder)?.slot(forNumber: number, variant: card.variant),
              binder.binderLayout.contains(slot: slot) else { return nil }
        return slot
    }

    /// Pocket assignments for a set binder (nil for other containers).
    func checklistLayout(for binder: StorageContainer) -> SetChecklistLayout? {
        guard let setName = binder.linkedSetName else { return nil }
        return SetChecklistLayout(printings: printings(for: setName), hasFoilPockets: binder.hasFoilPockets)
    }

    /// The "missing card" ghost for every pocket of a set binder, keyed by slot. Foil
    /// pockets in a master set show the foil printing.
    func checklistGhosts(for binder: StorageContainer) -> [Int: LorcanaCard] {
        guard let setName = binder.linkedSetName, let layout = checklistLayout(for: binder) else { return [:] }
        var cardsByNumber: [Int: LorcanaCard] = [:]
        for card in SetsDataManager.shared.getCardsForSet(setName) {
            if let number = card.cardNumber, cardsByNumber[number] == nil {
                cardsByNumber[number] = card
            }
        }
        var ghosts: [Int: LorcanaCard] = [:]
        for slot in 0..<min(layout.pocketCount, binder.binderLayout.totalSlots) {
            guard let pocket = layout.pocket(atSlot: slot), let card = cardsByNumber[pocket.number] else { continue }
            ghosts[slot] = pocket.isFoilPocket ? card.withVariant(.foil) : card
        }
        return ghosts
    }

    // MARK: - Foil upgrades

    /// In a one-per-card checklist, the normal copy sitting in the pocket this foil
    /// could replace. Nil when there's nothing to upgrade (or it's a master set, where
    /// the foil has its own pocket).
    func upgradeTarget(for card: LorcanaCard, in binder: StorageContainer) -> StoredCard? {
        guard card.variant == .foil,
              !binder.hasFoilPockets,
              let slot = setPocket(for: card, in: binder),
              let occupant = item(atSlot: slot, in: binder),
              occupant.cardVariant == .normal,
              unsortedQuantity(for: card) > 0 else { return nil }
        return occupant
    }

    /// Swaps a foil into the pocket its normal copy holds; the normal goes to Unsorted.
    /// Only ever done when the collector asks — auto-fill and scans never swap.
    @discardableResult
    func upgradeToFoil(_ card: LorcanaCard, in binder: StorageContainer) -> Bool {
        guard let context = modelContext,
              let occupant = upgradeTarget(for: card, in: binder),
              let slot = occupant.slotIndex else { return false }
        binder.items?.removeAll { $0.id == occupant.id }
        context.delete(occupant)
        let foil = StoredCard(from: card, quantity: 1, slotIndex: slot)
        context.insert(foil)
        foil.container = binder
        save()
        Analytics.send(.storageCardsStored(count: 1, kind: binder.kind.rawValue, source: "foilUpgrade"))
        return true
    }

    private func printings(for setName: String) -> [Int: CardVariant] {
        if let cached = printingsCache[setName], !cached.isEmpty { return cached }
        let printings = catalogPrintings(setName)
        printingsCache[setName] = printings
        return printings
    }

    /// Whether a card is allowed in this container at all. Set checklist binders only
    /// take cards from their set; everything else takes anything.
    func accepts(_ card: LorcanaCard, in container: StorageContainer) -> Bool {
        container.linkedSetName == nil || setPocket(for: card, in: container) != nil
    }

    /// Whether at least one copy of this card could go in right now: allowed, room left,
    /// and — for set binders — its numbered pocket still empty.
    func canAccept(_ card: LorcanaCard, in container: StorageContainer) -> Bool {
        guard accepts(card, in: container), !isFull(container) else { return false }
        if container.linkedSetName != nil, let slot = setPocket(for: card, in: container) {
            return item(atSlot: slot, in: container) == nil
        }
        return true
    }

    /// Why a card can't go in a container, for disabled rows. Nil when it can.
    func refusal(for card: LorcanaCard, in container: StorageContainer) -> String? {
        if !accepts(card, in: container) {
            return String(localized: "Only \(container.linkedSetName ?? "") cards")
        }
        if isFull(container) { return String(localized: "Full") }
        if !canAccept(card, in: container) {
            if upgradeTarget(for: card, in: container) != nil {
                return String(localized: "Pocket #\(card.cardNumber ?? 0) has the normal copy")
            }
            return String(localized: "Pocket #\(card.cardNumber ?? 0) is taken")
        }
        return nil
    }

    /// Stores one copy in a specific pocket. Fails if the pocket is taken or no copy is unsorted.
    @discardableResult
    func place(_ card: LorcanaCard, atSlot slot: Int, in binder: StorageContainer) -> Bool {
        guard let context = modelContext,
              binder.binderLayout.contains(slot: slot),
              item(atSlot: slot, in: binder) == nil,
              binder.linkedSetName == nil || setPocket(for: card, in: binder) == slot,
              unsortedQuantity(for: card) > 0 else { return false }
        let item = StoredCard(from: card, quantity: 1, slotIndex: slot)
        context.insert(item)
        item.container = binder
        save()
        Analytics.send(.storageCardsStored(count: 1, kind: binder.kind.rawValue, source: "pocket"))
        return true
    }

    /// Moves a pocket's card to another pocket, swapping if that pocket is occupied.
    func moveItem(_ item: StoredCard, toSlot slot: Int) {
        guard let binder = item.container, binder.binderLayout.contains(slot: slot),
              item.slotIndex != slot else { return }
        if let occupant = self.item(atSlot: slot, in: binder) {
            occupant.slotIndex = item.slotIndex
        }
        item.slotIndex = slot
        save()
    }

    /// Closes every gap so cards sit in consecutive pockets, preserving order.
    func compact(_ binder: StorageContainer) {
        let items = binder.items ?? []
        let map = BinderLayout.compactionMap(occupied: items.compactMap(\.slotIndex))
        for item in items {
            if let slot = item.slotIndex, let newSlot = map[slot] {
                item.slotIndex = newSlot
            }
        }
        save()
    }

    /// Fills free pockets with unsorted copies of `cards`, in the chosen order.
    /// Returns the cards that were placed, in placement order, for the drop-in animation.
    @discardableResult
    func autoFill(
        _ binder: StorageContainer,
        with cards: [LorcanaCard],
        order: BinderSortOrder,
        setOrder: [String: Int]
    ) -> [StoredCard] {
        guard let context = modelContext, binder.kind.usesSlots else { return [] }
        var occupied = occupiedSlots(in: binder)
        var placed: [StoredCard] = []
        // The stored index only refreshes on save, so count this run's placements here.
        var placedByIdentity: [String: Int] = [:]

        for card in order.sorted(cards, setOrder: setOrder) {
            let key = CollectionManager.identityKey(for: card)
            let copies = unsortedQuantity(for: card) - placedByIdentity[key, default: 0]
            for _ in 0..<max(0, copies) {
                guard let slot = preferredSlot(for: card, in: binder, occupied: occupied) else { break }
                let item = StoredCard(from: card, quantity: 1, slotIndex: slot)
                context.insert(item)
                item.container = binder
                occupied.insert(slot)
                placed.append(item)
                placedByIdentity[key, default: 0] += 1
            }
        }

        guard !placed.isEmpty else { return [] }
        save()
        Analytics.send(.storageBinderAutoFilled(count: placed.count, order: order.rawValue))
        return placed
    }

    /// Adds sheets to a binder (e.g. when auto-fill runs out of room).
    func addSheets(_ count: Int, to binder: StorageContainer) {
        binder.sheetCount += max(0, count)
        save()
    }

    /// After a binder shrinks, moves cards from pockets that no longer exist into free
    /// pockets, or back to Unsorted if there's no room.
    private func relocateOutOfRangeItems(in binder: StorageContainer) {
        guard let context = modelContext else { return }
        let layout = binder.binderLayout
        let items = binder.items ?? []
        var occupied = Set(items.compactMap(\.slotIndex).filter { layout.contains(slot: $0) })
        for item in items {
            guard let slot = item.slotIndex, !layout.contains(slot: slot) else { continue }
            // A checklist card has exactly one valid pocket, so it goes back to Unsorted.
            if binder.linkedSetName == nil, let free = layout.firstEmptySlot(occupied: occupied) {
                item.slotIndex = free
                occupied.insert(free)
            } else {
                binder.items?.removeAll { $0.id == item.id }
                context.delete(item)
            }
        }
    }

    // MARK: - Reconciliation

    /// Called when the owned count of a card changes. If more copies are stored than
    /// owned, trims the most recently stored copies. Returns what was trimmed so the UI
    /// can say where the copies were taken from.
    @discardableResult
    func reconcile(_ card: LorcanaCard, ownedQuantity: Int) -> [StorageAllocation] {
        let key = CollectionManager.identityKey(for: card)
        let before = locations(for: card)
        let excess = (storedQuantityByIdentity[key] ?? 0) - max(0, ownedQuantity)
        guard excess > 0 else { return [] }

        let rows = (itemsByIdentity[key] ?? []).sorted { $0.dateStored > $1.dateStored }
        removeCopies(excess, from: rows)
        save()

        let after = Dictionary(uniqueKeysWithValues: locations(for: card).map { ($0.containerId, $0.quantity) })
        return before.compactMap { allocation in
            let removed = allocation.quantity - (after[allocation.containerId] ?? 0)
            guard removed > 0 else { return nil }
            return StorageAllocation(
                containerId: allocation.containerId,
                containerName: allocation.containerName,
                kind: allocation.kind,
                quantity: removed,
                pockets: []
            )
        }
    }

    /// Trims over-stored cards across the whole collection (launch, after imports).
    ///
    /// Cards with **no** collection row are left alone: after a fresh install CloudKit can
    /// deliver storage rows before the collection rows they belong to, and trimming then
    /// would wipe the collector's storage. Real removals go through `reconcile(_:ownedQuantity:)`.
    func reconcileAll() {
        guard !itemsByIdentity.isEmpty, let owned = ownedQuantitiesByIdentity() else { return }

        var changed = false
        for (key, items) in itemsByIdentity {
            guard let ownedCount = owned[key] else { continue }
            let stored = items.reduce(0) { $0 + $1.quantity }
            if stored > ownedCount {
                removeCopies(stored - ownedCount, from: items.sorted { $0.dateStored > $1.dateStored })
                changed = true
            }
        }
        if changed { save() }
    }

    private static func identityKey(for row: CollectedCard) -> String {
        let variant = row.variant ?? CardVariant.normal.rawValue
        if let uniqueId = row.uniqueId, !uniqueId.isEmpty {
            return "\(uniqueId)|\(variant)"
        }
        return "\(row.name)|\(row.setName)|\(variant)"
    }

    // MARK: - Sync duplicates

    /// Two devices storing the same card while offline can leave duplicate rows once
    /// CloudKit merges them. In boxes, duplicates of one card fold into the larger count
    /// (matching `DeckManager.mergeDuplicateDeckCards`). In binders, two rows claiming one
    /// pocket keep the earliest; the later one moves to a free pocket.
    func mergeDuplicateStoredCards() {
        guard let context = modelContext,
              let allContainers = try? context.fetch(FetchDescriptor<StorageContainer>()) else { return }

        var didChange = false
        for container in allContainers {
            let items = container.items ?? []
            guard items.count > 1 else { continue }

            if container.kind.usesSlots {
                let layout = container.binderLayout
                var occupied = Set<Int>()
                for item in items.sorted(by: { $0.dateStored < $1.dateStored }) {
                    guard let slot = item.slotIndex else { continue }
                    if occupied.contains(slot) {
                        if let free = layout.firstEmptySlot(occupied: occupied.union(items.compactMap(\.slotIndex))) {
                            item.slotIndex = free
                            occupied.insert(free)
                        } else {
                            container.items?.removeAll { $0.id == item.id }
                            context.delete(item)
                        }
                        didChange = true
                    } else {
                        occupied.insert(slot)
                    }
                }
            } else {
                let groups = Dictionary(grouping: items) { item in
                    "\(item.identityKey)|\(item.originContainerId?.uuidString ?? "")|\(item.originSlot.map(String.init) ?? "")"
                }
                for (_, rows) in groups where rows.count > 1 {
                    let sorted = rows.sorted { $0.dateStored < $1.dateStored }
                    let survivor = sorted[0]
                    for duplicate in sorted.dropFirst() {
                        survivor.quantity = max(survivor.quantity, duplicate.quantity)
                        container.items?.removeAll { $0.id == duplicate.id }
                        context.delete(duplicate)
                        didChange = true
                    }
                }
            }
        }

        if didChange {
            try? context.save()
        }
    }

    // MARK: - Reset

    /// Used by Settings → Delete All Data.
    func deleteAll() {
        guard let context = modelContext else { return }
        for container in (try? context.fetch(FetchDescriptor<StorageContainer>())) ?? [] {
            context.delete(container)
        }
        containers = []
        save()
    }
}

// MARK: - Built decks

/// A deck is "built" when a deck box is linked to it. Its cards physically move into
/// that box, so storage stays the single source of truth for where every copy is.
extension StorageManager {
    func deckBox(for deckId: UUID) -> StorageContainer? {
        containers.first { $0.linkedDeckId == deckId }
    }

    func isBuilt(_ deck: Deck) -> Bool {
        deckBox(for: deck.id) != nil
    }

    /// Deck boxes not holding a deck, which a new build can use.
    var availableDeckBoxes: [StorageContainer] {
        containers.filter { $0.kind == .deckBox && $0.linkedDeckId == nil }
    }

    /// Name of the deck a box holds, for labels.
    func deckName(for deckId: UUID) -> String? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<Deck>(predicate: #Predicate { $0.id == deckId })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.name
    }

    /// Makes a new deck box for a deck, bypassing the free limit.
    @discardableResult
    func createDeckBox(for deck: Deck) -> StorageContainer? {
        let color = deck.deckInkColors.first.flatMap { StorageCoverColor(rawValue: $0.rawValue.lowercased()) } ?? .midnight
        return createContainer(name: deck.name, kind: .deckBox) { box in
            box.coverColor = color
            box.linkedDeckId = deck.id
            box.capacity = max(box.capacity ?? 0, deck.totalCards)
        }
    }

    func link(_ box: StorageContainer, to deck: Deck) {
        box.linkedDeckId = deck.id
        if let capacity = box.capacity, capacity < deck.totalCards {
            box.capacity = deck.totalCards
        }
        save()
    }

    /// Stops a box holding a deck without moving any cards (used when a deck is deleted).
    func unlinkDeck(_ deckId: UUID) {
        for box in containers where box.linkedDeckId == deckId {
            box.linkedDeckId = nil
        }
        save()
    }

    /// How much of the deck is in its box — cheap enough to show on every render
    /// (unlike `pullPlan`, it doesn't look anywhere but the box).
    func deckProgress(_ deck: Deck, in box: StorageContainer) -> (inBox: Int, total: Int) {
        var boxRemaining: [String: Int] = [:]
        for item in box.items ?? [] {
            boxRemaining[item.identityKey, default: 0] += item.quantity
        }
        var inBox = 0
        var total = 0
        for deckCard in deck.cards ?? [] {
            var need = deckCard.quantity
            total += need
            for candidate in Self.interchangeableVariants(of: deckCard.toLorcanaCard) where need > 0 {
                let key = CollectionManager.identityKey(for: candidate)
                let have = min(need, boxRemaining[key] ?? 0)
                boxRemaining[key, default: 0] -= have
                need -= have
                inBox += have
            }
        }
        return (inBox, total)
    }

    // MARK: Planning

    /// Where to find every copy the deck still needs. Prefers Unsorted, then binders and
    /// boxes in shelf order, and never takes cards out of another built deck's box.
    /// A normal card in the deck can be filled by a foil of the same card and vice versa.
    func pullPlan(for deck: Deck, into box: StorageContainer) -> DeckPullPlan {
        var plan = DeckPullPlan()
        let sources = containers.filter { $0.linkedDeckId == nil && $0.id != box.id }
        let unsorted = unsortedQuantitiesByIdentity()

        var boxRemaining: [String: Int] = [:]
        for item in box.items ?? [] {
            boxRemaining[item.identityKey, default: 0] += item.quantity
        }
        var unsortedRemaining = unsorted
        var takenItems: Set<UUID> = []
        var takenFromBoxRows: [UUID: Int] = [:]

        for deckCard in (deck.cards ?? []).sorted(by: { ($0.cost, $0.name) < ($1.cost, $1.name) }) {
            let wanted = deckCard.toLorcanaCard
            var need = deckCard.quantity
            plan.total += need
            let candidates = Self.interchangeableVariants(of: wanted)

            // Already in the box.
            for candidate in candidates where need > 0 {
                let key = CollectionManager.identityKey(for: candidate)
                let have = min(need, boxRemaining[key] ?? 0)
                boxRemaining[key, default: 0] -= have
                need -= have
                plan.inBox += have
            }

            // Unsorted copies.
            for candidate in candidates where need > 0 {
                let key = CollectionManager.identityKey(for: candidate)
                let take = min(need, unsortedRemaining[key] ?? 0)
                guard take > 0 else { continue }
                unsortedRemaining[key, default: 0] -= take
                need -= take
                plan.pulls.append(.init(
                    card: candidate, sourceId: nil, sourceName: String(localized: "Unsorted"),
                    sourceKind: nil, quantity: take, slots: [], pockets: []
                ))
            }

            // Binders and boxes.
            for container in sources where need > 0 {
                for candidate in candidates where need > 0 {
                    let key = CollectionManager.identityKey(for: candidate)
                    let rows = (container.items ?? []).filter { $0.identityKey == key }
                    if container.kind.usesSlots {
                        let free = rows.filter { !takenItems.contains($0.id) }
                            .sorted { ($0.slotIndex ?? 0) < ($1.slotIndex ?? 0) }
                            .prefix(need)
                        guard !free.isEmpty else { continue }
                        free.forEach { takenItems.insert($0.id) }
                        let slots = free.compactMap(\.slotIndex)
                        let layout = container.binderLayout
                        need -= free.count
                        plan.pulls.append(.init(
                            card: candidate, sourceId: container.id, sourceName: container.name,
                            sourceKind: container.kind, quantity: free.count, slots: slots,
                            pockets: slots.map {
                                let position = layout.position(of: $0)
                                return .init(page: position.page + 1, pocket: position.pocket + 1)
                            }
                        ))
                    } else {
                        var take = 0
                        for row in rows where need > take {
                            let left = row.quantity - (takenFromBoxRows[row.id] ?? 0)
                            let used = min(left, need - take)
                            takenFromBoxRows[row.id, default: 0] += used
                            take += used
                        }
                        guard take > 0 else { continue }
                        need -= take
                        plan.pulls.append(.init(
                            card: candidate, sourceId: container.id, sourceName: container.name,
                            sourceKind: container.kind, quantity: take, slots: [], pockets: []
                        ))
                    }
                }
            }

            if need > 0 {
                plan.missing.append(.init(card: wanted, quantity: need))
            }
        }
        return plan
    }

    /// Normal and foil copies of a card are interchangeable in a deck; other printings aren't.
    static func interchangeableVariants(of card: LorcanaCard) -> [LorcanaCard] {
        switch card.variant {
        case .normal: [card, card.withVariant(.foil)]
        case .foil: [card, card.withVariant(.normal)]
        default: [card]
        }
    }

    // MARK: Pulling

    /// Moves one planned pull into the deck box, remembering where each copy came from.
    /// Returns how many copies moved (fewer if the box filled up or things changed).
    @discardableResult
    func pull(_ pull: DeckPullPlan.Pull, into box: StorageContainer) -> Int {
        guard let context = modelContext else { return 0 }
        var room = freeSpace(in: box) ?? .max
        var moved = 0

        func addToBox(_ copies: Int, origin: UUID?, slot: Int?) {
            let key = CollectionManager.identityKey(for: pull.card)
            if let existing = (box.items ?? []).first(where: {
                $0.identityKey == key && $0.originContainerId == origin && $0.originSlot == slot
            }) {
                existing.quantity += copies
            } else {
                let item = StoredCard(from: pull.card, quantity: copies)
                item.originContainerId = origin
                item.originSlot = slot
                context.insert(item)
                item.container = box
            }
        }

        if let sourceId = pull.sourceId {
            guard let source = containers.first(where: { $0.id == sourceId }) else { return 0 }
            let key = CollectionManager.identityKey(for: pull.card)
            let rows = (source.items ?? []).filter { $0.identityKey == key }
            if source.kind.usesSlots {
                for row in rows where pull.slots.contains(row.slotIndex ?? -1) && room > 0 && moved < pull.quantity {
                    addToBox(1, origin: source.id, slot: row.slotIndex)
                    source.items?.removeAll { $0.id == row.id }
                    context.delete(row)
                    moved += 1
                    room -= 1
                }
            } else {
                let wanted = min(pull.quantity, room)
                let available = rows.reduce(0) { $0 + $1.quantity }
                moved = min(wanted, available)
                guard moved > 0 else { return 0 }
                removeCopies(moved, from: rows)
                addToBox(moved, origin: source.id, slot: nil)
            }
        } else {
            moved = min(pull.quantity, room, unsortedQuantity(for: pull.card))
            guard moved > 0 else { return 0 }
            addToBox(moved, origin: nil, slot: nil)
        }

        save()
        return moved
    }

    /// Pulls everything in the plan. Returns copies moved.
    @discardableResult
    func pullAll(_ plan: DeckPullPlan, into box: StorageContainer) -> Int {
        plan.pulls.reduce(0) { $0 + pull($1, into: box) }
    }

    // MARK: Taking apart

    /// Empties a deck box and turns its deck back into an idea. With `returnToOrigins`,
    /// each copy goes back to the pocket or box it was pulled from when there's room;
    /// everything else becomes Unsorted.
    @discardableResult
    func takeApart(_ box: StorageContainer, returnToOrigins: Bool) -> (returned: Int, unsorted: Int) {
        guard let context = modelContext else { return (0, 0) }
        var returned = 0
        var unsorted = 0

        for item in box.items ?? [] {
            var copies = item.quantity
            if returnToOrigins,
               let originId = item.originContainerId,
               let origin = containers.first(where: { $0.id == originId }),
               origin.id != box.id {
                let card = item.toLorcanaCard
                if origin.kind.usesSlots {
                    var occupied = occupiedSlots(in: origin)
                    while copies > 0 {
                        let preferred = item.originSlot.flatMap { occupied.contains($0) || !origin.binderLayout.contains(slot: $0) ? nil : $0 }
                        // Checklist binders only take a card back into its own pocket.
                        let fallback = origin.linkedSetName == nil ? origin.binderLayout.firstEmptySlot(occupied: occupied) : nil
                        guard let slot = preferred ?? fallback else { break }
                        let restored = StoredCard(from: card, quantity: 1, slotIndex: slot)
                        context.insert(restored)
                        restored.container = origin
                        occupied.insert(slot)
                        copies -= 1
                        returned += 1
                    }
                } else {
                    let placed = insert(card, quantity: copies, into: origin)
                    copies -= placed
                    returned += placed
                }
            }
            unsorted += copies
            box.items?.removeAll { $0.id == item.id }
            context.delete(item)
        }

        box.linkedDeckId = nil
        save()
        return (returned, unsorted)
    }
}

// MARK: - Backup

extension StorageManager {
    /// What a restore put back.
    struct RestoreSummary: Equatable {
        var containers = 0
        var cards = 0
    }

    /// Every binder and box with its contents, for the JSON backup.
    func backupContainers() -> [InkwellBackup.Container] {
        containers.map(InkwellBackup.Container.init)
    }

    /// Recreates binders and boxes from a backup, after its cards have been imported.
    ///
    /// - Containers already here (same id — e.g. restoring onto the device that made
    ///   the backup) are left alone rather than duplicated.
    /// - Cards go back in their exact pockets, but never more copies than are owned;
    ///   anything the collection doesn't have stays out.
    /// - A deck box only re-links to its deck if that deck still exists.
    @discardableResult
    func restore(_ backup: [InkwellBackup.Container], deckExists: (UUID) -> Bool) -> RestoreSummary {
        guard let context = modelContext else { return RestoreSummary() }
        let existingIds = Set(containers.map(\.id))
        var room = ownedQuantitiesByIdentity() ?? [:]
        for (key, stored) in storedQuantityByIdentity {
            room[key, default: 0] -= stored
        }

        var summary = RestoreSummary()
        let toRestore = backup.filter { !existingIds.contains($0.id) }.sorted { $0.sortOrder < $1.sortOrder }
        for (offset, saved) in toRestore.enumerated() {
            let container = StorageContainer(name: saved.name, kind: StorageKind(rawValue: saved.kind) ?? .other)
            container.id = saved.id
            container.coverStyle = saved.coverStyle
            container.colorName = saved.colorName
            container.sortOrder = containers.count + offset
            container.notes = saved.notes
            container.pocketsPerPage = saved.pocketsPerPage
            container.sheetCount = saved.sheetCount
            container.isDoubleSided = saved.isDoubleSided
            container.capacity = saved.capacity
            container.linkedSetName = saved.linkedSetName
            container.hasFoilPockets = saved.hasFoilPockets
            container.linkedDeckId = saved.linkedDeckId.flatMap { deckExists($0) ? $0 : nil }
            context.insert(container)
            summary.containers += 1

            let totalSlots = container.binderLayout.totalSlots
            var usedSlots = Set<Int>()
            for item in saved.items {
                let card = item.card
                let key = CollectionManager.identityKey(for: card)
                let copies = min(item.quantity, room[key, default: 0])
                guard copies > 0 else { continue }
                if container.kind.usesSlots {
                    // A pocket that no longer exists or is already taken can't be refilled.
                    guard let slot = item.slotIndex, slot < totalSlots, !usedSlots.contains(slot) else { continue }
                    usedSlots.insert(slot)
                }
                let row = StoredCard(from: card, quantity: copies, slotIndex: container.kind.usesSlots ? item.slotIndex : nil)
                row.originContainerId = item.originContainerId
                row.originSlot = item.originSlot
                row.container = container
                context.insert(row)
                room[key, default: 0] -= copies
                summary.cards += copies
            }
        }

        guard summary.containers > 0 else { return summary }
        try? context.save()
        loadContainers()
        return summary
    }
}
