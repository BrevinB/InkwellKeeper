//
//  StorageBackupTests.swift
//  Inkwell KeeperTests
//
//  Binders and boxes survive a JSON backup: they're written out with every pocket,
//  and restoring puts cards back where they were without ever storing more copies
//  than the collection owns or duplicating containers that are already here.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct StorageBackupTests {
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
    private func own(_ quantity: Int, of name: String, number: Int, in context: ModelContext) throws -> LorcanaCard {
        let row = CollectedCard(
            cardId: name,
            name: name,
            cost: 2,
            type: "Character",
            rarity: .common,
            setName: "The First Chapter",
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

    /// A backup of one binder (Elsa in pocket 4) and one trove (3 Mickeys), made on
    /// a device that has since been wiped, then restored onto `fixture`.
    private func sampleBackup(from source: Fixture) throws -> [InkwellBackup.Container] {
        let elsa = try own(1, of: "Elsa", number: 1, in: source.context)
        let mickey = try own(3, of: "Mickey", number: 2, in: source.context)
        let binder = try #require(source.manager.createContainer(name: "Main Binder", kind: .binder) {
            $0.coverColor = .ruby
            $0.sheetCount = 4
        })
        let trove = try #require(source.manager.createContainer(name: "Trove", kind: .trove))
        #expect(source.manager.place(elsa, atSlot: 4, in: binder))
        source.manager.store(mickey, quantity: 3, in: trove)
        return source.manager.backupContainers()
    }

    @Test func aBackupRoundTripsThroughJSON() throws {
        let backup = InkwellBackup(
            exportDate: "2026-10-04T10:00:00+0000",
            appVersion: "3.5",
            totalCards: 0,
            totalQuantity: 0,
            cards: [],
            storage: try sampleBackup(from: makeFixture())
        )
        let json = try #require(String(data: JSONEncoder().encode(backup), encoding: .utf8))
        #expect(InkwellBackup.looksLikeBackup(json))
        let decoded = try #require(InkwellBackup.decode(json))
        let binder = try #require(decoded.storage?.first { $0.name == "Main Binder" })
        #expect(binder.colorName == StorageCoverColor.ruby.rawValue)
        #expect(binder.sheetCount == 4)
        #expect(binder.items.map(\.slotIndex) == [4])
    }

    @Test func backupsFromBeforeStorageStillRead() throws {
        let json = """
        {"appVersion":"3.2","cards":[],"exportDate":"2026-01-01T00:00:00+0000","totalCards":0,"totalQuantity":0}
        """
        let decoded = try #require(InkwellBackup.decode(json))
        #expect(decoded.storage == nil)
    }

    @Test func theOfficialAppsBackupIsNotMistakenForOurs() {
        #expect(!InkwellBackup.looksLikeBackup(#"{"OwnedCardQuantitiesV2":[]}"#))
        #expect(!InkwellBackup.looksLikeBackup("Elsa,The First Chapter,Normal,1"))
    }

    @Test func restoringPutsCardsBackInTheirPockets() throws {
        let saved = try sampleBackup(from: makeFixture())
        let target = try makeFixture()
        try own(1, of: "Elsa", number: 1, in: target.context)
        try own(3, of: "Mickey", number: 2, in: target.context)

        let summary = target.manager.restore(saved, deckExists: { _ in false })

        #expect(summary == StorageManager.RestoreSummary(containers: 2, cards: 4))
        let binder = try #require(target.manager.containers.first { $0.name == "Main Binder" })
        #expect(binder.coverColor == .ruby)
        #expect(target.manager.item(atSlot: 4, in: binder)?.name == "Elsa")
        let trove = try #require(target.manager.containers.first { $0.kind == .trove })
        #expect(trove.cardCount == 3)
    }

    @Test func restoringNeverStoresMoreThanIsOwned() throws {
        let saved = try sampleBackup(from: makeFixture())
        let target = try makeFixture()
        // Only one Mickey came back with the cards, and no Elsa at all.
        try own(1, of: "Mickey", number: 2, in: target.context)

        let summary = target.manager.restore(saved, deckExists: { _ in false })

        #expect(summary.cards == 1)
        let binder = try #require(target.manager.containers.first { $0.kind == .binder })
        #expect(binder.cardCount == 0)
        let trove = try #require(target.manager.containers.first { $0.kind == .trove })
        #expect(trove.cardCount == 1)
    }

    @Test func restoringTwiceDoesNotDuplicateContainers() throws {
        let saved = try sampleBackup(from: makeFixture())
        let target = try makeFixture()
        try own(1, of: "Elsa", number: 1, in: target.context)
        try own(3, of: "Mickey", number: 2, in: target.context)

        target.manager.restore(saved, deckExists: { _ in false })
        let again = target.manager.restore(saved, deckExists: { _ in false })

        #expect(again == StorageManager.RestoreSummary())
        #expect(target.manager.containers.count == 2)
    }

    @Test func aDeckBoxOnlyRelinksToADeckThatStillExists() throws {
        let deckId = UUID()
        let box = InkwellBackup.Container(
            id: UUID(), name: "Amber Steel", kind: StorageKind.deckBox.rawValue,
            coverStyle: "classic", colorName: "amber", sortOrder: 0, notes: "",
            pocketsPerPage: 9, sheetCount: 20, isDoubleSided: true, capacity: 60,
            linkedSetName: nil, hasFoilPockets: false, linkedDeckId: deckId, items: []
        )
        let gone = try makeFixture()
        gone.manager.restore([box], deckExists: { _ in false })
        #expect(gone.manager.containers.first?.linkedDeckId == nil)

        let kept = try makeFixture()
        kept.manager.restore([box], deckExists: { $0 == deckId })
        #expect(kept.manager.containers.first?.linkedDeckId == deckId)
    }
}
