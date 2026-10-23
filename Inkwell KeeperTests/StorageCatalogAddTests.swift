//
//  StorageCatalogAddTests.swift
//  Inkwell KeeperTests
//
//  Putting cards away from the whole catalog: copies the collector doesn't have
//  unsorted are added to the collection first, but only as many as will fit.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct StorageCatalogAddTests {
    private struct Fixture {
        let context: ModelContext
        let storage: StorageManager
        let collection: CollectionManager
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: CollectedCard.self, StorageContainer.self, StoredCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let storage = StorageManager()
        storage.setModelContext(context)
        let collection = CollectionManager()
        collection.setModelContext(context)
        return Fixture(context: context, storage: storage, collection: collection)
    }

    /// A catalog card the collector may or may not own.
    private func card(_ name: String = "Elsa", number: Int = 1, variant: CardVariant = .normal) -> LorcanaCard {
        LorcanaCard(
            id: "\(name)-\(variant.rawValue)",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: "The First Chapter",
            imageUrl: "",
            price: 2.50,
            variant: variant,
            cardNumber: number,
            uniqueId: "TFC-\(number)",
            inkColor: nil
        )
    }

    @Test func unownedCardsAreAddedToTheCollectionAndStored() throws {
        let fixture = try makeFixture()
        let elsa = card()
        let trove = try #require(fixture.storage.createContainer(name: "Trove", kind: .trove))

        let result = fixture.storage.storeAddingToCollection([(elsa, 2)], in: trove, collection: fixture.collection)

        #expect(result.stored == 2)
        #expect(result.added == 2)
        #expect(fixture.storage.ownedQuantity(for: elsa) == 2)
        #expect(fixture.storage.unsortedQuantity(for: elsa) == 0)
    }

    @Test func unsortedCopiesAreUsedBeforeAddingMore() throws {
        let fixture = try makeFixture()
        let elsa = card()
        fixture.collection.addCard(elsa)
        let trove = try #require(fixture.storage.createContainer(name: "Trove", kind: .trove))

        let result = fixture.storage.storeAddingToCollection([(elsa, 3)], in: trove, collection: fixture.collection)

        #expect(result.stored == 3)
        #expect(result.added == 2)
        #expect(fixture.storage.ownedQuantity(for: elsa) == 3)
    }

    @Test func onlyCopiesThatFitAreAdded() throws {
        let fixture = try makeFixture()
        let elsa = card()
        let binder = try #require(fixture.storage.createContainer(name: "Binder", kind: .binder) {
            $0.pocketsPerPage = 4
            $0.sheetCount = 1
            $0.isDoubleSided = false
        })

        let result = fixture.storage.storeAddingToCollection([(elsa, 10)], in: binder, collection: fixture.collection)

        #expect(result.stored == 4)
        #expect(result.added == 4)
        #expect(fixture.storage.ownedQuantity(for: elsa) == 4)
    }

    @Test func fillingATakenPocketAddsNothing() throws {
        let fixture = try makeFixture()
        let elsa = card()
        let anna = card("Anna", number: 2)
        let binder = try #require(fixture.storage.createContainer(name: "Binder", kind: .binder))
        #expect(fixture.storage.placeAddingToCollection(elsa, atSlot: 0, in: binder, collection: fixture.collection))

        #expect(!fixture.storage.placeAddingToCollection(anna, atSlot: 0, in: binder, collection: fixture.collection))
        #expect(fixture.storage.ownedQuantity(for: anna) == 0)
        #expect(fixture.storage.ownedQuantity(for: elsa) == 1)
    }

    @Test func copiesToAddCountsOnlyWhatUnsortedCannotCover() {
        let selection = ["a": 3, "b": 1, "c": 2]
        let unsorted = ["a": 1, "b": 4]
        #expect(AddCardsSource.copiesToAdd(selection: selection, unsorted: unsorted) == 4)
    }
}
