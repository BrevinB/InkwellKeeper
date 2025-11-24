//
//  DeckManager.swift
//  Inkwell Keeper
//
//  Manages deck creation, editing, and validation
//

import SwiftUI
import Combine
import SwiftData
import Foundation

class DeckManager: ObservableObject {
    var modelContext: ModelContext?
    @Published var decks: [Deck] = []

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
        if let context = modelContext {
            loadDecks(context: context)
        }
    }

    // MARK: - Load Decks
    func loadDecks(context: ModelContext) {
        self.modelContext = context
        let descriptor = FetchDescriptor<Deck>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])

        do {
            decks = try context.fetch(descriptor)
        } catch {
            decks = []
        }
    }

    // MARK: - Create Deck
    func createDeck(
        name: String,
        description: String = "",
        format: DeckFormat = .infinityConstructed,
        inkColors: [InkColor] = [],
        archetype: DeckArchetype? = nil
    ) -> Deck {
        guard let context = modelContext else {
            return Deck(name: name)
        }

        let deck = Deck(
            name: name,
            description: description,
            format: format,
            inkColors: inkColors,
            archetype: archetype
        )

        context.insert(deck)

        do {
            try context.save()
            loadDecks(context: context)
        } catch {
            // Handle error silently
        }

        return deck
    }

    // MARK: - Delete Deck
    func deleteDeck(_ deck: Deck) {
        guard let context = modelContext else { return }

        context.delete(deck)

        do {
            try context.save()
            loadDecks(context: context)
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Update Deck
    func updateDeck(_ deck: Deck) {
        guard let context = modelContext else { return }

        deck.lastModified = Date()

        do {
            try context.save()
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Add Card to Deck
    func addCard(_ card: LorcanaCard, to deck: Deck, quantity: Int = 1) {
        guard let context = modelContext else { return }

        var cardToUpdate: DeckCard?

        // Check if card already exists in deck
        if let existingCard = deck.cards.first(where: { $0.cardId == card.id }) {
            // Increment quantity (respecting max copies)
            let newQuantity = min(existingCard.quantity + quantity, deck.deckFormat.maxCopiesPerCard)
            existingCard.quantity = newQuantity
            cardToUpdate = existingCard
        } else {
            // Add new card
            let deckCard = DeckCard(from: card, quantity: min(quantity, deck.deckFormat.maxCopiesPerCard))
            deck.cards.append(deckCard)
            context.insert(deckCard)
            cardToUpdate = deckCard
        }

        deck.lastModified = Date()

        do {
            try context.save()

            // Fetch price for the card in background
            if let deckCard = cardToUpdate {
                Task {
                    await updateCardPrice(deckCard)
                }
            }
        } catch {
            // Handle error silently
        }
    }

    // MARK: - Update Card Price
    private func updateCardPrice(_ deckCard: DeckCard) async {
        let card = deckCard.toLorcanaCard
        do {
            if let pricing = try await PricingService.shared.getPricing(for: card) {
                let averagePrice = pricing.prices.map { $0.price }.reduce(0, +) / Double(pricing.prices.count)

                await MainActor.run {
                    deckCard.price = averagePrice
                    try? modelContext?.save()
                }
            }
        } catch {
            // Pricing failed - card will remain with nil/0 price
        }
    }

    // MARK: - Remove Card from Deck
    func removeCard(_ deckCard: DeckCard, from deck: Deck) {
        guard let context = modelContext else { return }

        if let index = deck.cards.firstIndex(where: { $0.cardId == deckCard.cardId }) {
            let removedCard = deck.cards.remove(at: index)
            context.delete(removedCard)
            deck.lastModified = Date()

            do {
                try context.save()
            } catch {
                // Handle error silently
            }
        }
    }

    // MARK: - Update Card Quantity
    func updateCardQuantity(_ deckCard: DeckCard, in deck: Deck, quantity: Int) {
        guard let context = modelContext else { return }
        let maxCopies = deck.deckFormat.maxCopiesPerCard

        if quantity <= 0 {
            removeCard(deckCard, from: deck)
        } else {
            deckCard.quantity = min(quantity, maxCopies)
            deck.lastModified = Date()

            do {
                try context.save()
            } catch {
                // Handle error silently
            }
        }
    }

    // MARK: - Duplicate Deck
    func duplicateDeck(_ deck: Deck) -> Deck {
        let newDeck = createDeck(
            name: "\(deck.name) (Copy)",
            description: deck.deckDescription,
            format: deck.deckFormat,
            inkColors: deck.deckInkColors,
            archetype: deck.deckArchetype
        )

        // Copy all cards
        for deckCard in deck.cards {
            let card = deckCard.toLorcanaCard
            addCard(card, to: newDeck, quantity: deckCard.quantity)
        }

        return newDeck
    }

    // MARK: - Validate Deck
    func validateDeck(_ deck: Deck) -> DeckValidation {
        return DeckValidation.validate(deck)
    }

    // MARK: - Calculate Statistics
    func calculateStatistics(for deck: Deck, collectionManager: CollectionManager) -> DeckStatistics {
        return DeckStatistics.calculate(for: deck, collectionManager: collectionManager)
    }

    // MARK: - Export Deck
    func exportDeckList(_ deck: Deck) -> String {
        var output = ""

        // Header
        output += "Deck: \(deck.name)\n"
        output += "Format: \(deck.deckFormat.rawValue)\n"
        if !deck.deckInkColors.isEmpty {
            output += "Colors: \(deck.deckInkColors.map { $0.rawValue }.joined(separator: ", "))\n"
        }
        if let archetype = deck.deckArchetype {
            output += "Archetype: \(archetype.rawValue)\n"
        }
        output += "Cards: \(deck.totalCards)\n"
        output += "\n"

        // Group cards by cost
        let cardsByCost = Dictionary(grouping: deck.cards) { $0.cost }
        let sortedCosts = cardsByCost.keys.sorted()

        for cost in sortedCosts {
            let cards = cardsByCost[cost]!.sorted { $0.name < $1.name }
            for card in cards {
                output += "\(card.quantity)x \(card.name) (\(card.setName))\n"
            }
        }

        output += "\n"
        output += "Exported from Ink Well Keeper\n"

        return output
    }

    // MARK: - Get Missing Cards
    func getMissingCards(for deck: Deck, collectionManager: CollectionManager) -> [(card: DeckCard, needed: Int)] {
        var missing: [(card: DeckCard, needed: Int)] = []

        for deckCard in deck.cards {
            // Try ID match first, then fallback to name match
            var ownedQuantity = collectionManager.getCollectedQuantity(for: deckCard.cardId)
            if ownedQuantity == 0 {
                ownedQuantity = collectionManager.getCollectedQuantityByName(
                    deckCard.name,
                    setName: deckCard.setName,
                    variant: deckCard.cardVariant
                )
            }

            let neededQuantity = deckCard.quantity
            let missingCount = max(0, neededQuantity - ownedQuantity)

            if missingCount > 0 {
                missing.append((card: deckCard, needed: missingCount))
            }
        }

        return missing.sorted { $0.card.name < $1.card.name }
    }

    // MARK: - Update Deck Colors from Cards
    func updateDeckColorsFromCards(_ deck: Deck) {
        // Automatically detect ink colors from added cards
        var detectedColors = Set<InkColor>()

        for card in deck.cards {
            if let inkColor = card.cardInkColor {
                detectedColors.insert(inkColor)
            }
        }

        // Only update if we have 1-2 colors
        if detectedColors.count <= 2 && !detectedColors.isEmpty {
            deck.deckInkColors = Array(detectedColors).sorted { $0.rawValue < $1.rawValue }
            deck.lastModified = Date()

            if let context = modelContext {
                try? context.save()
            }
        }
    }
}
