//
//  DeckToolsTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the opening-hand simulator and the AI swap-suggestion parser.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct DeckToolsTests {
    private func makeDeckCards(uniqueCards: Int, copiesEach: Int) -> [DeckCard] {
        (0..<uniqueCards).map { index in
            DeckCard(
                from: LorcanaCard(
                    id: "TST_\(index)",
                    name: "Card \(index)",
                    cost: (index % 7) + 1,
                    type: "Character",
                    rarity: .common,
                    setName: "The First Chapter",
                    imageUrl: "https://example.com/\(index).png",
                    inkwell: index.isMultiple(of: 2)
                ),
                quantity: copiesEach
            )
        }
    }

    // MARK: - Opening hand simulator

    @Test func dealsSevenAndTracksRemainingDeck() {
        let simulator = OpeningHandSimulator(deckCards: makeDeckCards(uniqueCards: 15, copiesEach: 4))
        #expect(simulator != nil)
        #expect(simulator?.hand.count == 7)
        #expect(simulator?.remainingDeck.count == 53)
        #expect(simulator?.hasMulliganed == false)
    }

    @Test func refusesDecksSmallerThanAHand() {
        #expect(OpeningHandSimulator(deckCards: makeDeckCards(uniqueCards: 3, copiesEach: 2)) == nil)
    }

    @Test func mulliganReplacesSelectedAndKeepsDeckSize() {
        var simulator = OpeningHandSimulator(deckCards: makeDeckCards(uniqueCards: 15, copiesEach: 4))!
        let kept = [simulator.hand[3], simulator.hand[4], simulator.hand[5], simulator.hand[6]]

        simulator.mulligan(indices: [0, 1, 2])

        #expect(simulator.hand.count == 7)
        #expect(simulator.remainingDeck.count == 53)
        #expect(simulator.hasMulliganed)
        // The four unselected cards survive the alteration.
        for card in kept {
            #expect(simulator.hand.contains { $0.id == card.id })
        }
    }

    @Test func onlyOneMulliganPerHand() {
        var simulator = OpeningHandSimulator(deckCards: makeDeckCards(uniqueCards: 15, copiesEach: 4))!
        simulator.mulligan(indices: [0])
        let handAfterFirst = simulator.hand.map { $0.id }

        simulator.mulligan(indices: [0, 1])

        #expect(simulator.hand.map { $0.id } == handAfterFirst)
    }

    @Test func newHandResetsMulligan() {
        var simulator = OpeningHandSimulator(deckCards: makeDeckCards(uniqueCards: 15, copiesEach: 4))!
        simulator.mulligan(indices: [0])
        simulator.drawNewHand()
        #expect(simulator.hasMulliganed == false)
        #expect(simulator.hand.count == 7)
    }

    // MARK: - Swap parsing

    @Test func parsesSwapPairs() {
        let response = """
        The deck lacks card draw.
        [SWAPS]
        OUT: 2x Slow Card
        IN: 2x Better Card
        OUT: 1x Weak Character - Subtitle
        IN: 1x Strong Character - Subtitle (Fabled)
        [/SWAPS]
        """
        let swaps = AIDeckService.parseSwaps(from: response)

        #expect(swaps.count == 2)
        #expect(swaps[0].outName == "Slow Card")
        #expect(swaps[0].outQuantity == 2)
        #expect(swaps[0].inName == "Better Card")
        #expect(swaps[1].inName == "Strong Character - Subtitle")
        #expect(swaps[1].inQuantity == 1)
    }

    @Test func ignoresUnpairedAndMalformedLines() {
        let response = """
        [SWAPS]
        IN: 2x Orphan In Line
        OUT: 2x Has No Partner
        OUT: 1x Real Out
        IN: 1x Real In
        Nonsense line
        [/SWAPS]
        """
        let swaps = AIDeckService.parseSwaps(from: response)

        #expect(swaps.count == 1)
        #expect(swaps[0].outName == "Real Out")
        #expect(swaps[0].inName == "Real In")
    }

    @Test func parsesSwapsWithoutMarkersAsFallback() {
        let response = "OUT: 3x Old\nIN: 3x New"
        let swaps = AIDeckService.parseSwaps(from: response)
        #expect(swaps.count == 1)
        #expect(swaps[0].outQuantity == 3)
    }
}
