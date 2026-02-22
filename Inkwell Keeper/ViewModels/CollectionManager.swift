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
    private let pricingService = PricingService.shared

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
        guard let context = modelContext else {
            print("❌ [loadCollection] modelContext is nil")
            return
        }

        do {
            // Fetch all cards (no predicate) first to see total count
            let allDescriptor = FetchDescriptor<CollectedCard>()
            let allCards = try context.fetch(allDescriptor)
            print("📊 [loadCollection] Total cards in store: \(allCards.count)")

            let collectedDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let collectedData = try context.fetch(collectedDescriptor)
            print("📊 [loadCollection] Fetched \(collectedData.count) collected, \(allCards.count - collectedData.count) wishlisted")
            let newCollectedCards = collectedData.map { $0.toLorcanaCard }

            let wishlistDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == true },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let wishlistData = try context.fetch(wishlistDescriptor)
            let newWishlistCards = wishlistData.map { $0.toLorcanaCard }

            // Update on main thread synchronously if already on main thread, otherwise async
            if Thread.isMainThread {
                self.collectedCards = newCollectedCards
                self.wishlistCards = newWishlistCards
            } else {
                DispatchQueue.main.async {
                    self.collectedCards = newCollectedCards
                    self.wishlistCards = newWishlistCards
                }
            }

        } catch {
            print("❌ [loadCollection] Fetch error: \(error)")
        }
    }
    
    func addCard(_ card: LorcanaCard, quantity: Int = 1) {
        guard let context = modelContext else {
            return
        }

        print("📝 [addCard] Saving card:")
        print("   Name: \(card.name)")
        print("   Variant: \(card.variant.rawValue)")
        print("   uniqueId: \(card.uniqueId ?? "nil")")
        print("   cardNumber: \(card.cardNumber?.description ?? "nil")")

        do {
            // Use uniqueId + variant for deduplication (more reliable than card.id which has format inconsistencies)
            let existing: CollectedCard?
            if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                let variantString = card.variant.rawValue
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.uniqueId == uniqueId &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                existing = try context.fetch(descriptor).first
            } else {
                let cardName = card.name
                let setName = card.setName
                let variantString = card.variant.rawValue
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.name == cardName &&
                        $0.setName == setName &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                existing = try context.fetch(descriptor).first
            }

            if let existingCard = existing {
                existingCard.quantity += quantity
                print("   ✅ Updated existing card quantity to \(existingCard.quantity)")
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
                    variant: card.variant,
                    inkColor: card.inkColor,
                    uniqueId: card.uniqueId,
                    cardNumber: card.cardNumber
                )
                context.insert(newCard)
                print("   ✅ Inserted new card")
            }

            try context.save()
            print("   ✅ Saved successfully")

            // Verify: count all cards in context right after save
            let verifyDescriptor = FetchDescriptor<CollectedCard>()
            if let verifyCards = try? context.fetch(verifyDescriptor) {
                print("   📊 Context now has \(verifyCards.count) total card(s) after save")
                for c in verifyCards {
                    print("     - \(c.name) | uniqueId: \(c.uniqueId ?? "nil") | wishlisted: \(c.isWishlisted)")
                }
            }

        } catch {
            print("   ❌ [addCard] Error: \(error)")
        }

        // Always reload collection regardless of save success/failure
        loadCollection()

        // Update price on main actor to safely access ModelContext
        Task { @MainActor in
            await updateCardPrice(card)
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
            variant: card.variant,
            inkColor: card.inkColor,
            uniqueId: card.uniqueId,
            cardNumber: card.cardNumber
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

    /// Delete all user data (collection, wishlist, decks, and all associated data)
    func deleteAllData() async {
        guard let context = modelContext else { return }

        do {
            // Delete all CollectedCards (collection and wishlist)
            let collectedDescriptor = FetchDescriptor<CollectedCard>()
            let allCollectedCards = try context.fetch(collectedDescriptor)
            for card in allCollectedCards {
                context.delete(card)
            }

            // Delete all Decks (DeckCards will be deleted automatically via cascade)
            let deckDescriptor = FetchDescriptor<Deck>()
            let allDecks = try context.fetch(deckDescriptor)
            for deck in allDecks {
                context.delete(deck)
            }

            // Delete all CardSets
            let setDescriptor = FetchDescriptor<CardSet>()
            let allSets = try context.fetch(setDescriptor)
            for set in allSets {
                context.delete(set)
            }

            // Delete all CollectionStats
            let statsDescriptor = FetchDescriptor<CollectionStats>()
            let allStats = try context.fetch(statsDescriptor)
            for stat in allStats {
                context.delete(stat)
            }

            // Delete all PriceHistory
            let priceHistoryDescriptor = FetchDescriptor<PriceHistory>()
            let allPriceHistory = try context.fetch(priceHistoryDescriptor)
            for history in allPriceHistory {
                context.delete(history)
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
            // Try matching by uniqueId first (most reliable)
            if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                let cardIsSpecialVariant = card.variant == .enchanted ||
                                          card.variant == .epic ||
                                          card.variant == .iconic ||
                                          card.variant == .promo

                let variantString = card.variant.rawValue

                if cardIsSpecialVariant {
                    // For special variants, match uniqueId + variant
                    let descriptor = FetchDescriptor<CollectedCard>(
                        predicate: #Predicate<CollectedCard> {
                            $0.uniqueId == uniqueId &&
                            $0.variant == variantString &&
                            $0.isWishlisted == false
                        }
                    )
                    if let found = try context.fetch(descriptor).first {
                        return found
                    }
                } else {
                    // For Normal/Foil, match uniqueId only (variant doesn't matter)
                    let descriptor = FetchDescriptor<CollectedCard>(
                        predicate: #Predicate<CollectedCard> {
                            $0.uniqueId == uniqueId &&
                            $0.isWishlisted == false
                        }
                    )
                    if let found = try context.fetch(descriptor).first {
                        return found
                    }
                }
            }

            // Fallback to name + set + variant matching
            let cardName = card.name
            let setName = card.setName
            let cardIsSpecialVariant = card.variant == .enchanted ||
                                      card.variant == .epic ||
                                      card.variant == .iconic ||
                                      card.variant == .promo

            if cardIsSpecialVariant {
                // For special variants, match name + set + variant
                let variantString = card.variant.rawValue
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.name == cardName &&
                        $0.setName == setName &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                return try context.fetch(descriptor).first
            } else {
                // For Normal/Foil, match name + set (exclude special variants)
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.name == cardName &&
                        $0.setName == setName &&
                        $0.isWishlisted == false
                    }
                )
                // Filter out special variants manually (can't do complex logic in Predicate)
                let results = try context.fetch(descriptor)
                return results.first { collected in
                    let variant = CardVariant(rawValue: collected.variant ?? "Normal") ?? .normal
                    return variant != .enchanted && variant != .epic && variant != .iconic && variant != .promo
                }
            }
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
    
    @MainActor
    private func updateCardPrice(_ card: LorcanaCard) async {
        guard let context = modelContext else { return }

        do {
            let price = await pricingService.getMarketPrice(for: card)

            if let updatedPrice = price {
                // Match by uniqueId or name+set to find the stored card
                let cardsToUpdate: [CollectedCard]
                if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                    let descriptor = FetchDescriptor<CollectedCard>(
                        predicate: #Predicate<CollectedCard> { $0.uniqueId == uniqueId }
                    )
                    cardsToUpdate = try context.fetch(descriptor)
                } else {
                    let cardName = card.name
                    let setName = card.setName
                    let descriptor = FetchDescriptor<CollectedCard>(
                        predicate: #Predicate<CollectedCard> { $0.name == cardName && $0.setName == setName }
                    )
                    cardsToUpdate = try context.fetch(descriptor)
                }

                for cardData in cardsToUpdate {
                    cardData.price = updatedPrice
                }

                try context.save()
                loadCollection()
            }
        } catch {
            print("❌ [updateCardPrice] Error: \(error)")
        }
    }

    /// Refresh prices for all cards in collection (call manually, not on every load)
    @MainActor
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
            loadCollection()
        } catch {
            print("❌ [refreshAllPrices] Error: \(error)")
        }
    }
    
    func getSetProgress(_ setName: String, totalCardsInSet: Int) -> (collected: Int, total: Int, percentage: Double) {
        let dataManager = SetsDataManager.shared

        // Get all cards in this set from the data manager
        let cardsInSet = dataManager.getCardsForSet(setName)

        print("🔍 [getSetProgress] Checking set: \(setName)")
        print("   Cards in set: \(cardsInSet.count)")
        print("   Total collected cards: \(collectedCards.count)")
        if collectedCards.count > 0 {
            print("   All collected cards:")
            for (idx, card) in collectedCards.enumerated() {
                print("     \(idx + 1). \(card.name) - \(card.setName) (\(card.variant.rawValue)) - uniqueId: \(card.uniqueId ?? "nil")")
            }
        }

        // Count how many we have collected FROM THIS SPECIFIC SET
        var collectedCount = 0

        for card in cardsInSet {
            // Check if we own this card (from ANY set, counting reprints)
            let isOwned = collectedCards.contains { collected in
                // Try matching by uniqueId first (if both have non-empty uniqueIds)
                if let cardUniqueId = card.uniqueId, let collectedUniqueId = collected.uniqueId,
                   !cardUniqueId.isEmpty, !collectedUniqueId.isEmpty {
                    // If uniqueIds match exactly, this is definitely the same card
                    if collectedUniqueId == cardUniqueId {
                        print("✅ [getSetProgress] UniqueId match: \(card.name) - uniqueId: \(cardUniqueId)")
                        return true
                    }
                    // UniqueIds don't match, but this might still be a reprint
                    // Fall through to name matching below
                }

                // Match by name across ALL sets (for reprints)
                // For Enchanted/Epic/Iconic/Promo, they are separate cards so match variant too
                // For Normal/Foil, they're the same card so ignore variant (but exclude special variants)
                let cardIsSpecialVariant = card.variant == .enchanted ||
                                          card.variant == .epic ||
                                          card.variant == .iconic ||
                                          card.variant == .promo

                let collectedIsSpecialVariant = collected.variant == .enchanted ||
                                               collected.variant == .epic ||
                                               collected.variant == .iconic ||
                                               collected.variant == .promo

                if cardIsSpecialVariant {
                    // For special variants, match name + variant (regardless of set)
                    let matched = collected.name == card.name && collected.variant == card.variant
                    if matched {
                        print("✅ [getSetProgress] Special variant match: \(card.name) (\(card.variant.rawValue))")
                    }
                    return matched
                } else {
                    // For Normal/Foil, match name only but EXCLUDE special variants
                    let matched = collected.name == card.name && !collectedIsSpecialVariant
                    if matched {
                        print("✅ [getSetProgress] Name match: \(card.name) (set: \(setName), collected from: \(collected.setName))")
                    }
                    return matched
                }
            }

            if isOwned {
                collectedCount += 1
            }
        }

        print("📊 [getSetProgress] Set: \(setName) - Collected: \(collectedCount) / \(totalCardsInSet)")

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

    /// Get collected quantity by uniqueId (more reliable for promo cards)
    func getCollectedQuantityByUniqueId(_ uniqueId: String, variant: CardVariant) -> Int {
        guard let context = modelContext else { return 0 }

        let variantString = variant.rawValue
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate<CollectedCard> {
                    $0.uniqueId == uniqueId &&
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

    /// Get total collected quantity across Normal and Foil variants only
    /// (Enchanted/Epic/Iconic are separate cards, not summed)
    func getTotalQuantityAcrossVariants(uniqueId: String?, cardName: String, setName: String) -> Int {
        guard let context = modelContext else { return 0 }

        do {
            var descriptor: FetchDescriptor<CollectedCard>

            // If uniqueId is available, match by uniqueId (for promo cards)
            if let uniqueId = uniqueId, !uniqueId.isEmpty {
                descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.uniqueId == uniqueId &&
                        $0.isWishlisted == false
                    }
                )
            } else {
                // Otherwise match by name + setName (for regular cards)
                descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.name == cardName &&
                        $0.setName == setName &&
                        $0.isWishlisted == false
                    }
                )
            }

            let cards = try context.fetch(descriptor)

            // Only sum Normal and Foil variants (Enchanted/Epic/Iconic are separate cards)
            return cards.filter { card in
                let variant = CardVariant(rawValue: card.variant ?? "Normal") ?? .normal
                return variant == .normal || variant == .foil
            }.reduce(0) { $0 + $1.quantity }
        } catch {
            return 0
        }
    }
}

