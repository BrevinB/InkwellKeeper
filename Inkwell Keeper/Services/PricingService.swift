//
//  PricingService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/6/25.
//

import Foundation
import Combine

class PricingService: ObservableObject {
    private let session = URLSession.shared
    private var priceHistory: [String: PriceHistory] = [:]
    
    // MARK: - Pricing Providers
    enum PricingProvider: String, Codable {
        case ximilar
        case priceCharting
        case tcgPlayer
        case eBayAverage
    }
    
    // MARK: - Pricing Models
    struct CardPricing: Codable {
        let cardName: String
        let prices: [PriceData]
        let lastUpdated: Date
        let source: PricingProvider
    }
    
    struct PriceData: Codable {
        let price: Double
        let condition: CardCondition
        let currency: String
        let marketplace: String
        let url: String?
        let confidence: Double?
    }
    
    struct PriceHistory: Codable {
        let cardId: String
        let cardName: String
        var priceEntries: [PriceEntry]
    }
    
    struct PriceEntry: Codable, Identifiable {
        let id = UUID()
        let price: Double
        let condition: CardCondition
        let date: Date
        let source: PricingProvider
        
        enum CodingKeys: String, CodingKey {
            case price, condition, date, source
        }
    }
    
    enum CardCondition: String, CaseIterable, Codable {
        case nearMint = "Near Mint"
        case lightlyPlayed = "Lightly Played"
        case moderatelyPlayed = "Moderately Played"
        case heavilyPlayed = "Heavily Played"
        case damaged = "Damaged"
        case graded = "Graded"
        
        var shortName: String {
            switch self {
            case .nearMint: return "NM"
            case .lightlyPlayed: return "LP"
            case .moderatelyPlayed: return "MP"
            case .heavilyPlayed: return "HP"
            case .damaged: return "DMG"
            case .graded: return "GRADED"
            }
        }
    }
    
    // MARK: - Public Methods
    func getPricing(for card: LorcanaCard, condition: CardCondition = .nearMint) async throws -> CardPricing? {
        // Try multiple providers in order of preference
        let providers: [PricingProvider] = [.ximilar, .eBayAverage, .tcgPlayer, .priceCharting]
        
        for provider in providers {
            do {
                let pricing = try await fetchPricing(for: card, condition: condition, provider: provider)
                return pricing
            } catch {
                continue
            }
        }
        
        // If all providers fail, return estimated pricing
        return generateEstimatedPricing(for: card, condition: condition)
    }
    
    func getMarketPrice(for card: LorcanaCard, condition: CardCondition = .nearMint) async -> Double? {
        do {
            guard let pricing = try await getPricing(for: card, condition: condition) else {
                return estimatePrice(for: card)
            }
            
            // Calculate average price for the requested condition
            let relevantPrices = pricing.prices.filter { $0.condition == condition }
            guard !relevantPrices.isEmpty else {
                // If no prices for specific condition, use all prices
                let averagePrice = pricing.prices.map { $0.price }.reduce(0, +) / Double(pricing.prices.count)
                trackPrice(for: card, price: averagePrice, condition: condition, source: pricing.source)
                return averagePrice
            }
            
            let averagePrice = relevantPrices.map { $0.price }.reduce(0, +) / Double(relevantPrices.count)
            
            // Track the price for historical purposes
            trackPrice(for: card, price: averagePrice, condition: condition, source: pricing.source)
            
            return averagePrice
            
        } catch {
            let estimatedPrice = estimatePrice(for: card)
            return estimatedPrice
        }
    }
    
    // Enhanced price display with confidence indicator
    func getPriceWithConfidence(for card: LorcanaCard, condition: CardCondition = .nearMint) async -> (price: Double, confidence: PriceConfidence) {
        do {
            guard let pricing = try await getPricing(for: card, condition: condition) else {
                return (estimatePrice(for: card), .estimated)
            }
            
            let relevantPrices = pricing.prices.filter { $0.condition == condition }
            let allPrices = relevantPrices.isEmpty ? pricing.prices : relevantPrices
            
            if allPrices.isEmpty {
                return (estimatePrice(for: card), .estimated)
            }
            
            let averagePrice = allPrices.map { $0.price }.reduce(0, +) / Double(allPrices.count)
            let confidence: PriceConfidence
            
            if allPrices.count >= 5 {
                confidence = .high
            } else if allPrices.count >= 2 {
                confidence = .medium
            } else {
                confidence = .low
            }
            
            trackPrice(for: card, price: averagePrice, condition: condition, source: pricing.source)
            return (averagePrice, confidence)
            
        } catch {
            let estimatedPrice = estimatePrice(for: card)
            return (estimatedPrice, .estimated)
        }
    }
    
    enum PriceConfidence: String, CaseIterable {
        case high = "High"
        case medium = "Medium" 
        case low = "Low"
        case estimated = "Estimated"
        
        var description: String {
            switch self {
            case .high: return "Based on 5+ recent sales"
            case .medium: return "Based on 2-4 recent sales"
            case .low: return "Based on limited sales data"
            case .estimated: return "Algorithmic estimation"
            }
        }
        
        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "orange"
            case .low: return "red"
            case .estimated: return "gray"
            }
        }
    }
    
    // MARK: - Private Methods
    private func fetchPricing(for card: LorcanaCard, condition: CardCondition, provider: PricingProvider) async throws -> CardPricing {
        switch provider {
        case .ximilar:
            return try await fetchXimilarPricing(for: card, condition: condition)
        case .eBayAverage:
            return try await fetcheBayAveragePricing(for: card, condition: condition)
        case .tcgPlayer:
            return try await fetchTCGPlayerPricing(for: card, condition: condition)
        case .priceCharting:
            return try await fetchPriceChartingPricing(for: card, condition: condition)
        }
    }
    
    private func fetchXimilarPricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        // Implementation for Ximilar API
        // This would require API key and proper endpoint
        throw PricingError.providerNotImplemented
    }
    
    private func fetcheBayAveragePricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        // eBay API implementation
        guard let apiKey = getEbayAPIKey() else {
            throw PricingError.apiKeyRequired
        }
        
        let searchQuery = "\(card.name) Lorcana \(card.setName) \(condition.rawValue)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // eBay Finding API endpoint for sold listings
        let urlString = "https://svcs.ebay.com/services/search/FindingService/v1" +
                       "?OPERATION-NAME=findCompletedItems" +
                       "&SERVICE-VERSION=1.0.0" +
                       "&SECURITY-APPNAME=\(apiKey)" +
                       "&RESPONSE-DATA-FORMAT=JSON" +
                       "&keywords=\(encodedQuery)" +
                       "&categoryId=183454" + // Trading Cards category
                       "&itemFilter(0).name=SoldItemsOnly" +
                       "&itemFilter(0).value=true" +
                       "&itemFilter(1).name=Condition" +
                       "&itemFilter(1).value=\(getEbayConditionValue(condition))" +
                       "&sortOrder=EndTimeSoonest" +
                       "&paginationInput.entriesPerPage=20"
        
        guard let url = URL(string: urlString) else {
            throw PricingError.invalidResponse
        }
        
        let (data, _) = try await session.data(from: url)
        let ebayResponse = try JSONDecoder().decode(EbayResponse.self, from: data)
        
        guard let searchResult = ebayResponse.findCompletedItemsResponse.first,
              let items = searchResult.searchResult.first?.item,
              !items.isEmpty else {
            throw PricingError.noDataFound
        }
        
        let priceData = items.compactMap { item -> PriceData? in
            guard let sellingStatus = item.sellingStatus?.first,
                  let currentPrice = sellingStatus.currentPrice?.first,
                  let priceString = currentPrice.value,
                  let price = Double(priceString) else { return nil }
            
            return PriceData(
                price: price,
                condition: condition,
                currency: "USD",
                marketplace: "eBay",
                url: item.viewItemURL?.first,
                confidence: 0.9
            )
        }
        
        return CardPricing(
            cardName: card.name,
            prices: priceData,
            lastUpdated: Date(),
            source: .eBayAverage
        )
    }
    
    private func getEbayAPIKey() -> String? {
        // eBay Finding API requires an App ID from eBay Developers Program
        // Get yours at: https://developer.ebay.com/my/keys
        // TODO: Replace with your eBay App ID after joining eBay Partner Network
        let ebayAppID = "YOUR_EBAY_APP_ID"

        return ebayAppID.contains("YOUR_") ? nil : ebayAppID
    }
    
    private func getEbayConditionValue(_ condition: CardCondition) -> String {
        switch condition {
        case .nearMint: return "New"
        case .lightlyPlayed: return "Used"
        case .moderatelyPlayed: return "Used"
        case .heavilyPlayed: return "For parts or not working"
        case .damaged: return "For parts or not working"
        case .graded: return "New"
        }
    }
    
    private func fetchTCGPlayerPricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        // Simple TCGPlayer price scraping fallback (when API not available)
        return try await fetchTCGPlayerWebPrice(for: card, condition: condition)
    }
    
    private func fetchTCGPlayerWebPrice(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        let searchQuery = "\(card.name) \(card.setName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.tcgplayer.com/search/lorcana/product?q=\(searchQuery)"
        
        guard let url = URL(string: urlString) else {
            throw PricingError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        
        // Simple price extraction from HTML (basic implementation)
        if let htmlString = String(data: data, encoding: .utf8) {
            let estimatedPrice = extractPriceFromHTML(htmlString) ?? estimatePrice(for: card)
            
            let priceData = PriceData(
                price: estimatedPrice,
                condition: condition,
                currency: "USD",
                marketplace: "TCGPlayer",
                url: urlString,
                confidence: 0.7
            )
            
            return CardPricing(
                cardName: card.name,
                prices: [priceData],
                lastUpdated: Date(),
                source: .tcgPlayer
            )
        }
        
        throw PricingError.noDataFound
    }
    
    private func extractPriceFromHTML(_ html: String) -> Double? {
        // Basic regex to find price patterns like $12.99
        let pricePattern = #"\$([0-9]+\.?[0-9]*)"#
        let regex = try? NSRegularExpression(pattern: pricePattern)
        let range = NSRange(location: 0, length: html.count)
        
        if let match = regex?.firstMatch(in: html, range: range),
           let priceRange = Range(match.range(at: 1), in: html) {
            let priceString = String(html[priceRange])
            return Double(priceString)
        }
        
        return nil
    }
    
    private func fetchPriceChartingPricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        // Implementation for PriceCharting API (requires subscription)
        throw PricingError.providerNotImplemented
    }
    
    private func generateEstimatedPricing(for card: LorcanaCard, condition: CardCondition) -> CardPricing {
        let estimatedPrice = estimatePrice(for: card)
        let priceData = PriceData(
            price: estimatedPrice,
            condition: condition,
            currency: "USD",
            marketplace: "Estimated",
            url: nil,
            confidence: 0.6
        )
        
        return CardPricing(
            cardName: card.name,
            prices: [priceData],
            lastUpdated: Date(),
            source: .eBayAverage
        )
    }
    
    private func estimatePrice(for card: LorcanaCard) -> Double {
        // Enhanced price estimation with variant support
        let basePrice = getBasePriceForRarity(card.rarity)
        let variantMultiplier = getVariantMultiplier(card.variant)
        let setMultiplier = getSetMultiplier(card.setName)
        let typeMultiplier = getTypeMultiplier(card.type)
        let popularityMultiplier = getPopularityMultiplier(card.name)
        let abilityMultiplier = getAbilityMultiplier(card)
        
        let finalPrice = basePrice * variantMultiplier * setMultiplier * typeMultiplier * popularityMultiplier * abilityMultiplier
        
        // Apply minimum price floor
        return max(finalPrice, 0.10)
    }
    
    private func getBasePriceForRarity(_ rarity: CardRarity) -> Double {
        switch rarity {
        case .common:
            return 0.25
        case .uncommon:
            return 0.65
        case .rare:
            return 3.25
        case .superRare:
            return 11.50
        case .legendary:
            return 24.00
        case .enchanted:
            return 125.00  // Increased base for enchanted
        }
    }
    
    private func getVariantMultiplier(_ variant: CardVariant) -> Double {
        switch variant {
        case .normal:
            return 1.0
        case .foil:
            return 1.8  // Foil cards typically 80% more valuable
        case .borderless:
            return 2.2  // Borderless variants are premium
        case .promo:
            return 1.5  // Promos vary but generally higher
        case .enchanted:
            return 3.5  // Enchanted variants are significantly more valuable
        }
    }
    
    private func getSetMultiplier(_ setName: String) -> Double {
        let setLower = setName.lowercased()
        
        // Set popularity and availability affect prices
        switch setLower {
        case let s where s.contains("first chapter"):
            return 1.4  // Original set, high demand
        case let s where s.contains("rise of the floodborn"):
            return 1.2
        case let s where s.contains("into the inklands"):
            return 1.1
        case let s where s.contains("ursula"):
            return 1.0
        case let s where s.contains("shimmering skies"):
            return 0.95  // Newer sets might be lower initially
        case let s where s.contains("azurite sea"):
            return 0.9   // Newest set
        default:
            return 1.0
        }
    }
    
    private func getTypeMultiplier(_ type: String) -> Double {
        let typeLower = type.lowercased()
        
        if typeLower.contains("character") {
            return 1.3  // Characters are most popular
        } else if typeLower.contains("action") {
            return 0.85  // Actions generally less valuable
        } else if typeLower.contains("item") {
            return 0.9   // Items somewhere in between
        } else if typeLower.contains("location") {
            return 1.1   // Locations can be valuable for gameplay
        }
        
        return 1.0
    }
    
    private func getPopularityMultiplier(_ cardName: String) -> Double {
        let nameLower = cardName.lowercased()
        
        // Tier 1 - Most popular Disney characters
        let tier1Characters = ["mickey", "elsa", "stitch", "belle", "beast", "ariel", "simba", "aladdin"]
        if tier1Characters.contains(where: { nameLower.contains($0) }) {
            return 1.6
        }
        
        // Tier 2 - Very popular characters
        let tier2Characters = ["anna", "moana", "mulan", "jasmine", "rapunzel", "maleficent", "jafar", "ursula"]
        if tier2Characters.contains(where: { nameLower.contains($0) }) {
            return 1.4
        }
        
        // Tier 3 - Popular characters
        let tier3Characters = ["tinker bell", "peter pan", "alice", "robin hood", "hercules", "merida"]
        if tier3Characters.contains(where: { nameLower.contains($0) }) {
            return 1.2
        }
        
        return 1.0
    }
    
    private func getAbilityMultiplier(_ card: LorcanaCard) -> Double {
        guard !card.cardText.isEmpty else { return 1.0 }
        
        let textLower = card.cardText.lowercased()
        var multiplier = 1.0
        
        // Powerful game mechanics increase value
        if textLower.contains("draw") && textLower.contains("card") {
            multiplier += 0.15  // Card draw is valuable
        }
        
        if textLower.contains("gain") && textLower.contains("lore") {
            multiplier += 0.2   // Lore gain is crucial
        }
        
        if textLower.contains("exert") {
            multiplier += 0.1   // Exert abilities add utility
        }
        
        if textLower.contains("damage") || textLower.contains("banish") {
            multiplier += 0.15  // Removal effects are powerful
        }
        
        if textLower.contains("shift") {
            multiplier += 0.25  // Shift is a premium mechanic
        }
        
        // High-cost cards (6+ ink) often have powerful effects
        if card.cost >= 6 {
            multiplier += 0.1
        }
        
        // High stats increase character value
        if let strength = card.strength, strength >= 4 {
            multiplier += 0.05
        }
        
        if let willpower = card.willpower, willpower >= 5 {
            multiplier += 0.05
        }
        
        if let lore = card.lore, lore >= 2 {
            multiplier += 0.1
        }
        
        return multiplier
    }
    
    // MARK: - Price Tracking Methods
    func trackPrice(for card: LorcanaCard, price: Double, condition: CardCondition, source: PricingProvider) {
        let entry = PriceEntry(
            price: price,
            condition: condition,
            date: Date(),
            source: source
        )
        
        if var history = priceHistory[card.id] {
            history.priceEntries.append(entry)
            priceHistory[card.id] = history
        } else {
            priceHistory[card.id] = PriceHistory(
                cardId: card.id,
                cardName: card.name,
                priceEntries: [entry]
            )
        }
        
    }
    
    func getPriceHistory(for card: LorcanaCard) -> PriceHistory? {
        return priceHistory[card.id]
    }
    
    func getRecentPriceChange(for card: LorcanaCard, condition: CardCondition = .nearMint) -> (current: Double?, previous: Double?, changePercent: Double?) {
        guard let history = priceHistory[card.id] else { return (nil, nil, nil) }
        
        let relevantEntries = history.priceEntries
            .filter { $0.condition == condition }
            .sorted { $0.date > $1.date }
        
        guard relevantEntries.count >= 2 else { return (relevantEntries.first?.price, nil, nil) }
        
        let current = relevantEntries[0].price
        let previous = relevantEntries[1].price
        let changePercent = ((current - previous) / previous) * 100
        
        return (current, previous, changePercent)
    }
    
    // MARK: - Collection Analytics
    
    func calculateCollectionValue(_ cards: [LorcanaCard]) async -> CollectionValue {
        var totalEstimated: Double = 0
        var totalMarket: Double = 0
        var priceConfidences: [PriceConfidence] = []
        var topCards: [(card: LorcanaCard, price: Double)] = []
        
        for card in cards {
            let (price, confidence) = await getPriceWithConfidence(for: card)
            totalEstimated += price
            totalMarket += price
            priceConfidences.append(confidence)
            topCards.append((card: card, price: price))
        }
        
        // Sort to find most valuable cards
        topCards.sort { $0.price > $1.price }
        let top5 = Array(topCards.prefix(5))
        
        // Calculate confidence distribution
        let highConfidence = priceConfidences.filter { $0 == .high }.count
        let mediumConfidence = priceConfidences.filter { $0 == .medium }.count
        let lowConfidence = priceConfidences.filter { $0 == .low }.count
        let estimated = priceConfidences.filter { $0 == .estimated }.count
        
        return CollectionValue(
            totalValue: totalMarket,
            cardCount: cards.count,
            averageValue: cards.isEmpty ? 0 : totalMarket / Double(cards.count),
            topCards: top5,
            confidenceBreakdown: ConfidenceBreakdown(
                high: highConfidence,
                medium: mediumConfidence,
                low: lowConfidence,
                estimated: estimated
            )
        )
    }
    
    struct CollectionValue {
        let totalValue: Double
        let cardCount: Int
        let averageValue: Double
        let topCards: [(card: LorcanaCard, price: Double)]
        let confidenceBreakdown: ConfidenceBreakdown
        
        var formattedTotalValue: String {
            return String(format: "$%.2f", totalValue)
        }
        
        var formattedAverageValue: String {
            return String(format: "$%.2f", averageValue)
        }
    }
    
    struct ConfidenceBreakdown {
        let high: Int
        let medium: Int
        let low: Int
        let estimated: Int
        
        var total: Int {
            return high + medium + low + estimated
        }
        
        var highPercent: Double {
            return total > 0 ? Double(high) / Double(total) * 100 : 0
        }
        
        var marketDataPercent: Double {
            return total > 0 ? Double(high + medium + low) / Double(total) * 100 : 0
        }
    }
    
    func getSetValueAnalysis(_ setName: String, cards: [LorcanaCard]) async -> SetValueAnalysis {
        let setCards = cards.filter { $0.setName == setName }
        let collectionValue = await calculateCollectionValue(setCards)
        
        // Calculate rarity breakdown
        var rarityValues: [CardRarity: Double] = [:]
        for rarity in CardRarity.allCases {
            let rarityCards = setCards.filter { $0.rarity == rarity }
            let rarityValue = await calculateCollectionValue(rarityCards)
            rarityValues[rarity] = rarityValue.totalValue
        }
        
        return SetValueAnalysis(
            setName: setName,
            totalValue: collectionValue.totalValue,
            cardCount: setCards.count,
            rarityBreakdown: rarityValues,
            topCard: collectionValue.topCards.first
        )
    }
    
    struct SetValueAnalysis {
        let setName: String
        let totalValue: Double
        let cardCount: Int
        let rarityBreakdown: [CardRarity: Double]
        let topCard: (card: LorcanaCard, price: Double)?
        
        var formattedTotalValue: String {
            return String(format: "$%.2f", totalValue)
        }
        
        var mostValuableRarity: CardRarity? {
            return rarityBreakdown.max { $0.value < $1.value }?.key
        }
    }
    
    // MARK: - Affiliate Link Generation
    func generateEbayAffiliateLink(for card: LorcanaCard, condition: CardCondition = .nearMint) -> String? {
        guard let campaignId = getEbayCampaignId() else { return nil }
        
        let searchQuery = "\(card.name) Lorcana \(card.setName) \(condition.rawValue)"
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // eBay Partner Network affiliate link
        let affiliateLink = "https://www.ebay.com/sch/i.html" +
                           "?_nkw=\(encodedQuery)" +
                           "&_sacat=183454" + // Trading Cards category
                           "&LH_Sold=1" + // Sold listings
                           "&LH_Complete=1" + // Completed listings
                           "&_pgn=1" +
                           "&campid=\(campaignId)" +
                           "&toolid=20008" // eBay Partner Network tool ID
        
        return affiliateLink
    }
    
    private func getEbayCampaignId() -> String? {
        // Your eBay Partner Network Campaign ID
        return nil // Replace with your campaign ID
    }
    
    // MARK: - eBay API Models
    struct EbayResponse: Codable {
        let findCompletedItemsResponse: [FindCompletedItemsResponse]
    }
    
    struct FindCompletedItemsResponse: Codable {
        let searchResult: [SearchResult]
    }
    
    struct SearchResult: Codable {
        let item: [EbayItem]?
    }
    
    struct EbayItem: Codable {
        let title: [String]?
        let viewItemURL: [String]?
        let sellingStatus: [SellingStatus]?
    }
    
    struct SellingStatus: Codable {
        let currentPrice: [Price]?
    }
    
    struct Price: Codable {
        let value: String?
        let currencyId: String?
    }
    
    // MARK: - Error Types
    enum PricingError: LocalizedError {
        case providerNotImplemented
        case invalidResponse
        case noDataFound
        case apiKeyRequired
        
        var errorDescription: String? {
            switch self {
            case .providerNotImplemented:
                return "Pricing provider not yet implemented"
            case .invalidResponse:
                return "Invalid response from pricing service"
            case .noDataFound:
                return "No pricing data found for this card"
            case .apiKeyRequired:
                return "API key required for this pricing service"
            }
        }
    }
}

// MARK: - Extensions
extension PricingService.PricingProvider: CustomStringConvertible {
    var description: String {
        switch self {
        case .ximilar: return "Ximilar AI"
        case .priceCharting: return "PriceCharting"
        case .tcgPlayer: return "TCGPlayer"
        case .eBayAverage: return "eBay Average"
        }
    }
}
