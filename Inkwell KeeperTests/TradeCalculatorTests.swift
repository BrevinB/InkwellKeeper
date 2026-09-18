//
//  TradeCalculatorTests.swift
//  Inkwell KeeperTests
//
//  The trade view model's own logic: which direction the difference runs, and
//  when a trade is complete enough to confirm.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct TradeCalculatorTests {
    private func card(id: String, name: String = "Card") -> LorcanaCard {
        LorcanaCard(
            id: id,
            name: name,
            cost: 1,
            type: "Character",
            rarity: .common,
            setName: "The First Chapter",
            imageUrl: ""
        )
    }

    /// Builds a model without touching the network: `add` kicks off a price
    /// refresh, so these set prices directly on the sides afterwards.
    private func model() -> TradeCalculatorViewModel {
        TradeCalculatorViewModel()
    }

    @Test func aTradeNeedsBothSidesBeforeItCanBeConfirmed() {
        let viewModel = model()
        #expect(viewModel.canConfirm == false)

        viewModel.yours.add(card(id: "a"))
        #expect(viewModel.canConfirm == false, "one-sided trade is not confirmable")

        viewModel.theirs.add(card(id: "b"))
        #expect(viewModel.canConfirm)
    }

    /// Positive means the other side is worth more — the direction a collector
    /// reads as "I came out ahead".
    @Test func differenceIsPositiveWhenYouReceiveMore() {
        let viewModel = model()
        viewModel.yours.add(card(id: "a"))
        viewModel.theirs.add(card(id: "b"))
        viewModel.yours.applyPrices(["a|Normal": 1.00])
        viewModel.theirs.applyPrices(["b|Normal": 4.00])

        #expect(viewModel.difference == 3.00)
    }

    @Test func differenceIsNegativeWhenYouGiveMore() {
        let viewModel = model()
        viewModel.yours.add(card(id: "a"))
        viewModel.theirs.add(card(id: "b"))
        viewModel.yours.applyPrices(["a|Normal": 9.00])
        viewModel.theirs.applyPrices(["b|Normal": 4.00])

        #expect(viewModel.difference == -5.00)
    }

    @Test func unpricedCardsAreCountedAcrossBothSides() {
        let viewModel = model()
        viewModel.yours.add(card(id: "a"))
        viewModel.theirs.add(card(id: "b"))
        viewModel.yours.applyPrices(["a|Normal": 1.00])

        #expect(viewModel.unpricedCount == 1)
    }

    @Test func clearingEmptiesBothSides() {
        let viewModel = model()
        viewModel.yours.add(card(id: "a"))
        viewModel.theirs.add(card(id: "b"))

        viewModel.clear()

        #expect(viewModel.isEmpty)
        #expect(viewModel.canConfirm == false)
        #expect(viewModel.difference == 0)
    }

    @Test func removingFromOneSideLeavesTheOtherAlone() {
        let viewModel = model()
        viewModel.yours.add(card(id: "a"))
        viewModel.theirs.add(card(id: "b"))

        viewModel.remove("a|Normal", from: .yours)

        #expect(viewModel.yours.lines.isEmpty)
        #expect(viewModel.theirs.lines.count == 1)
    }

    @Test func sideTitlesReadFromTheCollectorsPointOfView() {
        #expect(TradeCalculatorViewModel.Side.yours.title == "You give")
        #expect(TradeCalculatorViewModel.Side.theirs.title == "You get")
    }
}
