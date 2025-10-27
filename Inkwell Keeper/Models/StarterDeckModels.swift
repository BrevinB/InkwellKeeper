//
//  StarterDeckModels.swift
//  Inkwell Keeper
//
//  Models for importing pre-built starter decks
//

import Foundation
import SwiftUI

// MARK: - Starter Deck Card Entry
struct StarterDeckCardEntry: Codable {
    let name: String
    let quantity: Int
}

// MARK: - Starter Deck
struct StarterDeck: Identifiable, Codable {
    let id: String
    let name: String
    let setName: String
    let inkColors: [String]
    let description: String
    let format: String
    let cards: [StarterDeckCardEntry]

    var deckFormat: DeckFormat {
        DeckFormat(rawValue: format) ?? .infinityConstructed
    }

    var deckInkColors: [InkColor] {
        inkColors.compactMap { InkColor.fromString($0) }
    }

    var totalCards: Int {
        cards.reduce(0) { $0 + $1.quantity }
    }
}

// MARK: - Starter Decks Data
struct StarterDecksData: Codable {
    let version: String
    let lastUpdated: String
    let starterDecks: [StarterDeck]
}
