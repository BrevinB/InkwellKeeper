//
//  CollectionManager.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import SwiftData
import Foundation
import Combine

class CollectionManager: ObservableObject {
    private var modelContext: ModelContext?
    private let pricingService = PricingService()
    
    @Published var collectedCards: [LorcanaCard] = []
    @Published var wishlistCards: [LorcanaCard] = []
    
    init() {
        // Don't load mock data - start with empty collections
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCollection()
    }
    
    func loadCollection() {
        guard let context = modelContext else { return }
        
        do {
            let collectedDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let collectedData = try context.fetch(collectedDescriptor)
            let newCollectedCards = collectedData.map { $0.toLorcanaCard }
            
            let wishlistDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == true },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let wishlistData = try context.fetch(wishlistDescriptor)
            let newWishlistCards = wishlistData.map { $0.toLorcanaCard }
            
            DispatchQueue.main.async {
                self.collectedCards = newCollectedCards
                self.wishlistCards = newWishlistCards
            }

        } catch {
            // Handle error silently
        }
    }
    
    func addCard(_ card: LorcanaCard, quantity: Int = 1) {
        guard let context = modelContext else {
            return
        }
        
        let descriptor = FetchDescriptor<CollectedCard>(
            predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
        )
        
        do {
            let existing = try context.fetch(descriptor).first
            
            if let existingCard = existing {
                existingCard.quantity += quantity
            } else {
                let newCard = CollectedCard(
                    cardId: card.id,
                    name: card.name,
                    cost: card.cost,
                    type: card.type,
                    rarity: card.rarity,
                    setName: card.setName,
                    cardText: card.cardText,
                    imageUrl: card.imageUrl,
                    price: card.price,
                    quantity: quantity,
                    variant: card.variant
                )
                context.insert(newCard)
            }

            try context.save()
            
            Task {
                await updateCardPrice(card)
            }
            
            loadCollection()

        } catch {
            // Handle error silently
        }
    }
    
    func removeCard(_ card: LorcanaCard) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CollectedCard>(
            predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
        )
        
        do {
            let cardsToDelete = try context.fetch(descriptor)
            for cardData in cardsToDelete {
                context.delete(cardData)
            }
            try context.save()
            loadCollection()
        } catch {
            // Handle error silently
        }
    }
    
    func addToWishlist(_ card: LorcanaCard) {
        guard let context = modelContext else { return }
        
        let wishlistCard = CollectedCard(
            cardId: card.id,
            name: card.name,
            cost: card.cost,
            type: card.type,
            rarity: card.rarity,
            setName: card.setName,
            cardText: card.cardText,
            imageUrl: card.imageUrl,
            price: card.price,
            quantity: 1,
            isWishlisted: true,
            variant: card.variant
        )
        
        context.insert(wishlistCard)
        
        do {
            try context.save()
            loadCollection()
        } catch {
            // Handle error silently
        }
    }
    
    func removeFromWishlist(_ card: LorcanaCard) {
        guard let context = modelContext else {
            return
        }
        
        let descriptor = FetchDescriptor<CollectedCard>(
            predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == true }
        )
        
        do {
            let cardsToDelete = try context.fetch(descriptor)

            for cardData in cardsToDelete {
                context.delete(cardData)
            }
            
            try context.save()
            loadCollection()
        } catch {
            // Handle error silently
        }
    }
    
    func getCollectionStats() -> (totalValue: Double, cardCount: Int, rarityBreakdown: [CardRarity: Int]) {
        guard let context = modelContext else { return (0, 0, [:]) }
        
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false }
            )
            let cards = try context.fetch(descriptor)
            
            let totalValue = cards.compactMap { $0.price }.reduce(0, +)
            let cardCount = cards.reduce(0) { $0 + $1.quantity }

            var rarityBreakdown: [CardRarity: Int] = [:]
            for card in cards {
                let rarity = card.cardRarity
                rarityBreakdown[rarity, default: 0] += card.quantity
            }
            
            return (totalValue, cardCount, rarityBreakdown)

        } catch {
            return (0, 0, [:])
        }
    }
    
    // Debug function to clear all data
    func clearAllData() {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<CollectedCard>()
            let allCards = try context.fetch(descriptor)
            
            for card in allCards {
                context.delete(card)
            }
            
            try context.save()
            
            DispatchQueue.main.async {
                self.collectedCards = []
                self.wishlistCards = []
            }

        } catch {
            // Handle error silently
        }
    }
    
    func getCollectedCardData(for card: LorcanaCard) -> CollectedCard? {
        guard let context = modelContext else { return nil }
        
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
            )
            return try context.fetch(descriptor).first
        } catch {
            return nil
        }
    }
    
    func updateCardQuantity(_ card: LorcanaCard, newQuantity: Int) {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
            )
            
            if let existingCard = try context.fetch(descriptor).first {
                if newQuantity <= 0 {
                    context.delete(existingCard)
                } else {
                    existingCard.quantity = newQuantity
                }
                try context.save()
                loadCollection()
            }
        } catch {
            // Handle error silently
        }
    }
    
    private func updateCardPrice(_ card: LorcanaCard) async {
        guard let context = modelContext else { return }

        do {
            let price = await pricingService.getMarketPrice(for: card)

            if let updatedPrice = price {
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> { $0.cardId == card.id }
                )

                let cardsToUpdate = try context.fetch(descriptor)
                for cardData in cardsToUpdate {
                    cardData.price = updatedPrice
                }

                try context.save()

                DispatchQueue.main.async {
                    self.loadCollection()
                }
            }
        } catch {
            // Handle error silently
        }
    }

    /// Refresh prices for all cards in collection (call manually, not on every load)
    func refreshAllPrices() async {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<CollectedCard>()

        do {
            let allCards = try context.fetch(descriptor)

            // Batch update prices (with rate limiting to avoid API throttling)
            for (index, cardData) in allCards.enumerated() {
                let card = cardData.toLorcanaCard

                // Small delay to avoid rate limiting (every 10 cards)
                if index > 0 && index % 10 == 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }

                let price = await pricingService.getMarketPrice(for: card)
                if let updatedPrice = price {
                    cardData.price = updatedPrice
                }
            }

            try context.save()

            DispatchQueue.main.async {
                self.loadCollection()
            }
        } catch {
            // Handle error silently
        }
    }
    
    func getSetProgress(_ setName: String, totalCardsInSet: Int) -> (collected: Int, total: Int, percentage: Double) {
        let dataManager = SetsDataManager.shared

        // Get all cards in this set from the data manager
        let cardsInSet = dataManager.getCardsForSet(setName)

        // Count how many we have collected
        var collectedCount = 0

        for card in cardsInSet {
            // Check if we own this specific card
            let ownedBySetName = collectedCards.contains { $0.setName == setName && $0.name == card.name }

            if ownedBySetName {
                collectedCount += 1
                continue
            }

            // If not found by set name, check if this is a reprint we own from another set
            if dataManager.isReprint(cardName: card.name) {
                // Check if we own this card from ANY set
                let ownedFromAnySet = collectedCards.contains { $0.name == card.name }
                if ownedFromAnySet {
                    collectedCount += 1
                }
            }
        }

        let percentage = totalCardsInSet > 0 ? Double(collectedCount) / Double(totalCardsInSet) * 100 : 0
        return (collected: collectedCount, total: totalCardsInSet, percentage: percentage)
    }
    
    func isCardCollected(_ cardId: String) -> Bool {
        guard let context = modelContext else { return false }

        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> { $0.cardId == cardId && $0.isWishlisted == false }
            )
            let cards = try context.fetch(descriptor)
            return !cards.isEmpty
        } catch {
            return false
        }
    }

    func isCardCollectedByName(_ cardName: String, setName: String, variant: CardVariant) -> Bool {
        guard let context = modelContext else { return false }

        let variantString = variant.rawValue
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> {
                    $0.name == cardName &&
                    $0.setName == setName &&
                    $0.variant == variantString &&
                    $0.isWishlisted == false
                }
            )
            let cards = try context.fetch(descriptor)
            return !cards.isEmpty
        } catch {
            return false
        }
    }

    /// Check if a card is collected, considering reprints from other sets
    func isCardCollectedIncludingReprints(_ card: LorcanaCard) -> Bool {
        // First check by exact card ID
        if isCardCollected(card.id) {
            return true
        }

        // If not found, check if this is a reprint and we own it from another set
        let dataManager = SetsDataManager.shared
        if dataManager.isReprint(cardName: card.name) {
            // Check if we own this card from ANY set
            return collectedCards.contains { $0.name == card.name }
        }

        return false
    }

    /// Get collected quantity for a card, considering reprints
    func getCollectedQuantityIncludingReprints(for card: LorcanaCard) -> Int {
        // First try by exact card ID
        let exactQuantity = getCollectedQuantity(for: card.id)
        if exactQuantity > 0 {
            return exactQuantity
        }

        // If not found, check reprints from other sets
        let dataManager = SetsDataManager.shared
        if dataManager.isReprint(cardName: card.name) {
            // Find any version of this card in our collection
            if let collected = collectedCards.first(where: { $0.name == card.name }) {
                return getCollectedQuantity(for: collected.id)
            }
        }

        return 0
    }

    func getCollectedQuantity(for cardId: String) -> Int {
        guard let context = modelContext else { return 0 }

        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> { $0.cardId == cardId && $0.isWishlisted == false }
            )
            let card = try context.fetch(descriptor).first
            return card?.quantity ?? 0
        } catch {
            return 0
        }
    }

    func getCollectedQuantityByName(_ cardName: String, setName: String, variant: CardVariant) -> Int {
        guard let context = modelContext else { return 0 }

        let variantString = variant.rawValue
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> {
                    $0.name == cardName &&
                    $0.setName == setName &&
                    $0.variant == variantString &&
                    $0.isWishlisted == false
                }
            )
            let card = try context.fetch(descriptor).first
            return card?.quantity ?? 0
        } catch {
            return 0
        }
    }
}

