//
//  DeckBuildTests.swift
//  Inkwell KeeperTests
//
//  Idea decks vs built decks: building moves real copies into a deck box, the pull
//  list says where each copy is, and taking a deck apart puts cards back.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct DeckBuildTests {
    private struct Fixture {
        let context: ModelContext
        let storage: StorageManager
        let collection: CollectionManager
    }

    private func makeFixture() throws -> Fixture {
        let container = try ModelContainer(
            for: CollectedCard.self, StorageContainer.self, StoredCard.self, Deck.self, DeckCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let storage = StorageManager()
        storage.setModelContext(context)
        let collection = CollectionManager()
        collection.setModelContext(context)
        return Fixture(context: context, storage: storage, collection: collection)
    }

    @discardableResult
    private func own(_ quantity: Int, _ name: String, number: Int, variant: CardVariant = .normal, in context: ModelContext) throws -> LorcanaCard {
        let row = CollectedCard(
            cardId: "\(name)-\(variant.rawValue)", name: name, cost: 2, type: "Character",
            rarity: .common, setName: "The First Chapter", imageUrl: "", quantity: quantity,
            variant: variant, uniqueId: "TFC-\(number)", cardNumber: number
        )
        context.insert(row)
        try context.save()
        return row.toLorcanaCard
    }

    private func deck(_ cards: [(LorcanaCard, Int)], in context: ModelContext) throws -> Deck {
        let deck = Deck(name: "Ruby Steel", inkColors: [.ruby])
        context.insert(deck)
        for (card, quantity) in cards {
            let deckCard = DeckCard(from: card, quantity: quantity)
            context.insert(deckCard)
            deckCard.deck = deck
        }
        try context.save()
        return deck
    }

    // MARK: - Ideas vs built

    @Test func ideaDecksDoNotClaimCards() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, "Elsa", number: 1, in: fixture.context)
        _ = try deck([(elsa, 2)], in: fixture.context)

        #expect(fixture.collection.getTotalDeckAllocation(for: elsa) == 0)
        #expect(fixture.storage.unsortedQuantity(for: elsa) == 2)
    }

    @Test func builtDecksClaimOnlyWhatIsInTheBox() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, "Elsa", number: 1, in: fixture.context)
        let deck = try deck([(elsa, 2)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))

        #expect(fixture.collection.getTotalDeckAllocation(for: elsa) == 0)
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        #expect(fixture.collection.getDeckAllocations(for: elsa).map(\.deckName) == ["Ruby Steel"])
        #expect(fixture.collection.getTotalDeckAllocation(for: elsa) == 2)
        #expect(fixture.storage.unsortedQuantity(for: elsa) == 1)
    }

    @Test func deckBoxesHoldingADeckDoNotCountTowardTheFreeLimit() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        for index in 0..<StorageManager.freeContainerLimit - 1 {
            fixture.storage.createContainer(name: "Box \(index)", kind: .trove)
        }
        fixture.storage.createDeckBox(for: try deck([(elsa, 1)], in: fixture.context))

        #expect(fixture.storage.canCreateContainer(isSubscribed: false))
    }

    // MARK: - Pull plan

    @Test func planPrefersUnsortedThenBindersWithPockets() throws {
        let fixture = try makeFixture()
        let elsa = try own(3, "Elsa", number: 1, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "Main Binder", kind: .binder))
        fixture.storage.place(elsa, atSlot: 13, in: binder)
        fixture.storage.place(elsa, atSlot: 14, in: binder)
        let deck = try deck([(elsa, 3)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))

        let plan = fixture.storage.pullPlan(for: deck, into: box)

        #expect(plan.pulls.map(\.sourceName) == ["Unsorted", "Main Binder"])
        #expect(plan.pulls.last?.slots == [13, 14])
        #expect(plan.pulls.last?.pockets.first == .init(page: 2, pocket: 5))
        #expect(plan.missing.isEmpty)
    }

    @Test func foilCopiesCanFillANormalSlot() throws {
        let fixture = try makeFixture()
        let normal = try own(1, "Elsa", number: 1, in: fixture.context)
        try own(1, "Elsa", number: 1, variant: .foil, in: fixture.context)
        let deck = try deck([(normal, 2)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))

        let plan = fixture.storage.pullPlan(for: deck, into: box)

        #expect(plan.toPull == 2)
        #expect(Set(plan.pulls.map(\.card.variant)) == [.normal, .foil])
    }

    @Test func otherBuiltDecksAreNeverRaided() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, "Elsa", number: 1, in: fixture.context)
        let first = try deck([(elsa, 2)], in: fixture.context)
        let firstBox = try #require(fixture.storage.createDeckBox(for: first))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: first, into: firstBox), into: firstBox)

        let second = try deck([(elsa, 1)], in: fixture.context)
        let secondBox = try #require(fixture.storage.createDeckBox(for: second))
        let plan = fixture.storage.pullPlan(for: second, into: secondBox)

        #expect(plan.pulls.isEmpty)
        #expect(plan.missingCount == 1)
    }

    @Test func progressCountsCopiesAlreadyInTheBox() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, "Anna", number: 2, in: fixture.context)
        let deck = try deck([(elsa, 2), (anna, 2)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        let progress = fixture.storage.deckProgress(deck, in: box)
        #expect(progress.inBox == 3)
        #expect(progress.total == 4)
        #expect(fixture.storage.pullPlan(for: deck, into: box).missingCount == 1)
    }

    // MARK: - Pulling and taking apart

    @Test func pullingFromABinderFreesThePocketAndRemembersIt() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "Main Binder", kind: .binder))
        fixture.storage.place(elsa, atSlot: 7, in: binder)
        let deck = try deck([(elsa, 1)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))

        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        #expect(fixture.storage.occupiedSlots(in: binder).isEmpty)
        #expect(box.items?.first?.originContainerId == binder.id)
        #expect(box.items?.first?.originSlot == 7)
        #expect(fixture.storage.storedQuantity(for: elsa) == 1)
    }

    @Test func takingApartReturnsCardsToTheirPockets() throws {
        let fixture = try makeFixture()
        let elsa = try own(2, "Elsa", number: 1, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "Main Binder", kind: .binder))
        fixture.storage.place(elsa, atSlot: 7, in: binder)
        let deck = try deck([(elsa, 2)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        let result = fixture.storage.takeApart(box, returnToOrigins: true)

        #expect(result.returned == 1)  // the binder copy
        #expect(result.unsorted == 1)  // the Unsorted copy
        #expect(fixture.storage.occupiedSlots(in: binder) == [7])
        #expect(box.linkedDeckId == nil)
        #expect(!fixture.storage.isBuilt(deck))
    }

    @Test func takingApartFallsBackWhenTheOldPocketIsTaken() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        let anna = try own(1, "Anna", number: 2, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "Main Binder", kind: .binder))
        fixture.storage.place(elsa, atSlot: 0, in: binder)
        let deck = try deck([(elsa, 1)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)
        fixture.storage.place(anna, atSlot: 0, in: binder)

        fixture.storage.takeApart(box, returnToOrigins: true)

        #expect(fixture.storage.item(atSlot: 0, in: binder)?.name == "Anna")
        #expect(fixture.storage.item(atSlot: 1, in: binder)?.name == "Elsa")
    }

    @Test func takingApartNeverPutsACardInTheWrongChecklistPocket() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "TFC Set", kind: .binder) {
            $0.linkedSetName = "The First Chapter"
        })
        fixture.storage.store(elsa, in: binder)
        let deck = try deck([(elsa, 1)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))

        // The only copy is in checklist pocket #1, so that's where it's pulled from.
        let plan = fixture.storage.pullPlan(for: deck, into: box)
        #expect(plan.pulls.map(\.sourceId) == [binder.id])
        fixture.storage.pullAll(plan, into: box)

        // A second copy arrives and fills pocket #1 while the deck is built.
        try own(1, "Elsa", number: 1, in: fixture.context)
        #expect(fixture.storage.store(elsa, in: binder) == 1)

        let result = fixture.storage.takeApart(box, returnToOrigins: true)

        // The pocket is taken and a checklist card has no other valid pocket.
        #expect(result.returned == 0)
        #expect(result.unsorted == 1)
        #expect(fixture.storage.occupiedSlots(in: binder) == [0])
    }

    @Test func takingApartToUnsortedEmptiesTheBox() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        let binder = try #require(fixture.storage.createContainer(name: "Main Binder", kind: .binder))
        fixture.storage.place(elsa, atSlot: 3, in: binder)
        let deck = try deck([(elsa, 1)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        fixture.storage.takeApart(box, returnToOrigins: false)

        #expect(box.cardCount == 0)
        #expect(fixture.storage.occupiedSlots(in: binder).isEmpty)
        #expect(fixture.storage.unsortedQuantity(for: elsa) == 1)
    }

    @Test func deletingABuiltDeckKeepsItsCards() throws {
        let fixture = try makeFixture()
        let elsa = try own(1, "Elsa", number: 1, in: fixture.context)
        let deck = try deck([(elsa, 1)], in: fixture.context)
        let box = try #require(fixture.storage.createDeckBox(for: deck))
        fixture.storage.pullAll(fixture.storage.pullPlan(for: deck, into: box), into: box)

        fixture.storage.unlinkDeck(deck.id)

        #expect(box.linkedDeckId == nil)
        #expect(box.cardCount == 1)
    }
}
