//
//  StorageManagerTests.swift
//  Inkwell KeeperTests
//
//  The core promise of storage tracking: a copy lives in at most one place, stored
//  copies never exceed owned copies, and nothing here ever removes a card from the
//  collection itself.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct StorageManagerTests {
    private struct Fixture {
        let context: ModelContext
        let manager: StorageManager
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: CollectedCard.self, StorageContainer.self, StoredCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let manager = StorageManager()
        manager.setModelContext(context)
        return Fixture(context: context, manager: manager)
    }

    /// Inserts an owned card and returns it as the app's value type.
    @discardableResult
    private func own(
        _ quantity: Int,
        of name: String = "Elsa",
        number: Int = 1,
        variant: CardVariant = .normal,
        setName: String = "The First Chapter",
        in context: ModelContext
    ) throws -> LorcanaCard {
        let row = CollectedCard(
            cardId: "\(name)-\(variant.rawValue)",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: setName,
            imageUrl: "",
            price: 2.50,
            quantity: quantity,
            variant: variant,
            uniqueId: "TFC-\(number)",
            cardNumber: number
        )
        context.insert(row)
        try context.save()
        return row.toLorcanaCard
    }

    private func binder(_ manager: StorageManager, pockets: Int = 9, sheets: Int = 2) throws -> StorageContainer {
        try #require(manager.createContainer(name: "Binder A", kind: .binder) {
            $0.pocketsPerPage = pockets
            $0.sheetCount = sheets
        })
    }

    private func box(_ manager: StorageManager, name: String = "Trove") throws -> StorageContainer {
        try #require(manager.createContainer(name: name, kind: .trove))
    }

    // MARK: - Storing

    @Test func storingIsCappedAtOwnedCopies() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)

        #expect(fixture.manager.store(elsa, quantity: 5, in: trove) == 3)
        #expect(fixture.manager.storedQuantity(for: elsa) == 3)
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 0)
        #expect(fixture.manager.store(elsa, in: trove) == 0)
    }

    @Test func unsortedIsOwnedMinusStoredAcrossContainers() throws {
        let fixture = try makeFixture()
        let elsa = try own(4, in: fixture.context)
        let trove = try box(fixture.manager)
        let deckBox = try box(fixture.manager, name: "Deck Box")

        fixture.manager.store(elsa, quantity: 1, in: trove)
        fixture.manager.store(elsa, quantity: 2, in: deckBox)

        #expect(fixture.manager.unsortedQuantity(for: elsa) == 1)
        #expect(fixture.manager.locations(for: elsa).map(\.quantity) == [1, 2])
    }

    @Test func boxesKeepOneRowPerCard() throws {
        let fixture = try makeFixture()
        let elsa = try own(4, in: fixture.context)
        let trove = try box(fixture.manager)

        fixture.manager.store(elsa, quantity: 1, in: trove)
        fixture.manager.store(elsa, quantity: 2, in: trove)

        #expect(trove.items?.count == 1)
        #expect(trove.cardCount == 3)
    }

    @Test func normalAndFoilAreTrackedSeparately() throws {
        let fixture = try makeFixture()
        let normal = try own(1, variant: .normal, in: fixture.context)
        let foil = try own(2, variant: .foil, in: fixture.context)
        let trove = try box(fixture.manager)

        fixture.manager.store(foil, quantity: 2, in: trove)

        #expect(fixture.manager.unsortedQuantity(for: normal) == 1)
        #expect(fixture.manager.unsortedQuantity(for: foil) == 0)
    }

    // MARK: - Binders

    @Test func binderCopiesTakeConsecutivePockets() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let binder = try binder(fixture.manager)

        fixture.manager.store(elsa, quantity: 3, in: binder)

        #expect(fixture.manager.occupiedSlots(in: binder) == [0, 1, 2])
        let pockets = fixture.manager.locations(for: elsa).first?.pockets
        #expect(pockets?.first == StorageAllocation.BinderPocket(page: 1, pocket: 1))
    }

    @Test func fullBinderStoresOnlyWhatFits() throws {
        let fixture = try makeFixture()
        let elsa = try own(10, in: fixture.context)
        let binder = try binder(fixture.manager, pockets: 4, sheets: 1) // 8 pockets

        #expect(fixture.manager.store(elsa, quantity: 10, in: binder) == 8)
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 2)
    }

    @Test func setBinderPutsCardsInTheirNumberedPocket() throws {
        let fixture = try makeFixture()
        let card = try own(1, of: "Mickey", number: 12, in: fixture.context)
        let binder = try binder(fixture.manager)
        binder.linkedSetName = "The First Chapter"

        fixture.manager.store(card, in: binder)

        #expect(fixture.manager.occupiedSlots(in: binder) == [11])
    }

    // MARK: - Set checklist binders

    private func setBinder(_ manager: StorageManager) throws -> StorageContainer {
        let binder = try binder(manager, pockets: 9, sheets: 2)
        binder.linkedSetName = "The First Chapter"
        return binder
    }

    @Test func setBindersRefuseOtherSets() throws {
        let fixture = try makeFixture()
        let stranger = try own(1, of: "Stitch", number: 3, setName: "Rise of the Floodborn", in: fixture.context)
        let binder = try setBinder(fixture.manager)

        #expect(fixture.manager.store(stranger, in: binder) == 0)
        #expect(!fixture.manager.place(stranger, atSlot: 2, in: binder))
        #expect(!fixture.manager.accepts(stranger, in: binder))
        #expect(fixture.manager.refusal(for: stranger, in: binder) == "Only The First Chapter cards")
    }

    @Test func setBindersHoldOneCopyPerNumberedPocket() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, of: "Elsa", number: 5, in: fixture.context)
        let binder = try setBinder(fixture.manager)

        #expect(fixture.manager.store(elsa, quantity: 3, in: binder) == 1)
        #expect(fixture.manager.occupiedSlots(in: binder) == [4])
        #expect(!fixture.manager.canAccept(elsa, in: binder))
        #expect(fixture.manager.refusal(for: elsa, in: binder) == "Pocket #5 is taken")
    }

    @Test func setBinderCardsOnlyGoInTheirOwnPocket() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, of: "Elsa", number: 5, in: fixture.context)
        let binder = try setBinder(fixture.manager)

        #expect(!fixture.manager.place(elsa, atSlot: 0, in: binder))
        #expect(fixture.manager.place(elsa, atSlot: 4, in: binder))
    }

    @Test func autoFillingASetBinderSkipsOtherSetsAndExtraCopies() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, of: "Elsa", number: 5, in: fixture.context)
        let foilElsa = try own(1, of: "Elsa", number: 5, variant: .foil, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let stranger = try own(1, of: "Stitch", number: 3, setName: "Rise of the Floodborn", in: fixture.context)
        let binder = try setBinder(fixture.manager)

        let placed = fixture.manager.autoFill(
            binder,
            with: [elsa, foilElsa, anna, stranger],
            order: .setNumber,
            setOrder: [:]
        )

        #expect(placed.count == 2)
        #expect(fixture.manager.occupiedSlots(in: binder) == [1, 4])
        #expect(fixture.manager.unsortedQuantity(for: stranger) == 1)
    }

    @Test func specialPrintingsGetTheirOwnNumberedPockets() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 205: .epic, 223: .enchanted] }
        let epic = try own(1, of: "Tiana", number: 205, variant: .epic, in: fixture.context)
        let binder = try binder(fixture.manager, pockets: 9, sheets: 14) // 252 pockets
        binder.linkedSetName = "The First Chapter"

        #expect(fixture.manager.store(epic, in: binder) == 1)
        #expect(fixture.manager.occupiedSlots(in: binder) == [204])
    }

    /// Older versions could save an Enchanted copy under its base card's number; it must
    /// not take the normal card's pocket.
    @Test func mismatchedPrintingsAreKeptOutOfNormalPockets() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 223: .enchanted] }
        let legacyEnchanted = try own(1, of: "Elsa", number: 1, variant: .enchanted, in: fixture.context)
        let foil = try own(1, of: "Elsa", number: 1, variant: .foil, in: fixture.context)
        let binder = try setBinder(fixture.manager)

        #expect(fixture.manager.setPocket(for: legacyEnchanted, in: binder) == nil)
        #expect(fixture.manager.setPocket(for: foil, in: binder) == 0)
    }

    // MARK: - Foils in checklists

    @Test func foilPocketBindersHoldTheNormalAndTheFoil() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let normal = try own(1, of: "Elsa", number: 2, in: fixture.context)
        let foil = try own(1, of: "Elsa", number: 2, variant: .foil, in: fixture.context)
        let binder = try setBinder(fixture.manager)
        binder.hasFoilPockets = true

        #expect(fixture.manager.store(normal, in: binder) == 1)
        #expect(fixture.manager.store(foil, in: binder) == 1)
        #expect(fixture.manager.occupiedSlots(in: binder) == [2, 3])
        #expect(fixture.manager.upgradeTarget(for: foil, in: binder) == nil)
    }

    @Test func aFoilCanUpgradeTheNormalCopyWhenAsked() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let normal = try own(1, of: "Elsa", number: 2, in: fixture.context)
        let foil = try own(1, of: "Elsa", number: 2, variant: .foil, in: fixture.context)
        let binder = try setBinder(fixture.manager)
        fixture.manager.store(normal, in: binder)

        #expect(fixture.manager.store(foil, in: binder) == 0) // never swaps on its own
        #expect(fixture.manager.upgradeTarget(for: foil, in: binder)?.cardVariant == .normal)
        #expect(fixture.manager.refusal(for: foil, in: binder) == "Pocket #2 has the normal copy")

        #expect(fixture.manager.upgradeToFoil(foil, in: binder))

        #expect(fixture.manager.item(atSlot: 1, in: binder)?.cardVariant == .foil)
        #expect(fixture.manager.unsortedQuantity(for: normal) == 1)
        #expect(fixture.manager.unsortedQuantity(for: foil) == 0)
    }

    @Test func autoFillNeverSwapsANormalForAFoil() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let normal = try own(1, of: "Elsa", number: 2, in: fixture.context)
        let foil = try own(1, of: "Elsa", number: 2, variant: .foil, in: fixture.context)
        let binder = try setBinder(fixture.manager)
        fixture.manager.store(normal, in: binder)

        let placed = fixture.manager.autoFill(binder, with: [foil], order: .setNumber, setOrder: [:])

        #expect(placed.isEmpty)
        #expect(fixture.manager.item(atSlot: 1, in: binder)?.cardVariant == .normal)
    }

    @Test func movingIntoAnOccupiedPocketSwaps() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.store(elsa, in: binder)
        fixture.manager.store(anna, in: binder)

        let elsaItem = try #require(fixture.manager.item(atSlot: 0, in: binder))
        fixture.manager.moveItem(elsaItem, toSlot: 1)

        #expect(fixture.manager.item(atSlot: 0, in: binder)?.name == "Anna")
        #expect(fixture.manager.item(atSlot: 1, in: binder)?.name == "Elsa")
    }

    @Test func placeRejectsTakenPocketsAndMissingCopies() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, in: fixture.context)
        let binder = try binder(fixture.manager)

        #expect(fixture.manager.place(elsa, atSlot: 5, in: binder))
        #expect(!fixture.manager.place(elsa, atSlot: 6, in: binder)) // no unsorted copy left
        #expect(fixture.manager.occupiedSlots(in: binder) == [5])
    }

    @Test func compactClosesGaps() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.place(elsa, atSlot: 4, in: binder)
        fixture.manager.place(elsa, atSlot: 9, in: binder)

        fixture.manager.compact(binder)

        #expect(fixture.manager.occupiedSlots(in: binder) == [0, 1])
    }

    @Test func autoFillPlacesUnsortedCopiesInOrder() throws {
        let fixture = try makeFixture()
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let elsa = try own(2, of: "Elsa", number: 1, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 1, in: trove)
        let binder = try binder(fixture.manager)

        let placed = fixture.manager.autoFill(
            binder,
            with: [anna, elsa],
            order: .setNumber,
            setOrder: ["The First Chapter": 1]
        )

        // Only one Elsa is still unsorted; set order puts #1 before #2.
        #expect(placed.map(\.name) == ["Elsa", "Anna"])
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 0)
        #expect(fixture.manager.unsortedQuantity(for: anna) == 0)
    }

    @Test func shrinkingABinderRehomesStrandedCards() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, in: fixture.context)
        let binder = try binder(fixture.manager, pockets: 9, sheets: 2) // 36 pockets
        fixture.manager.place(elsa, atSlot: 30, in: binder)

        binder.sheetCount = 1 // 18 pockets
        fixture.manager.containerDidChange(binder)

        #expect(fixture.manager.occupiedSlots(in: binder) == [0])
    }

    // MARK: - Moving and removing

    @Test func moveTransfersWithoutPassingThroughUnsorted() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)
        let binder = try binder(fixture.manager)
        fixture.manager.store(elsa, quantity: 3, in: trove)

        fixture.manager.move(elsa, quantity: 2, from: trove, to: binder)

        #expect(trove.cardCount == 1)
        #expect(binder.cardCount == 2)
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 0)
    }

    @Test func unstoreReturnsCopiesToUnsorted() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 2, in: trove)

        fixture.manager.unstore(elsa, quantity: 1, from: trove)

        #expect(fixture.manager.unsortedQuantity(for: elsa) == 1)
    }

    @Test func deletingAContainerKeepsCardsInTheCollection() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 2, in: trove)

        fixture.manager.delete(trove)

        #expect(fixture.manager.containers.isEmpty)
        #expect(fixture.manager.ownedQuantity(for: elsa) == 2)
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 2)
        #expect(try fixture.context.fetch(FetchDescriptor<StoredCard>()).isEmpty)
    }

    // MARK: - Reconciliation

    @Test func reconcileTrimsTheMostRecentlyStoredCopies() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)
        let deckBox = try box(fixture.manager, name: "Deck Box")
        fixture.manager.store(elsa, quantity: 2, in: trove)
        fixture.manager.store(elsa, quantity: 1, in: deckBox)
        deckBox.items?.first?.dateStored = .now.addingTimeInterval(60)

        let trimmed = fixture.manager.reconcile(elsa, ownedQuantity: 2)

        #expect(trimmed.map(\.containerName) == ["Deck Box"])
        #expect(trove.cardCount == 2)
        #expect(deckBox.cardCount == 0)
    }

    @Test func reconcileDoesNothingWhenStorageFits() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 2, in: trove)

        #expect(fixture.manager.reconcile(elsa, ownedQuantity: 2).isEmpty)
        #expect(trove.cardCount == 2)
    }

    @Test func removingACardFromTheCollectionClearsItsStorage() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.store(elsa, quantity: 2, in: binder)

        fixture.manager.reconcile(elsa, ownedQuantity: 0)

        #expect(fixture.manager.storedQuantity(for: elsa) == 0)
        #expect(binder.items?.isEmpty == true)
    }

    /// CloudKit can deliver storage rows before the collection rows they belong to.
    /// Trimming those as "not owned" would wipe the collector's storage on a new device.
    @Test func reconcileAllLeavesCardsWithNoCollectionRowAlone() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, in: trove)

        let row = try #require(try fixture.context.fetch(FetchDescriptor<CollectedCard>()).first)
        fixture.context.delete(row)
        try fixture.context.save()
        fixture.manager.reconcileAll()

        #expect(trove.cardCount == 1)
    }

    @Test func reconcileAllTrimsOverStoredCards() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 3, in: trove)

        let row = try #require(try fixture.context.fetch(FetchDescriptor<CollectedCard>()).first)
        row.quantity = 1
        try fixture.context.save()
        fixture.manager.reconcileAll()

        #expect(trove.cardCount == 1)
    }

    // MARK: - Sync duplicates

    @Test func duplicatePocketClaimsMoveTheLaterCard() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.place(elsa, atSlot: 0, in: binder)

        // Simulate another device's row landing in the same pocket.
        let clash = StoredCard(from: anna, slotIndex: 0)
        clash.dateStored = .now.addingTimeInterval(60)
        fixture.context.insert(clash)
        clash.container = binder
        try fixture.context.save()

        fixture.manager.mergeDuplicateStoredCards()

        #expect(fixture.manager.item(atSlot: 0, in: binder)?.name == "Elsa")
        #expect(fixture.manager.item(atSlot: 1, in: binder)?.name == "Anna")
    }

    @Test func duplicateBoxRowsFoldTogether() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let trove = try box(fixture.manager)
        fixture.manager.store(elsa, quantity: 2, in: trove)

        let duplicate = StoredCard(from: elsa, quantity: 1)
        fixture.context.insert(duplicate)
        duplicate.container = trove
        try fixture.context.save()

        fixture.manager.mergeDuplicateStoredCards()

        #expect(trove.items?.count == 1)
        #expect(trove.cardCount == 2)
    }

    // MARK: - Room

    @Test func fullBoxesTakeNoMore() throws {
        let fixture = try makeFixture()
        let elsa = try own(5, in: fixture.context)
        let trove = try box(fixture.manager)
        trove.capacity = 3

        #expect(fixture.manager.store(elsa, quantity: 5, in: trove) == 3)
        #expect(fixture.manager.isFull(trove))
        #expect(fixture.manager.store(elsa, in: trove) == 0)
        #expect(fixture.manager.unsortedQuantity(for: elsa) == 2)
    }

    @Test func boxesWithoutCapacityNeverFill() throws {
        let fixture = try makeFixture()
        let elsa = try own(5, in: fixture.context)
        let trove = try box(fixture.manager)
        trove.capacity = nil
        fixture.manager.store(elsa, quantity: 5, in: trove)

        #expect(fixture.manager.freeSpace(in: trove) == nil)
        #expect(!fixture.manager.isFull(trove))
    }

    @Test func freeSpaceCountsEmptyBinderPockets() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, in: fixture.context)
        let binder = try binder(fixture.manager, pockets: 4, sheets: 1) // 8 pockets
        fixture.manager.store(elsa, quantity: 3, in: binder)

        #expect(fixture.manager.freeSpace(in: binder) == 5)
    }

    @Test func movingIntoAFullContainerMovesOnlyWhatFits() throws {
        let fixture = try makeFixture()
        let elsa = try own(4, in: fixture.context)
        let source = try box(fixture.manager, name: "Source")
        let destination = try box(fixture.manager, name: "Small")
        destination.capacity = 1
        fixture.manager.store(elsa, quantity: 4, in: source)

        fixture.manager.move(elsa, quantity: 4, from: source, to: destination)

        #expect(destination.cardCount == 1)
        #expect(source.cardCount == 3)
        #expect(fixture.manager.storedQuantity(for: elsa) == 4)
    }

    // MARK: - Limits

    @Test func freeUsersAreLimitedToThreeContainers() throws {
        let fixture = try makeFixture()
        for index in 0..<StorageManager.freeContainerLimit {
            _ = try box(fixture.manager, name: "Box \(index)")
        }
        #expect(!fixture.manager.canCreateContainer(isSubscribed: false))
        #expect(fixture.manager.canCreateContainer(isSubscribed: true))
    }
}
