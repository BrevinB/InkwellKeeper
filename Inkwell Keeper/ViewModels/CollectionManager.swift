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
import CoreData

class CollectionManager: ObservableObject {
    private var modelContext: ModelContext?
    private let pricingService = PricingService.shared

    /// Observer token for CloudKit remote-change notifications.
    private var remoteChangeObserver: NSObjectProtocol?

    @Published var collectedCards: [LorcanaCard] = []
    @Published var wishlistCards: [LorcanaCard] = []
    /// Card key ("name||setName") → total owned quantity (normal + foil), for AI deck building
    @Published var collectedCardQuantities: [String: Int] = [:]

    /// Build a compound key for card quantity lookups
    static func cardKey(name: String, setName: String) -> String {
        "\(name)||\(setName)"
    }
    
    init() {
        // Don't load mock data - start with empty collections
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        wipeStaleEstimatedPricesIfNeeded(context: context)
        repairBulkAddVariantCorruptionIfNeeded(context: context)
        mergeDuplicateCollectedCards()
        loadCollection()
        startObservingRemoteChanges()
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    /// CloudKit imports changes on a background context and posts
    /// `.NSPersistentStoreRemoteChange`. Our @Published arrays are populated by manual
    /// fetches, so we re-merge + reload whenever synced data lands.
    private func startObservingRemoteChanges() {
        guard remoteChangeObserver == nil else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.mergeDuplicateCollectedCards()
                self.loadCollection()
            }
        }
    }

    /// Collapses duplicate `CollectedCard` rows that appear when two devices each insert
    /// the same physical card while offline and CloudKit later merges both. Rows are the
    /// "same card" when they share wishlist state + (uniqueId, else name||setName) +
    /// variant. Mirrors the merge logic in `performBulkAddRepair`.
    func mergeDuplicateCollectedCards() {
        guard let context = modelContext else { return }

        do {
            let all = try context.fetch(FetchDescriptor<CollectedCard>())

            var groups: [String: [CollectedCard]] = [:]
            for card in all {
                let identity = (card.uniqueId?.isEmpty == false)
                    ? card.uniqueId!
                    : "\(card.name)||\(card.setName)"
                let key = "\(card.isWishlisted)|\(identity)|\(card.variant ?? "Normal")"
                groups[key, default: []].append(card)
            }

            var didChange = false
            for (_, rows) in groups where rows.count > 1 {
                // Keep the earliest-added row; fold the rest into it.
                let sorted = rows.sorted { $0.dateAdded < $1.dateAdded }
                let survivor = sorted[0]
                for dup in sorted.dropFirst() {
                    survivor.quantity = max(survivor.quantity, dup.quantity)
                    if survivor.price == nil { survivor.price = dup.price }
                    if let extra = dup.imageAttachments, !extra.isEmpty {
                        var merged = survivor.imageAttachments ?? []
                        merged.append(contentsOf: extra)
                        survivor.imageAttachments = merged
                    }
                    context.delete(dup)
                    didChange = true
                }
            }

            if didChange {
                try context.save()
            }
        } catch {
            // Non-fatal — duplicates are cosmetic and will be retried on the next sync.
        }
    }

    /// One-time repair for a pre-fix bulk-add bug. Prior versions of "Bulk Add" in
    /// SetDetailView forced every selected card to .normal while preserving its
    /// original uniqueId. That left rows like { variant: "Normal", uniqueId: <Enchanted's> }
    /// which made the Missing filter and set-progress totals disagree, and — once the
    /// filter was fixed — let users bulk-add the special variants a second time,
    /// producing pairs of rows pointing to the same Cardmarket entry.
    ///
    /// We have to wait for SetsDataManager to finish its async load before running,
    /// otherwise the master-card lookup is empty and the repair no-ops. The v2 flag
    /// retries even for users who hit the v1 flag while master data was still loading.
    private func repairBulkAddVariantCorruptionIfNeeded(context: ModelContext) {
        let defaultsKey = "didRepairBulkAddVariants_v2"
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }

        Task { @MainActor in
            // Poll until SetsDataManager has loaded its bundled JSON, up to ~30s.
            var attempts = 0
            while SetsDataManager.shared.getAllCards().isEmpty && attempts < 60 {
                try? await Task.sleep(for: .milliseconds(500))
                attempts += 1
            }
            guard !SetsDataManager.shared.getAllCards().isEmpty else { return }

            performBulkAddRepair(context: context)
            UserDefaults.standard.set(true, forKey: defaultsKey)
        }
    }

    @MainActor
    private func performBulkAddRepair(context: ModelContext) {
        let masterSpecialVariants: [String: CardVariant] = {
            var map: [String: CardVariant] = [:]
            for card in SetsDataManager.shared.getAllCards() {
                guard let uid = card.uniqueId, !uid.isEmpty else { continue }
                switch card.variant {
                case .enchanted, .epic, .iconic, .promo, .borderless:
                    map[uid] = card.variant
                case .normal, .foil:
                    break
                }
            }
            return map
        }()
        guard !masterSpecialVariants.isEmpty else { return }

        do {
            let allCards = try context.fetch(FetchDescriptor<CollectedCard>())

            // Index existing rows by (uniqueId, variant) so we can detect collisions
            // when promoting a corrupted Normal row to its real variant.
            var existingByKey: [String: CollectedCard] = [:]
            for card in allCards {
                guard let uid = card.uniqueId, !uid.isEmpty else { continue }
                existingByKey["\(uid)|\(card.cardVariant.rawValue)"] = card
            }

            var changed = 0
            for record in allCards {
                guard record.cardVariant == .normal,
                      let uid = record.uniqueId, !uid.isEmpty,
                      let correctVariant = masterSpecialVariants[uid] else { continue }

                let targetKey = "\(uid)|\(correctVariant.rawValue)"
                if let collision = existingByKey[targetKey], collision !== record {
                    // A legit row at the correct variant already exists — the corrupted
                    // row is a duplicate of the same physical card. Keep the larger
                    // quantity (the user almost certainly only owns 1) and delete the
                    // corrupted row.
                    collision.quantity = max(collision.quantity, record.quantity)
                    if collision.price == nil, let recordPrice = record.price {
                        collision.price = recordPrice
                    }
                    context.delete(record)
                } else {
                    record.cardVariant = correctVariant
                    existingByKey[targetKey] = record
                }
                changed += 1
            }

            if changed > 0 {
                try context.save()
                updateCollectedCardsInPlace()
            }
        } catch {
            // Non-fatal — the underlying bug is already fixed in code, so new bulk-adds
            // won't reintroduce the corruption.
        }
    }

    /// One-time wipe of stored CollectedCard.price values that may have been written
    /// as algorithmic estimates by prior versions of the app. Future refreshes will
    /// repopulate prices only with real market data.
    private func wipeStaleEstimatedPricesIfNeeded(context: ModelContext) {
        let defaultsKey = "didWipeEstimatedPrices_v3"
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }

        do {
            let descriptor = FetchDescriptor<CollectedCard>()
            let cards = try context.fetch(descriptor)
            for card in cards where card.price != nil {
                card.price = nil
            }
            try context.save()
            UserDefaults.standard.set(true, forKey: defaultsKey)
        } catch {
            // Migration failure is non-fatal — prices will continue to be replaced
            // organically as users refresh.
        }
    }

    /// Lightweight refresh of collected cards only (avoids full 3-fetch reload)
    private func updateCollectedCardsInPlace() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let collectedData = try context.fetch(descriptor)
            self.collectedCards = collectedData.map { $0.toLorcanaCard }

            var quantities: [String: Int] = [:]
            for card in collectedData {
                let variant = CardVariant(rawValue: card.variant ?? "Normal") ?? .normal
                if variant == .normal || variant == .foil {
                    let key = CollectionManager.cardKey(name: card.name, setName: card.setName)
                    quantities[key, default: 0] += card.quantity
                }
            }
            self.collectedCardQuantities = quantities
        } catch {
            // Fall back to full reload on error
            loadCollection()
        }
    }

    /// Lightweight refresh of wishlist cards only
    private func updateWishlistCardsInPlace() {
        guard let context = modelContext else { return }
        do {
            let descriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == true },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let wishlistData = try context.fetch(descriptor)
            self.wishlistCards = wishlistData.map { $0.toLorcanaCard }
        } catch {
            loadCollection()
        }
    }

    /// Save any pending changes to the model context
    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
        } catch {
            // Handle error silently
        }
    }
    
    func loadCollection() {
        guard let context = modelContext else {
            return
        }

        do {
            // Fetch all cards (no predicate) first to see total count
            let allDescriptor = FetchDescriptor<CollectedCard>()
            let allCards = try context.fetch(allDescriptor)

            let collectedDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == false },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let collectedData = try context.fetch(collectedDescriptor)
            let newCollectedCards = collectedData.map { $0.toLorcanaCard }

            // Build card key (name+set) → total owned quantity (normal + foil only)
            var quantities: [String: Int] = [:]
            for card in collectedData {
                let variant = CardVariant(rawValue: card.variant ?? "Normal") ?? .normal
                if variant == .normal || variant == .foil {
                    let key = CollectionManager.cardKey(name: card.name, setName: card.setName)
                    quantities[key, default: 0] += card.quantity
                }
            }
            let newQuantities = quantities

            let wishlistDescriptor = FetchDescriptor<CollectedCard>(
                predicate: #Predicate { $0.isWishlisted == true },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            let wishlistData = try context.fetch(wishlistDescriptor)
            let newWishlistCards = wishlistData.map { $0.toLorcanaCard }

            self.collectedCards = newCollectedCards
            self.wishlistCards = newWishlistCards
            self.collectedCardQuantities = newQuantities

        } catch {
            // Handle error silently
        }
    }
    
    func addCard(_ card: LorcanaCard, quantity: Int = 1, imageAttachments: [Data]? = nil) {
        guard let context = modelContext else {
            return
        }

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
                existingCard.dateAdded = Date()
                // Append new image attachments to existing ones
                if let newImages = imageAttachments, !newImages.isEmpty {
                    var currentImages = existingCard.imageAttachments ?? []
                    currentImages.append(contentsOf: newImages)
                    existingCard.imageAttachments = currentImages
                }
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
                if let newImages = imageAttachments, !newImages.isEmpty {
                    newCard.imageAttachments = newImages
                }
                context.insert(newCard)
            }

            try context.save()

        } catch {
            // Handle error silently
        }

        // Targeted in-memory update instead of full reload
        updateCollectedCardsInPlace()

        // Track milestone for review prompt
        ReviewManager.shared.recordCardAdded(totalCardCount: collectedCards.count)

        // Update price on main actor to safely access ModelContext
        Task { @MainActor in
            await updateCardPrice(card)
        }
    }
    
    /// Attach images to an existing collected card
    func attachImages(_ images: [Data], to card: LorcanaCard) {
        guard !images.isEmpty,
              let collected = getCollectedCardDataForVariant(card) else { return }
        var current = collected.imageAttachments ?? []
        current.append(contentsOf: images)
        collected.imageAttachments = current
        saveContext()
    }

    func removeCard(_ card: LorcanaCard) {
        guard let context = modelContext else { return }

        do {
            let cardsToDelete: [CollectedCard]
            if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                let variantString = card.variant.rawValue
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.uniqueId == uniqueId &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                cardsToDelete = try context.fetch(descriptor)
            } else {
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
                )
                cardsToDelete = try context.fetch(descriptor)
            }

            for cardData in cardsToDelete {
                context.delete(cardData)
            }
            try context.save()
            updateCollectedCardsInPlace()
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
            updateWishlistCardsInPlace()
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
            updateWishlistCardsInPlace()
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

            self.collectedCards = []
            self.wishlistCards = []

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

            self.collectedCards = []
            self.wishlistCards = []
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

    /// Fetches a collected card matching a specific variant (Normal vs Foil treated separately).
    func getCollectedCardDataForVariant(_ card: LorcanaCard) -> CollectedCard? {
        guard let context = modelContext else { return nil }

        let variantString = card.variant.rawValue

        do {
            if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.uniqueId == uniqueId &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                return try context.fetch(descriptor).first
            } else {
                let cardName = card.name
                let setName = card.setName
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> {
                        $0.name == cardName &&
                        $0.setName == setName &&
                        $0.variant == variantString &&
                        $0.isWishlisted == false
                    }
                )
                return try context.fetch(descriptor).first
            }
        } catch {
            return nil
        }
    }

    func updateCardQuantity(_ card: LorcanaCard, newQuantity: Int) {
        guard let context = modelContext else { return }

        do {
            // Find the card using the same matching logic as addCard
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
                // Fallback to cardId matching
                let descriptor = FetchDescriptor<CollectedCard>(
                    predicate: #Predicate<CollectedCard> { $0.cardId == card.id && $0.isWishlisted == false }
                )
                existing = try context.fetch(descriptor).first
            }

            if let existingCard = existing {
                if newQuantity <= 0 {
                    context.delete(existingCard)
                } else {
                    existingCard.quantity = newQuantity
                }
                try context.save()
                updateCollectedCardsInPlace()
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
                updateCollectedCardsInPlace()
            }
        } catch {
            // Handle error silently
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
                    try? await Task.sleep(for: .seconds(1))
                }

                let price = await pricingService.getMarketPrice(for: card)
                cardData.price = price
            }

            try context.save()
            loadCollection()
        } catch {
            // Handle error silently
        }
    }
    
    func getSetProgress(_ setName: String, totalCardsInSet: Int) -> (collected: Int, total: Int, percentage: Double) {
        let dataManager = SetsDataManager.shared
        let cardsInSet = dataManager.getCardsForSet(setName)

        // Pre-build O(1) lookup sets from collected cards
        var ownedSpecialKeys = Set<String>()
        var ownedNormalKeys = Set<String>()

        for collected in collectedCards {
            let isSpecial = collected.variant == .enchanted ||
                            collected.variant == .epic ||
                            collected.variant == .iconic ||
                            collected.variant == .promo

            if isSpecial {
                if let uniqueId = collected.uniqueId, !uniqueId.isEmpty {
                    ownedSpecialKeys.insert(uniqueId)
                } else {
                    ownedSpecialKeys.insert("\(collected.name)||\(collected.setName)||\(collected.variant.rawValue)")
                }
            } else {
                ownedNormalKeys.insert("\(collected.name)||\(collected.setName)")
            }
        }

        var collectedCount = 0
        for card in cardsInSet {
            let isSpecial = card.variant == .enchanted ||
                            card.variant == .epic ||
                            card.variant == .iconic ||
                            card.variant == .promo

            let isOwned: Bool
            if isSpecial {
                if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
                    isOwned = ownedSpecialKeys.contains(uniqueId)
                } else {
                    isOwned = ownedSpecialKeys.contains("\(card.name)||\(card.setName)||\(card.variant.rawValue)")
                }
            } else {
                isOwned = ownedNormalKeys.contains("\(card.name)||\(card.setName)")
            }

            if isOwned {
                collectedCount += 1
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

    /// Check if a card is collected (matches by name + set)
    func isCardCollectedIncludingReprints(_ card: LorcanaCard) -> Bool {
        // Check by exact card ID first
        if isCardCollected(card.id) {
            return true
        }

        // Fall back to name + set match
        return collectedCards.contains { $0.name == card.name && $0.setName == card.setName }
    }

    /// Get collected quantity for a card (matches by name + set)
    func getCollectedQuantityIncludingReprints(for card: LorcanaCard) -> Int {
        // First try by exact card ID
        let exactQuantity = getCollectedQuantity(for: card.id)
        if exactQuantity > 0 {
            return exactQuantity
        }

        // Fall back to name + set match
        if let collected = collectedCards.first(where: { $0.name == card.name && $0.setName == card.setName }) {
            return getCollectedQuantity(for: collected.id)
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

    // MARK: - Deck Allocation Tracking

    /// Represents how many copies of a card are used in a specific deck
    struct DeckAllocation {
        let deckName: String
        let quantity: Int
    }

    /// Get all deck allocations for a card (which decks use it and how many copies)
    func getDeckAllocations(for card: LorcanaCard) -> [DeckAllocation] {
        guard let context = modelContext else { return [] }

        do {
            let cardName = card.name
            let cardSetName = card.setName
            let descriptor = FetchDescriptor<DeckCard>(
                predicate: #Predicate<DeckCard> { $0.name == cardName && $0.setName == cardSetName }
            )
            let deckCards = try context.fetch(descriptor)

            return deckCards.compactMap { deckCard in
                guard let deck = deckCard.deck else { return nil }
                return DeckAllocation(deckName: deck.name, quantity: deckCard.quantity)
            }
        } catch {
            return []
        }
    }

    /// Get total quantity of a card allocated across all decks
    func getTotalDeckAllocation(for card: LorcanaCard) -> Int {
        return getDeckAllocations(for: card).reduce(0) { $0 + $1.quantity }
    }

    /// Get the number of copies available (not in any deck)
    func getAvailableQuantity(for card: LorcanaCard) -> Int {
        let owned: Int
        let isSpecialVariant = card.variant == .enchanted || card.variant == .epic ||
                               card.variant == .iconic || card.variant == .promo
        if isSpecialVariant {
            owned = getCollectedQuantityByName(card.name, setName: card.setName, variant: card.variant)
        } else {
            owned = getTotalQuantityAcrossVariants(uniqueId: card.uniqueId, cardName: card.name, setName: card.setName)
        }
        let allocated = getTotalDeckAllocation(for: card)
        return max(0, owned - allocated)
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

