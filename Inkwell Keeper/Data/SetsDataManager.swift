//
//  SetsDataManager.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/14/25.
//

import Foundation
import SwiftUI
import Combine

struct LorcanaSet: Identifiable, Codable {
    let id: String
    let name: String
    let setCode: String
    let releaseDate: String?
    let cardCount: Int
    let description: String
    let isReleased: Bool
    
    var releaseDateFormatted: String {
        guard let releaseDate = releaseDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: releaseDate) else { return releaseDate }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

struct SetsData: Codable {
    let version: String
    let lastUpdated: String
    let sets: [LorcanaSet]
}

struct SetCardData: Codable {
    let setName: String
    let setCode: String
    let cardCount: Int
    let cards: [LorcanaCard]
}

class SetsDataManager: ObservableObject {
    static let shared = SetsDataManager()
    
    @Published private(set) var sets: [LorcanaSet] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isDataLoaded = false

    private var setCards: [String: [LorcanaCard]] = [:]
    private let priceCache = PriceCache.shared
    
    private init() {
        loadLocalData()
    }
    
    // MARK: - Data Loading
    
    private func loadLocalData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await loadSetsMetadata()
                try await loadAllSetCards()
                
                await MainActor.run {
                    self.isLoading = false
                    self.isDataLoaded = true
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadSetsMetadata() async throws {
        guard let url = Bundle.main.url(forResource: "sets", withExtension: "json") else {
            throw DataError.fileNotFound("sets.json")
        }
        
        let data = try Data(contentsOf: url)
        let setsData = try JSONDecoder().decode(SetsData.self, from: data)
        
        await MainActor.run {
            self.sets = setsData.sets.sorted { 
                ($0.releaseDate ?? "") < ($1.releaseDate ?? "") 
            }
        }
    }
    
    private func loadAllSetCards() async throws {
        // Map set IDs to their JSON filenames
        let setFilenames: [String: String] = [
            "the_first_chapter": "the_first_chapter.json",
            "rise_of_the_floodborn": "rise_of_the_floodborn.json",
            "into_the_inklands": "into_the_inklands.json",
            "ursulas_return": "ursulas_return.json",
            "shimmering_skies": "shimmering_skies.json",
            "azurite_sea": "azurite_sea.json",
            "fabled": "fabled.json",
            "archazias_island": "archazias_island.json",
            "reign_of_jafar": "reign_of_jafar.json",
            "whispers_in_the_well": "whispers_in_the_well.json",
            "promo_set_1": "promo_set_1.json",
            "promo_set_2": "promo_set_2.json",
            "d23_collection": "d23_collection.json",
            "challenge_promo": "challenge_promo.json"
        ]

        for (setId, filename) in setFilenames {
            do {
                let cards = try await loadSetCards(filename: filename)
                if let set = sets.first(where: { $0.id == setId }) {
                    setCards[set.name] = cards
                }
            } catch {
                // Continue loading other sets even if one fails
            }
        }

        // Prefetch images for better performance
        let allCards = setCards.values.flatMap { $0 }
        ImageCache.shared.prefetchImages(for: Array(allCards.prefix(50)))  // Prefetch first 50 for quick start
    }
    
    private func loadSetCards(filename: String) async throws -> [LorcanaCard] {
        guard let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            throw DataError.fileNotFound(filename)
        }
        
        let data = try Data(contentsOf: url)
        let setData = try JSONDecoder().decode(SetCardData.self, from: data)
        return setData.cards
    }
    
    // MARK: - Public Interface
    
    func getAllSets() -> [LorcanaSet] {
        return sets
    }
    
    func getCardsForSet(_ setName: String) -> [LorcanaCard] {
        return setCards[setName] ?? []
    }
    
    func getSet(byName name: String) -> LorcanaSet? {
        return sets.first { $0.name == name }
    }
    
    func getSet(byCode code: String) -> LorcanaSet? {
        return sets.first { $0.setCode == code }
    }
    
    func hasLocalCards(for setName: String) -> Bool {
        return setCards[setName] != nil
    }
    
    func getLocalCardCount(for setName: String) -> Int {
        return setCards[setName]?.count ?? 0
    }
    
    // MARK: - Future Update Methods
    
    func refreshPricesInBackground() {
        Task {
            await priceCache.refreshPricesForCollectedCards()
        }
    }
    
    func getCardWithCachedPrice(_ card: LorcanaCard) -> LorcanaCard {
        var updatedCard = card
        if let cachedPrice = priceCache.getPrice(for: card.id) {
            updatedCard = LorcanaCard(
                id: card.id,
                name: card.name,
                cost: card.cost,
                type: card.type,
                rarity: card.rarity,
                setName: card.setName,
                cardText: card.cardText,
                imageUrl: card.imageUrl,
                price: cachedPrice,
                variant: card.variant,
                cardNumber: card.cardNumber,
                uniqueId: card.uniqueId,
                inkwell: card.inkwell,
                strength: card.strength,
                willpower: card.willpower,
                lore: card.lore,
                franchise: card.franchise,
                inkColor: card.inkColor
            )
        }
        return updatedCard
    }
    
    // MARK: - Search Functionality

    /// Search for cards and group reprints together
    func searchCardGroups(query: String) -> [CardGroup] {
        let cards = searchCards(query: query)
        return groupCards(cards)
    }

    /// Group cards by name (for handling reprints)
    private func groupCards(_ cards: [LorcanaCard]) -> [CardGroup] {
        var grouped: [String: [LorcanaCard]] = [:]

        for card in cards {
            grouped[card.name, default: []].append(card)
        }

        return grouped.map { name, cards in
            CardGroup(
                id: name.replacingOccurrences(of: " ", with: "_"),
                name: name,
                cards: cards.sorted { ($0.setName, $0.uniqueId ?? "") > ($1.setName, $1.uniqueId ?? "") }
            )
        }.sorted { $0.name < $1.name }
    }

    func searchCards(query: String) -> [LorcanaCard] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Wait for data to load if not ready
        if !isDataLoaded {
            return []
        }

        let normalizedQuery = normalizeSearchText(query)
        var allCards: [LorcanaCard] = []

        // Collect all cards from all sets
        for cards in setCards.values {
            allCards.append(contentsOf: cards)
        }
        
        // Apply cached prices to all cards
        allCards = allCards.map { getCardWithCachedPrice($0) }

        // Filter cards based on search query
        let filteredCards = allCards.filter { card in
            let normalizedName = normalizeSearchText(card.name)
            let normalizedText = normalizeSearchText(card.cardText)
            let normalizedType = normalizeSearchText(card.type)
            let normalizedSet = normalizeSearchText(card.setName)

            return normalizedName.contains(normalizedQuery) ||
                   normalizedText.contains(normalizedQuery) ||
                   normalizedType.contains(normalizedQuery) ||
                   normalizedSet.contains(normalizedQuery) ||
                   isExactMatch(query: normalizedQuery, cardName: normalizedName)
        }

        // Sort results: exact matches first, then by name
        return filteredCards.sorted { card1, card2 in
            let name1 = normalizeSearchText(card1.name)
            let name2 = normalizeSearchText(card2.name)
            
            let exact1 = isExactMatch(query: normalizedQuery, cardName: name1)
            let exact2 = isExactMatch(query: normalizedQuery, cardName: name2)
            
            if exact1 && !exact2 { return true }
            if !exact1 && exact2 { return false }
            
            return name1 < name2
        }
    }
    
    private func normalizeSearchText(_ text: String) -> String {
        return text.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isExactMatch(query: String, cardName: String) -> Bool {
        let queryWords = query.components(separatedBy: " ").filter { !$0.isEmpty }
        let nameWords = cardName.components(separatedBy: " ").filter { !$0.isEmpty }
        
        // Check if all query words appear in the card name
        return queryWords.allSatisfy { queryWord in
            nameWords.contains { nameWord in
                nameWord.hasPrefix(queryWord) || nameWord.contains(queryWord)
            }
        }
    }
    
    func getAllCards() -> [LorcanaCard] {
        var allCards: [LorcanaCard] = []
        for cards in setCards.values {
            allCards.append(contentsOf: cards)
        }
        return allCards.map { getCardWithCachedPrice($0) }
    }

    /// Get all set names that a card (by name) appears in
    func getSetsForCard(cardName: String) -> [String] {
        var sets: Set<String> = []
        for cards in setCards.values {
            if cards.contains(where: { $0.name == cardName }) {
                if let setName = cards.first?.setName {
                    sets.insert(setName)
                }
            }
        }
        return Array(sets).sorted()
    }

    /// Check if a card name appears in multiple sets (is a reprint)
    func isReprint(cardName: String) -> Bool {
        return getSetsForCard(cardName: cardName).count > 1
    }
}

// MARK: - Price Caching System

class PriceCache: ObservableObject {
    static let shared = PriceCache()
    
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?

    private let priceService = PricingService.shared
    private let userDefaults = UserDefaults.standard
    private let pricePrefix = "price_"
    private let timestampPrefix = "price_timestamp_"
    private let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours
    
    private init() {
        loadLastRefreshDate()
    }
    
    func getPrice(for cardId: String) -> Double? {
        let priceKey = pricePrefix + cardId
        let timestampKey = timestampPrefix + cardId
        
        guard userDefaults.object(forKey: priceKey) != nil else { return nil }
        
        let price = userDefaults.double(forKey: priceKey)
        let timestamp = userDefaults.object(forKey: timestampKey) as? Date ?? Date.distantPast
        
        // Check if price is too old
        if Date().timeIntervalSince(timestamp) > maxAge {
            return nil
        }
        
        return price > 0 ? price : nil
    }
    
    func setPrice(_ price: Double, for cardId: String) {
        let priceKey = pricePrefix + cardId
        let timestampKey = timestampPrefix + cardId
        
        userDefaults.set(price, forKey: priceKey)
        userDefaults.set(Date(), forKey: timestampKey)
    }
    
    func refreshPricesForCollectedCards() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        // This would iterate through collected cards and update prices
        // Implementation depends on accessing CollectionManager
        
        await MainActor.run {
            self.isRefreshing = false
            self.lastRefresh = Date()
            self.saveLastRefreshDate()
        }
    }
    
    private func loadLastRefreshDate() {
        lastRefresh = userDefaults.object(forKey: "lastPriceRefresh") as? Date
    }
    
    private func saveLastRefreshDate() {
        if let lastRefresh = lastRefresh {
            userDefaults.set(lastRefresh, forKey: "lastPriceRefresh")
        }
    }
}

// MARK: - Error Types

enum DataError: LocalizedError {
    case fileNotFound(String)
    case invalidData(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let filename):
            return "File not found: \(filename)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}

