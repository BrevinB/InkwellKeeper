//
//  PocketStackTests.swift
//  Inkwell KeeperTests
//
//  Several copies of one card — normal and foil — sharing a single binder pocket,
//  for collectors who don't give every copy its own pocket.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct PocketStackTests {
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

    @discardableResult
    private func own(
        _ quantity: Int,
        of name: String = "Elsa",
        number: Int = 1,
        variant: CardVariant = .normal,
        in context: ModelContext
    ) throws -> LorcanaCard {
        let row = CollectedCard(
            cardId: "\(name)-\(variant.rawValue)",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: "The First Chapter",
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

    private func binder(_ manager: StorageManager, name: String = "Binder A") throws -> StorageContainer {
        try #require(manager.createContainer(name: name, kind: .binder) {
            $0.pocketsPerPage = 9
            $0.sheetCount = 2
        })
    }

    // MARK: - Stacking

    @Test func normalAndFoilCopiesShareOnePocket() throws {
        let fixture = try makeFixture()
        let normal = try own(3, in: fixture.context)
        let foil = try own(1, variant: .foil, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.place(normal, atSlot: 0, in: binder)

        fixture.manager.setStackCount(3, of: normal, atSlot: 0, in: binder)
        fixture.manager.setStackCount(1, of: foil, atSlot: 0, in: binder)

        #expect(fixture.manager.items(atSlot: 0, in: binder).count == 4)
        #expect(fixture.manager.occupiedSlots(in: binder) == [0])
        #expect(fixture.manager.unsortedQuantity(for: normal) == 0)
        #expect(fixture.manager.unsortedQuantity(for: foil) == 0)
        // A stack takes one pocket, so the rest of the binder is still free.
        #expect(fixture.manager.freeSpace(in: binder) == binder.binderLayout.totalSlots - 1)
        // The normal copy sits on top.
        #expect(fixture.manager.item(atSlot: 0, in: binder)?.cardVariant == .normal)
    }

    @Test func stackingIsCappedAtUnsortedCopies() throws {
        let fixture = try makeFixture()
        let card = try own(2, in: fixture.context)
        let binder = try binder(fixture.manager)

        #expect(fixture.manager.setStackCount(5, of: card, atSlot: 0, in: binder) == 2)
        #expect(fixture.manager.storedQuantity(for: card) == 2)
    }

    @Test func loweringTheCountReturnsCopiesToUnsorted() throws {
        let fixture = try makeFixture()
        let card = try own(3, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(3, of: card, atSlot: 0, in: binder)

        fixture.manager.setStackCount(1, of: card, atSlot: 0, in: binder)
        #expect(fixture.manager.unsortedQuantity(for: card) == 2)

        fixture.manager.setStackCount(0, of: card, atSlot: 0, in: binder)
        #expect(fixture.manager.occupiedSlots(in: binder).isEmpty)
    }

    @Test func aPocketOnlyStacksOneCard() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.place(elsa, atSlot: 0, in: binder)

        #expect(fixture.manager.setStackCount(1, of: anna, atSlot: 0, in: binder) == 0)
        #expect(fixture.manager.items(atSlot: 0, in: binder).map(\.name) == ["Elsa"])
    }

    @Test func emptyingAPocketUnsortsTheWholeStack() throws {
        let fixture = try makeFixture()
        let normal = try own(2, in: fixture.context)
        let foil = try own(1, variant: .foil, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(2, of: normal, atSlot: 4, in: binder)
        fixture.manager.setStackCount(1, of: foil, atSlot: 4, in: binder)

        fixture.manager.emptyPocket(atSlot: 4, in: binder)

        #expect(binder.cardCount == 0)
        #expect(fixture.manager.unsortedQuantity(for: normal) == 2)
        #expect(fixture.manager.unsortedQuantity(for: foil) == 1)
    }

    @Test func stackedPocketsAreListedOnceInLocations() throws {
        let fixture = try makeFixture()
        let card = try own(3, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(3, of: card, atSlot: 0, in: binder)

        let location = try #require(fixture.manager.locations(for: card).first)
        #expect(location.quantity == 3)
        #expect(location.pockets.count == 1)
    }

    // MARK: - Set binders

    @Test func oneCopyPerCardSetBindersStackTheFoilWithTheNormal() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let normal = try own(1, number: 2, in: fixture.context)
        let foil = try own(1, number: 2, variant: .foil, in: fixture.context)
        let binder = try binder(fixture.manager)
        binder.linkedSetName = "The First Chapter"
        fixture.manager.store(normal, in: binder)

        #expect(fixture.manager.setStackCount(1, of: foil, atSlot: 1, in: binder) == 1)
        #expect(fixture.manager.items(atSlot: 1, in: binder).count == 2)
    }

    @Test func foilPocketSetBindersKeepTheFoilInItsOwnPocket() throws {
        let fixture = try makeFixture()
        fixture.manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let normal = try own(1, number: 2, in: fixture.context)
        let foil = try own(1, number: 2, variant: .foil, in: fixture.context)
        let binder = try binder(fixture.manager)
        binder.linkedSetName = "The First Chapter"
        binder.hasFoilPockets = true
        fixture.manager.store(normal, in: binder)
        let normalSlot = try #require(fixture.manager.setPocket(for: normal, in: binder))

        #expect(fixture.manager.stackPrintings(of: normal, atSlot: normalSlot, in: binder).map(\.variant) == [.normal])
        #expect(fixture.manager.setStackCount(1, of: foil, atSlot: normalSlot, in: binder) == 0)
    }

    // MARK: - Arranging

    @Test func movingAPocketMovesItsWholeStack() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(2, of: elsa, atSlot: 0, in: binder)
        fixture.manager.place(anna, atSlot: 1, in: binder)

        let top = try #require(fixture.manager.item(atSlot: 0, in: binder))
        fixture.manager.moveItem(top, toSlot: 1)

        #expect(fixture.manager.items(atSlot: 1, in: binder).map(\.name) == ["Elsa", "Elsa"])
        #expect(fixture.manager.items(atSlot: 0, in: binder).map(\.name) == ["Anna"])
    }

    @Test func closingGapsKeepsStacksTogether() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(2, of: elsa, atSlot: 3, in: binder)
        fixture.manager.place(anna, atSlot: 7, in: binder)

        fixture.manager.compact(binder)

        #expect(fixture.manager.items(atSlot: 0, in: binder).count == 2)
        #expect(fixture.manager.items(atSlot: 1, in: binder).map(\.name) == ["Anna"])
    }

    @Test func bulkMovingAStackIntoAnotherBinderKeepsItInOnePocket() throws {
        let fixture = try makeFixture()
        let normal = try own(2, in: fixture.context)
        let foil = try own(1, variant: .foil, in: fixture.context)
        let source = try binder(fixture.manager)
        let destination = try binder(fixture.manager, name: "Binder B")
        fixture.manager.setStackCount(2, of: normal, atSlot: 5, in: source)
        fixture.manager.setStackCount(1, of: foil, atSlot: 5, in: source)

        let result = fixture.manager.moveItems(source.items ?? [], to: destination)

        #expect(result.moved == 3)
        #expect(source.cardCount == 0)
        #expect(fixture.manager.items(atSlot: 0, in: destination).count == 3)
        #expect(fixture.manager.occupiedSlots(in: destination) == [0])
    }

    // MARK: - Sync

    @Test func syncMergeLeavesSameCardStacksAlone() throws {
        let fixture = try makeFixture()
        let card = try own(3, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.setStackCount(3, of: card, atSlot: 0, in: binder)

        fixture.manager.mergeDuplicateStoredCards()

        #expect(fixture.manager.items(atSlot: 0, in: binder).count == 3)
    }

    @Test func syncMergeMovesADifferentCardsWholeStackTogether() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, of: "Elsa", number: 1, in: fixture.context)
        let anna = try own(2, of: "Anna", number: 2, in: fixture.context)
        let binder = try binder(fixture.manager)
        fixture.manager.place(elsa, atSlot: 0, in: binder)

        // Another device stacked two Annas in the same pocket.
        for offset in 1...2 {
            let clash = StoredCard(from: anna, slotIndex: 0)
            clash.dateStored = .now.addingTimeInterval(Double(offset) * 60)
            fixture.context.insert(clash)
            clash.container = binder
        }
        try fixture.context.save()

        fixture.manager.mergeDuplicateStoredCards()

        #expect(fixture.manager.items(atSlot: 0, in: binder).map(\.name) == ["Elsa"])
        #expect(fixture.manager.items(atSlot: 1, in: binder).map(\.name) == ["Anna", "Anna"])
    }
}
