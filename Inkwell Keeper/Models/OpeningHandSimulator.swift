//
//  OpeningHandSimulator.swift
//  Inkwell Keeper
//
//  Deals sample opening hands from a deck, with Lorcana's alteration (mulligan) rule:
//  set aside any number of cards, draw that many, then shuffle the set-aside cards back.
//  Pure logic so it's unit-testable; the view drives it.
//

import Foundation

struct OpeningHandSimulator {
    static let handSize = 7

    private(set) var hand: [LorcanaCard] = []
    private(set) var remainingDeck: [LorcanaCard] = []
    /// True once the one allowed mulligan has been used for this hand.
    private(set) var hasMulliganed = false

    private let fullDeck: [LorcanaCard]

    /// Builds a simulator from a deck's cards (each card repeated by its quantity).
    /// Returns nil when the deck is too small to deal an opening hand.
    init?(deckCards: [DeckCard]) {
        var cards: [LorcanaCard] = []
        for deckCard in deckCards {
            let card = deckCard.toLorcanaCard
            cards.append(contentsOf: Array(repeating: card, count: deckCard.quantity))
        }
        guard cards.count >= Self.handSize else { return nil }
        fullDeck = cards
        drawNewHand()
    }

    /// Shuffles the full deck and deals a fresh hand. Resets the mulligan.
    mutating func drawNewHand() {
        var deck = fullDeck.shuffled()
        hand = Array(deck.prefix(Self.handSize))
        deck.removeFirst(Self.handSize)
        remainingDeck = deck
        hasMulliganed = false
    }

    /// Lorcana alteration: the selected cards are set aside, replacements are drawn, then
    /// the set-aside cards are shuffled back into the deck. One use per hand.
    mutating func mulligan(indices: Set<Int>) {
        guard !hasMulliganed, !indices.isEmpty else { return }

        let setAside = indices.sorted(by: >).compactMap { index -> LorcanaCard? in
            guard hand.indices.contains(index) else { return nil }
            return hand.remove(at: index)
        }
        guard !setAside.isEmpty else { return }

        let drawCount = min(setAside.count, remainingDeck.count)
        hand.append(contentsOf: remainingDeck.prefix(drawCount))
        remainingDeck.removeFirst(drawCount)

        remainingDeck.append(contentsOf: setAside)
        remainingDeck.shuffle()
        hasMulliganed = true
    }

    /// How many cards in the current hand can go into the inkwell.
    var inkableCount: Int {
        hand.filter { $0.inkwell == true }.count
    }
}
