//
//  TradeSideTests.swift
//  Inkwell KeeperTests
//
//  Building and valuing one half of a trade. The case that matters most is the
//  price keying: a foil and its normal printing share a card id and must not
//  share a price.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct TradeSideTests {
    private func card(
        id: String = "TFC-1",
        name: String = "Ariel",
        variant: CardVariant = .normal
    ) -> LorcanaCard {
        LorcanaCard(
            id: id,
            name: name,
            cost: 1,
            type: "Character",
            rarity: .common,
            setName: "The First Chapter",
            imageUrl: "",
            variant: variant
        )
    }

    // MARK: - Building a side

    @Test func addingTheSamePrintingTwiceIncrementsIt() {
        var side = TradeSide()
        side.add(card())
        side.add(card())

        #expect(side.lines.count == 1)
        #expect(side.lines[0].quantity == 2)
        #expect(side.cardCount == 2)
    }

    @Test func foilAndNormalPrintingsAreSeparateLines() {
        var side = TradeSide()
        side.add(card(variant: .normal))
        side.add(card(variant: .foil))

        #expect(side.lines.count == 2)
        #expect(side.cardCount == 2)
    }

    @Test func removingDecrementsBeforeDeleting() {
        var side = TradeSide()
        side.add(card())
        side.add(card())
        let lineID = side.lines[0].id

        side.remove(lineID)
        #expect(side.lines[0].quantity == 1)

        side.remove(lineID)
        #expect(side.lines.isEmpty)
    }

    @Test func removingSomethingNotThereIsHarmless() {
        var side = TradeSide()
        side.add(card())

        side.remove("not-a-line")

        #expect(side.lines.count == 1)
    }

    // MARK: - Pricing

    /// Both printings carry the same `card.id`, so keying prices on that would
    /// value a foil at its normal print's price.
    @Test func eachPrintingTakesItsOwnPrice() {
        var side = TradeSide()
        side.add(card(variant: .normal))
        side.add(card(variant: .foil))

        side.applyPrices([
            "TFC-1|Normal": 0.17,
            "TFC-1|Foil": 0.83
        ])

        let normal = side.lines.first { $0.card.variant == .normal }
        let foil = side.lines.first { $0.card.variant == .foil }
        #expect(normal?.unitPrice == 0.17)
        #expect(foil?.unitPrice == 0.83)
    }

    @Test func lineTotalsMultiplyByQuantity() {
        var side = TradeSide()
        side.add(card())
        side.add(card())
        side.applyPrices(["TFC-1|Normal": 2.50])

        #expect(side.lines[0].total == 5.00)
        #expect(side.total == 5.00)
    }

    /// An unpriced line is unknown, not free: it stays out of the total and is
    /// reported separately so the UI can say the figure is incomplete.
    @Test func unpricedLinesAreExcludedFromTheTotalAndCounted() {
        var side = TradeSide()
        side.add(card(id: "a", name: "Priced"))
        side.add(card(id: "b", name: "Unpriced"))
        side.add(card(id: "b", name: "Unpriced"))

        side.applyPrices(["a|Normal": 3.00])

        #expect(side.total == 3.00)
        #expect(side.unpricedCount == 2)
    }

    @Test func aPriceForSomethingNotOnThisSideIsIgnored() {
        var side = TradeSide()
        side.add(card())

        side.applyPrices(["something-else": 99.0])

        #expect(side.lines[0].unitPrice == nil)
        #expect(side.total == 0)
    }

    @Test func anEmptySideTotalsToZero() {
        let side = TradeSide()

        #expect(side.total == 0)
        #expect(side.cardCount == 0)
        #expect(side.unpricedCount == 0)
    }
}
