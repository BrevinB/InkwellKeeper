//
//  StarterDeckManager.swift
//  Inkwell Keeper
//
//  Manages loading and importing starter decks
//

import Foundation
import SwiftUI
import Combine

class StarterDeckManager: ObservableObject {
    static let shared = StarterDeckManager()

    @Published private(set) var starterDecks: [StarterDeck] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private init() {
        loadStarterDecks()
    }

    // MARK: - Load Starter Decks
    private func loadStarterDecks() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let url = Bundle.main.url(forResource: "starter_decks", withExtension: "json") else {
                    throw DataError.fileNotFound("starter_decks.json")
                }

                let data = try Data(contentsOf: url)
                let starterDecksData = try JSONDecoder().decode(StarterDecksData.self, from: data)

                await MainActor.run {
                    self.starterDecks = starterDecksData.starterDecks
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Import Starter Deck
    /// Import a starter deck into the user's deck collection
    /// Returns a tuple: (deck, unmatchedCards)
    func importStarterDeck(
        _ starterDeck: StarterDeck,
        deckManager: DeckManager,
        dataManager: SetsDataManager,
        collectionManager: CollectionManager? = nil,
        addToCollection: Bool = false
    ) -> (deck: Deck?, unmatchedCards: [String], addedToCollection: Int) {
        guard let context = deckManager.modelContext else {
            return (nil, [], 0)
        }

        // Create the deck
        let deck = deckManager.createDeck(
            name: starterDeck.name,
            description: starterDeck.description,
            format: starterDeck.deckFormat,
            inkColors: starterDeck.deckInkColors,
            archetype: nil
        )

        var unmatchedCards: [String] = []
        var addedToCollectionCount = 0

        // Add all cards from the starter deck
        for entry in starterDeck.cards {
            // Search for the card in the data manager
            let matchingCards = dataManager.searchCards(query: entry.name)

            if let matchedCard = matchingCards.first(where: { $0.name == entry.name }) {
                // Add the card to the deck
                deckManager.addCard(matchedCard, to: deck, quantity: entry.quantity)

                // Optionally add to collection
                if addToCollection, let collectionManager = collectionManager {
                    collectionManager.addCard(matchedCard, quantity: entry.quantity)
                    addedToCollectionCount += entry.quantity
                }
            } else {
                // Card not found - add to unmatched list
                unmatchedCards.append(entry.name)
            }
        }

        return (deck, unmatchedCards, addedToCollectionCount)
    }

    // MARK: - Import Cards to Collection Only
    /// Import starter deck cards to collection without creating a deck
    /// Returns a tuple: (unmatchedCards, addedCount)
    func importCardsToCollection(
        _ starterDeck: StarterDeck,
        collectionManager: CollectionManager,
        dataManager: SetsDataManager
    ) -> (unmatchedCards: [String], addedCount: Int) {
        var unmatchedCards: [String] = []
        var addedCount = 0

        // Add all cards from the starter deck to collection
        for entry in starterDeck.cards {
            // Search for the card in the data manager
            let matchingCards = dataManager.searchCards(query: entry.name)

            if let matchedCard = matchingCards.first(where: { $0.name == entry.name }) {
                collectionManager.addCard(matchedCard, quantity: entry.quantity)
                addedCount += entry.quantity
            } else {
                // Card not found - add to unmatched list
                unmatchedCards.append(entry.name)
            }
        }

        return (unmatchedCards, addedCount)
    }

    // MARK: - Get Starter Decks
    func getStarterDecks() -> [StarterDeck] {
        return starterDecks
    }

    func getStarterDeck(byId id: String) -> StarterDeck? {
        return starterDecks.first { $0.id == id }
    }

    // MARK: - Group Starter Decks by Set
    func getStarterDecksBySet() -> [String: [StarterDeck]] {
        return Dictionary(grouping: starterDecks) { $0.setName }
    }
}
