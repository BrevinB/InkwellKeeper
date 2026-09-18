//
//  CostBasisTests.swift
//  Inkwell KeeperTests
//
//  What was paid against what it is worth. The important cases are the ones
//  where a naive sum would invent a profit.
//

import Testing
import Foundation
import SwiftData
@testable import Inkwell_Keeper

@MainActor
struct CostBasisTests {
    /// An in-memory container, so these exercise real CollectedCard records
    /// rather than a stand-in.
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: CollectedCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @discardableResult
    private func card(
        in context: ModelContext,
        id: String = "TFC-1",
        name: String = "Ariel",
        quantity: Int = 1,
        paid: Double?,
        stored: Double? = nil,
        variant: String = "Normal"
    ) -> CollectedCard {
        let card = CollectedCard(
            cardId: id,
            name: name,
            cost: 1,
            type: "Character",
            rarity: .common,
            setName: "The First Chapter",
            imageUrl: "",
            price: stored,
            quantity: quantity,
            variant: CardVariant(rawValue: variant) ?? .normal
        )
        card.purchasePrice = paid
        context.insert(card)
        return card
    }

    private func fixedPrice(_ value: Double?) -> CostBasisCalculator.PriceLookup {
        { _, stored in value ?? stored }
    }

    // MARK: - Summary

    @Test func gainIsMarketValueMinusWhatWasPaid() throws {
        let context = try makeContext()
        card(in: context, quantity: 2, paid: 1.00)

        let summary = CostBasisCalculator.summary(
            for: [try context.fetch(FetchDescriptor<CollectedCard>())[0]],
            price: fixedPrice(3.00)
        )

        #expect(summary.costBasis == 2.00)
        #expect(summary.marketValue == 6.00)
        #expect(summary.gain == 4.00)
        #expect(summary.percentGain == 200.0)
    }

    /// A missing purchase price is unknown, not zero. Counting it as zero would
    /// report the card's whole market value as profit.
    @Test func copiesWithoutARecordedPriceAreExcludedFromBothSides() throws {
        let context = try makeContext()
        card(in: context, id: "a", quantity: 1, paid: 1.00)
        card(in: context, id: "b", quantity: 3, paid: nil)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let summary = CostBasisCalculator.summary(for: cards, price: fixedPrice(10.00))

        #expect(summary.costBasis == 1.00)
        #expect(summary.marketValue == 10.00)
        #expect(summary.recordedCopies == 1)
        #expect(summary.unrecordedCopies == 3)
        #expect(summary.isPartial)
    }

    /// Without a market price the card contributes what it cost, so it nets to
    /// zero rather than counting on the cost side alone.
    @Test func aCardWithNoMarketPriceDoesNotReadAsATotalLoss() throws {
        let context = try makeContext()
        card(in: context, quantity: 1, paid: 5.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let summary = CostBasisCalculator.summary(for: cards, price: { _, _ in nil })

        #expect(summary.costBasis == 5.00)
        #expect(summary.marketValue == 5.00)
        #expect(summary.gain == 0)
    }

    @Test func aLossIsReportedAsNegative() throws {
        let context = try makeContext()
        card(in: context, quantity: 1, paid: 10.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let summary = CostBasisCalculator.summary(for: cards, price: fixedPrice(4.00))

        #expect(summary.gain == -6.00)
        #expect(summary.percentGain == -60.0)
    }

    @Test func aFreeCardIsStillARecordedCost() throws {
        let context = try makeContext()
        card(in: context, quantity: 1, paid: 0)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let summary = CostBasisCalculator.summary(for: cards, price: fixedPrice(3.00))

        #expect(summary.recordedCopies == 1)
        #expect(summary.gain == 3.00)
        // No percentage from a zero cost basis.
        #expect(summary.percentGain == nil)
    }

    @Test func zeroQuantityRowsAreIgnored() throws {
        let context = try makeContext()
        card(in: context, quantity: 0, paid: 5.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let summary = CostBasisCalculator.summary(for: cards, price: fixedPrice(10.00))

        #expect(summary == .empty)
        #expect(summary.hasRecordedCost == false)
    }

    @Test func anEmptyCollectionSummarisesToEmpty() {
        #expect(CostBasisCalculator.summary(for: [], price: fixedPrice(1)) == .empty)
    }

    // MARK: - Entries

    @Test func entriesAreOrderedByTheSizeOfTheMove() throws {
        let context = try makeContext()
        card(in: context, id: "small", name: "Small", quantity: 1, paid: 1.00, stored: 2.00)
        card(in: context, id: "big", name: "Big", quantity: 1, paid: 1.00, stored: 20.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let entries = CostBasisCalculator.entries(for: cards, price: { _, stored in stored })

        #expect(entries.first?.name == "Big")
        #expect(entries.count == 2)
    }

    /// The same printing held in two conditions is two rows but one position.
    @Test func rowsForTheSamePrintingMergeIntoOneEntry() throws {
        let context = try makeContext()
        card(in: context, id: "TFC-1", quantity: 1, paid: 1.00, stored: 5.00)
        card(in: context, id: "TFC-1", quantity: 2, paid: 2.00, stored: 5.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let entries = CostBasisCalculator.entries(for: cards, price: { _, stored in stored })

        #expect(entries.count == 1)
        #expect(entries[0].quantity == 3)
        #expect(entries[0].costBasis == 5.00)     // 1x1.00 + 2x2.00
        #expect(entries[0].marketValue == 15.00)
    }

    @Test func foilAndNormalPrintingsStaySeparateEntries() throws {
        let context = try makeContext()
        card(in: context, id: "TFC-1", quantity: 1, paid: 1.00, stored: 2.00, variant: "Normal")
        card(in: context, id: "TFC-1", quantity: 1, paid: 4.00, stored: 9.00, variant: "Foil")

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let entries = CostBasisCalculator.entries(for: cards, price: { _, stored in stored })

        #expect(entries.count == 2)
        #expect(entries.contains { $0.isFoil })
        #expect(entries.contains { !$0.isFoil })
    }

    @Test func cardsWithoutARecordedPriceProduceNoEntry() throws {
        let context = try makeContext()
        card(in: context, quantity: 1, paid: nil, stored: 5.00)

        let cards = try context.fetch(FetchDescriptor<CollectedCard>())
        let entries = CostBasisCalculator.entries(for: cards, price: { _, stored in stored })

        #expect(entries.isEmpty)
    }
}
