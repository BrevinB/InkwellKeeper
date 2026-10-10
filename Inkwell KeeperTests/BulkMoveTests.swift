//
//  BulkMoveTests.swift
//  Inkwell KeeperTests
//
//  Moving many cards at once between binders, boxes and Unsorted: everything that
//  fits arrives, nothing that doesn't is lost, and no copy is ever duplicated.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct BulkMoveTests {
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
    private func own(_ quantity: Int, number: Int, setName: String = "The First Chapter", in context: ModelContext) throws -> LorcanaCard {
        let row = CollectedCard(
            cardId: "card-\(number)",
            name: "Card \(number)",
            cost: 1,
            type: "Character",
            rarity: .common,
            setName: setName,
            imageUrl: "",
            price: 1,
            quantity: quantity,
            variant: .normal,
            uniqueId: "TFC-\(number)",
            cardNumber: number
        )
        context.insert(row)
        try context.save()
        return row.toLorcanaCard
    }

    @Test func movesABinderSelectionIntoABox() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let binder = try #require(manager.createContainer(name: "Binder", kind: .binder))
        let trove = try #require(manager.createContainer(name: "Trove", kind: .trove))
        for number in 1...3 {
            let card = try own(1, number: number, in: fixture.context)
            manager.store(card, in: binder)
        }

        let result = manager.moveItems(binder.items ?? [], to: trove)

        #expect(result == StorageManager.BulkMoveResult(moved: 3, leftBehind: 0))
        #expect(binder.cardCount == 0)
        #expect(trove.cardCount == 3)
    }

    @Test func whatDoesNotFitStaysWhereItWas() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let trove = try #require(manager.createContainer(name: "Trove", kind: .trove))
        let small = try #require(manager.createContainer(name: "Small", kind: .storageBox) { $0.capacity = 2 })
        let card = try own(5, number: 1, in: fixture.context)
        manager.store(card, quantity: 5, in: trove)

        let result = manager.moveItems(trove.items ?? [], to: small)

        #expect(result == StorageManager.BulkMoveResult(moved: 2, leftBehind: 3))
        #expect(small.cardCount == 2)
        #expect(trove.cardCount == 3)
        #expect(manager.storedQuantity(for: card) == 5)
    }

    @Test func movingToUnsortedEmptiesTheSelection() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let trove = try #require(manager.createContainer(name: "Trove", kind: .trove))
        let card = try own(4, number: 1, in: fixture.context)
        manager.store(card, quantity: 4, in: trove)

        let result = manager.moveItems(trove.items ?? [], to: nil)

        #expect(result.moved == 4)
        #expect(trove.cardCount == 0)
        #expect(manager.unsortedQuantity(for: card) == 4)
    }

    @Test func aSetBinderOnlyTakesItsOwnSet() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        manager.catalogPrintings = { _ in [1: .normal, 2: .normal] }
        let trove = try #require(manager.createContainer(name: "Trove", kind: .trove))
        let checklist = try #require(manager.createContainer(name: "TFC", kind: .binder) {
            $0.linkedSetName = "The First Chapter"
        })
        let inSet = try own(1, number: 1, in: fixture.context)
        let otherSet = try own(1, number: 2, setName: "Rise of the Floodborn", in: fixture.context)
        manager.store(inSet, in: trove)
        manager.store(otherSet, in: trove)

        let result = manager.moveItems(trove.items ?? [], to: checklist)

        #expect(result == StorageManager.BulkMoveResult(moved: 1, leftBehind: 1))
        #expect(manager.item(atSlot: 0, in: checklist)?.name == inSet.name)
        #expect(trove.cardCount == 1)
    }

    @Test func cardsAlreadyThereAreLeftAlone() throws {
        let fixture = try makeFixture()
        let manager = fixture.manager
        let trove = try #require(manager.createContainer(name: "Trove", kind: .trove))
        let card = try own(2, number: 1, in: fixture.context)
        manager.store(card, quantity: 2, in: trove)

        let result = manager.moveItems(trove.items ?? [], to: trove)

        #expect(result == StorageManager.BulkMoveResult())
        #expect(trove.cardCount == 2)
    }

    // MARK: - Binder select mode

    @Test func selectModeTogglesCardsAndIgnoresEmptyPockets() {
        let model = BinderViewModel(layout: BinderLayout(pocketsPerPage: 9, sheetCount: 2, isDoubleSided: true), isTwoUp: false)
        model.isSelecting = true
        let id = UUID()
        #expect(model.action(forTapOnSlot: 0, occupant: id) == .toggleSelection(id))
        #expect(model.action(forTapOnSlot: 1, occupant: nil) == .none)
        model.toggleSelection(id)
        #expect(model.selectedItemIds == [id])
        model.toggleSelection(id)
        #expect(model.selectedItemIds.isEmpty)
    }

    @Test func selectingAndArrangingNeverOverlap() {
        let model = BinderViewModel(layout: BinderLayout(pocketsPerPage: 9, sheetCount: 2, isDoubleSided: true), isTwoUp: false)
        model.isEditing = true
        model.isSelecting = true
        #expect(!model.isEditing)
        model.toggleSelection(UUID())
        model.isEditing = true
        #expect(!model.isSelecting)
        #expect(model.selectedItemIds.isEmpty)
    }

    // MARK: - iPad spreads

    @Test func onASpreadTheBinderIsHeldOnTheRightPage() throws {
        let binder = StorageContainer(name: "Binder", kind: .binder)
        let size = CGSize(width: 1024, height: 768)
        let stages = BookshelfViewModel.stages(for: binder, in: size, spreads: true)
        let spread = try #require(stages.spread)
        #expect(CGRect(origin: .zero, size: size).contains(spread))
        #expect(stages.page.minX == spread.midX)
        #expect(stages.page.width == spread.width / 2)
        #expect(abs(spread.midX - size.width / 2) < 0.001)
    }

    @Test func boxesAndOnePageBindersHaveNoSpread() {
        let size = CGSize(width: 390, height: 700)
        #expect(BookshelfViewModel.stages(for: StorageContainer(name: "B", kind: .binder), in: size, spreads: false).spread == nil)
        #expect(BookshelfViewModel.stages(for: StorageContainer(name: "T", kind: .trove), in: size, spreads: true).spread == nil)
    }
}
