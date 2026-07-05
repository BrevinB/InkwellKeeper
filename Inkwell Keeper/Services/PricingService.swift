//
//  PricingService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/6/25.
//

import Foundation
import Combine

class PricingService: ObservableObject {
    static let shared = PricingService()

    static func formatPrice(_ value: Double) -> String {
        let currency = UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"
        let symbol = currency == "EUR" ? "€" : "$"
        return String(format: "%@%.2f", symbol, value)
    }

    static var preferredCurrency: String {
        UserDefaults.standard.string(forKey: "preferredCurrency") ?? "USD"
    }

    private let session = URLSession.shared
    private var priceHistory: [String: PriceHistory] = [:]
    private var pricingCache: [String: (pricing: CardPricing, cachedAt: Date)] = [:]
    private let cacheExpirationMinutes: TimeInterval = 60 // Cache for 1 hour

    private init() {
    }
    
    // MARK: - Pricing Providers
    enum PricingProvider: String, Codable {
        case inkwellAPI
        case lorcanaAPI
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

    /// Fetch real market pricing for a card. Returns nil when no provider has data —
    /// callers MUST treat nil as "price unavailable" and never substitute an estimate.
    func getPricing(for card: LorcanaCard, condition: CardCondition = .nearMint) async throws -> CardPricing? {
        let cacheKey = "\(card.id)_\(condition.rawValue)"

        if let cached = pricingCache[cacheKey] {
            let cacheAge = Date().timeIntervalSince(cached.cachedAt)
            if cacheAge < cacheExpirationMinutes * 60 {
                return cached.pricing
            }
        }

        // Inkwell backend serves pre-aggregated Cardmarket data; the Lorcana Prices API
        // is the live Cardmarket fallback when the backend doesn't have the card cached.
        let providers: [PricingProvider] = [.inkwellAPI, .lorcanaAPI]

        for provider in providers {
            do {
                let pricing = try await fetchPricing(for: card, condition: condition, provider: provider)
                pricingCache[cacheKey] = (pricing, Date())
                return pricing
            } catch PricingError.rateLimitExceeded {
                print("[Pricing] \(provider) rate limited for \(card.name)")
                continue
            } catch {
                print("[Pricing] \(provider) failed for \(card.name): \(error)")
                continue
            }
        }

        let uniqueId = buildUniqueId(for: card)
        print("[Pricing] No market data for \(card.name) (uniqueId: \(uniqueId))")
        return nil
    }
    
    /// Fetch the market average price for a card. Returns nil when no provider has data.
    func getMarketPrice(for card: LorcanaCard, condition: CardCondition = .nearMint) async -> Double? {
        do {
            guard let pricing = try await getPricing(for: card, condition: condition),
                  !pricing.prices.isEmpty else {
                return nil
            }

            let preferred = PricingService.preferredCurrency
            let preferredPrices = pricing.prices.filter { $0.currency == preferred && $0.condition == condition }
            let relevantPrices: [PriceData]
            if !preferredPrices.isEmpty {
                relevantPrices = preferredPrices
            } else {
                let conditionPrices = pricing.prices.filter { $0.condition == condition }
                if !conditionPrices.isEmpty {
                    relevantPrices = conditionPrices
                } else {
                    let allPreferred = pricing.prices.filter { $0.currency == preferred }
                    relevantPrices = allPreferred.isEmpty ? pricing.prices : allPreferred
                }
            }

            guard !relevantPrices.isEmpty else { return nil }

            let averagePrice = relevantPrices.map(\.price).reduce(0, +) / Double(relevantPrices.count)
            trackPrice(for: card, price: averagePrice, condition: condition, source: pricing.source)
            return averagePrice
        } catch {
            return nil
        }
    }
    
    /// Fetch the market price plus a confidence rating. Returns nil when no real market data is available.
    func getPriceWithConfidence(for card: LorcanaCard, condition: CardCondition = .nearMint) async -> (price: Double, confidence: PriceConfidence)? {
        do {
            guard let pricing = try await getPricing(for: card, condition: condition) else {
                return nil
            }

            let preferred = PricingService.preferredCurrency
            let preferredConditionPrices = pricing.prices.filter { $0.currency == preferred && $0.condition == condition }
            let conditionPrices = pricing.prices.filter { $0.condition == condition }
            let preferredAllPrices = pricing.prices.filter { $0.currency == preferred }
            let allPrices: [PriceData]
            if !preferredConditionPrices.isEmpty {
                allPrices = preferredConditionPrices
            } else if !conditionPrices.isEmpty {
                allPrices = conditionPrices
            } else if !preferredAllPrices.isEmpty {
                allPrices = preferredAllPrices
            } else {
                allPrices = pricing.prices
            }

            guard !allPrices.isEmpty else { return nil }

            let averagePrice = allPrices.map(\.price).reduce(0, +) / Double(allPrices.count)
            let confidence: PriceConfidence

            switch pricing.source {
            case .inkwellAPI, .lorcanaAPI:
                confidence = .high
            }

            trackPrice(for: card, price: averagePrice, condition: condition, source: pricing.source)
            return (averagePrice, confidence)
        } catch {
            return nil
        }
    }

    enum PriceConfidence: String, CaseIterable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"

        var description: String {
            switch self {
            case .high: return "Based on multiple recent sales"
            case .medium: return "Based on marketplace data"
            case .low: return "Based on limited sales data"
            }
        }

        var color: String {
            switch self {
            case .high: return "green"
            case .medium: return "orange"
            case .low: return "red"
            }
        }
    }
    
    // MARK: - Private Methods
    private func fetchPricing(for card: LorcanaCard, condition: CardCondition, provider: PricingProvider) async throws -> CardPricing {
        switch provider {
        case .inkwellAPI:
            return try await fetchInkwellAPIPricing(for: card, condition: condition)
        case .lorcanaAPI:
            return try await fetchLorcanaAPIPricing(for: card, condition: condition)
        }
    }
    
    // MARK: - Inkwell Keeper Backend API

    private let inkwellAPIBaseURL = "https://29kwvipys3.execute-api.us-east-2.amazonaws.com"

    private struct InkwellPriceResponse: Codable {
        let uniqueId: String
        let cardName: String
        let bestPriceUsd: Double?
        let priceConfidence: String
        let prices: [InkwellPrice]

        enum CodingKeys: String, CodingKey {
            case uniqueId = "unique_id"
            case cardName = "card_name"
            case bestPriceUsd = "best_price_usd"
            case priceConfidence = "price_confidence"
            case prices
        }
    }

    private struct InkwellPrice: Codable {
        let source: String
        let priceUsd: Double?
        let priceEur: Double?
        let marketplace: String
        let condition: String
        let confidence: Double?
        let fetchedAt: String

        enum CodingKeys: String, CodingKey {
            case source
            case priceUsd = "price_usd"
            case priceEur = "price_eur"
            case marketplace
            case condition
            case confidence
            case fetchedAt = "fetched_at"
        }
    }

    private static let setCodeMap: [String: String] = [
        "The First Chapter": "TFC",
        "Rise of the Floodborn": "ROF",
        "Into the Inklands": "ITI",
        "Ursula's Return": "URR",
        "Shimmering Skies": "SSK",
        "Azurite Sea": "AZS",
        "Archazia's Island": "ARI",
        "Reign of Jafar": "ROJ",
        "Fabled": "FAB",
        "Whispers in the Well": "WIW",
        "Winterspell": "WIN",
        "Promo Set 1": "P1",
        "Promo Set 2": "P2",
        "Promo Set 3": "P3",
        "Challenge Promo": "CP",
        "D23 Collection": "D23",
        "EPCOT Festival of the Arts": "EFA",
        "Lorcana Challenge Year 3": "C2",
        "Wilds Unknown": "WU",
        "Attack of the Vine!": "AOV",
    ]

    private static func setCode(for setName: String) -> String {
        setCodeMap[setName] ?? String(setName.prefix(3)).uppercased()
    }

    private func buildUniqueId(for card: LorcanaCard) -> String {
        // Always construct from set code + card number to match backend format (e.g., "TFC-1")
        let code = PricingService.setCode(for: card.setName)
        if let cardNum = card.cardNumber {
            return "\(code)-\(cardNum)"
        }
        // Fall back to stored uniqueId, stripping any leading zeros after the dash
        if let existingId = card.uniqueId, !existingId.isEmpty {
            let parts = existingId.split(separator: "-", maxSplits: 1)
            if parts.count == 2, let num = Int(parts[1]) {
                return "\(parts[0])-\(num)"
            }
            return existingId
        }
        // Try to extract card number from generated ID format (e.g., "THE_001_N_CardName")
        let idParts = card.id.split(separator: "_")
        if idParts.count >= 2, let num = Int(idParts[1]) {
            return "\(code)-\(num)"
        }
        return "\(code)-\(card.id)"
    }

    private func fetchInkwellAPIPricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        let uniqueId = buildUniqueId(for: card)
        let urlString = "\(inkwellAPIBaseURL)/prices/\(uniqueId)"

        print("[InkwellAPI] Fetching: \(urlString)")

        guard let url = URL(string: urlString) else {
            throw PricingError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                print("[InkwellAPI] HTTP \(httpResponse.statusCode) for \(uniqueId)")
                throw PricingError.noDataFound
            }
        }

        let decoder = JSONDecoder()
        let inkwellResponse = try decoder.decode(InkwellPriceResponse.self, from: data)

        let prices: [PriceData] = inkwellResponse.prices.flatMap { p -> [PriceData] in
            let cardCondition = CardCondition(rawValue: p.condition) ?? condition
            var entries: [PriceData] = []
            if let usd = p.priceUsd {
                entries.append(PriceData(
                    price: usd,
                    condition: cardCondition,
                    currency: "USD",
                    marketplace: p.marketplace,
                    url: nil,
                    confidence: p.confidence
                ))
            }
            if let eur = p.priceEur {
                entries.append(PriceData(
                    price: eur,
                    condition: cardCondition,
                    currency: "EUR",
                    marketplace: p.marketplace,
                    url: nil,
                    confidence: p.confidence
                ))
            }
            return entries
        }

        guard !prices.isEmpty else {
            throw PricingError.noDataFound
        }

        return CardPricing(
            cardName: card.name,
            prices: prices,
            lastUpdated: Date(),
            source: .inkwellAPI
        )
    }

    // MARK: - Lorcana Prices API (Cardmarket data via RapidAPI)

    private var rapidAPIKey: String?

    private func getRapidAPIKey() async -> String? {
        if let cached = rapidAPIKey {
            return cached
        }

        do {
            let key = try await CloudKitKeyService.shared.fetchAPIKey("rapidapi")
            rapidAPIKey = key
            return key
        } catch {
            return nil
        }
    }

    private func fetchLorcanaAPIPricing(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        guard let apiKey = await getRapidAPIKey() else {
            throw PricingError.apiKeyRequired
        }

        // Build search query from card name
        let searchQuery = card.name
            .replacingOccurrences(of: " - ", with: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let urlString = "https://cardmarket-api-tcg.p.rapidapi.com/lorcana/cards?search=\(searchQuery)"

        guard let url = URL(string: urlString) else {
            throw PricingError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-rapidapi-key")
        request.setValue("cardmarket-api-tcg.p.rapidapi.com", forHTTPHeaderField: "x-rapidapi-host")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 429 {
                    throw PricingError.rateLimitExceeded(resetTime: nil)
                }

                guard httpResponse.statusCode == 200 else {
                    throw PricingError.invalidResponse
                }
            }

            // Parse the response - try array format first, then object with data array
            let cards: [LorcanaAPICard]
            if let directArray = try? JSONDecoder().decode([LorcanaAPICard].self, from: data) {
                cards = directArray
            } else if let wrappedResponse = try? JSONDecoder().decode(LorcanaAPIResponse.self, from: data) {
                cards = wrappedResponse.data
            } else {
                throw PricingError.invalidResponse
            }

            guard !cards.isEmpty else {
                throw PricingError.noDataFound
            }

            // Find the best match by comparing card name and set
            let matchedCard = findBestMatch(for: card, in: cards)

            guard let matched = matchedCard else {
                throw PricingError.noDataFound
            }

            return try buildLorcanaAPIPricing(from: matched, card: card, condition: condition)

        } catch let error as PricingError {
            throw error
        } catch {
            throw error
        }
    }

    private func findBestMatch(for card: LorcanaCard, in results: [LorcanaAPICard]) -> LorcanaAPICard? {
        let normalizedName = card.name.lowercased()
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let normalizedSet = card.setName.lowercased()

        // Score each result for relevance
        var bestMatch: (card: LorcanaAPICard, score: Int)?

        for apiCard in results {
            var score = 0
            let apiName = apiCard.name.lowercased()
                .replacingOccurrences(of: " - ", with: " ")
                .replacingOccurrences(of: "-", with: " ")

            // Exact name match is highest priority
            if apiName == normalizedName {
                score += 100
            } else if apiName.contains(normalizedName) || normalizedName.contains(apiName) {
                score += 50
            }

            // Set match
            if let episodeName = apiCard.episode?.name?.lowercased() {
                if episodeName == normalizedSet {
                    score += 30
                } else if episodeName.contains(normalizedSet) || normalizedSet.contains(episodeName) {
                    score += 15
                }
            }

            // Card number match
            if let apiNum = apiCard.card_number, let cardNum = card.cardNumber {
                let apiNumInt = Int(apiNum.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression))
                if apiNumInt == cardNum {
                    score += 20
                }
            }

            // Rarity match
            if let apiRarity = apiCard.rarity?.lowercased() {
                let cardRarity = card.rarity.rawValue.lowercased()
                if apiRarity == cardRarity {
                    score += 10
                }
            }

            if score > (bestMatch?.score ?? 0) {
                bestMatch = (apiCard, score)
            }
        }

        return bestMatch?.card
    }

    private func buildLorcanaAPIPricing(from apiCard: LorcanaAPICard, card: LorcanaCard, condition: CardCondition) throws -> CardPricing {
        var prices: [PriceData] = []

        if let cardmarketPrices = apiCard.prices?.cardmarket {
            // Near Mint price from Cardmarket
            if let nmPrice = cardmarketPrices.lowest_near_mint, nmPrice > 0 {
                // Convert EUR to approximate USD (1 EUR ~ 1.08 USD)
                let usdPrice = nmPrice * 1.08
                prices.append(PriceData(
                    price: usdPrice,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "Cardmarket (NM)",
                    url: nil,
                    confidence: 0.95
                ))

                // Also add the EUR price
                prices.append(PriceData(
                    price: nmPrice,
                    condition: .nearMint,
                    currency: "EUR",
                    marketplace: "Cardmarket (NM, EUR)",
                    url: nil,
                    confidence: 0.95
                ))
            }

            // Regional prices for additional data points
            if let dePrice = cardmarketPrices.lowest_near_mint_DE, dePrice > 0 {
                prices.append(PriceData(
                    price: dePrice * 1.08,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "Cardmarket DE",
                    url: nil,
                    confidence: 0.9
                ))
            }

            if let frPrice = cardmarketPrices.lowest_near_mint_FR, frPrice > 0 {
                prices.append(PriceData(
                    price: frPrice * 1.08,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "Cardmarket FR",
                    url: nil,
                    confidence: 0.9
                ))
            }

            if let itPrice = cardmarketPrices.lowest_near_mint_IT, itPrice > 0 {
                prices.append(PriceData(
                    price: itPrice * 1.08,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "Cardmarket IT",
                    url: nil,
                    confidence: 0.9
                ))
            }
        }

        // If we got TCGPlayer/US prices too
        if let tcgPrices = apiCard.prices?.tcgplayer {
            if let marketPrice = tcgPrices.market, marketPrice > 0 {
                prices.append(PriceData(
                    price: marketPrice,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "TCGPlayer (Market)",
                    url: nil,
                    confidence: 0.95
                ))
            }
            if let lowPrice = tcgPrices.low, lowPrice > 0 {
                prices.append(PriceData(
                    price: lowPrice,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "TCGPlayer (Low)",
                    url: nil,
                    confidence: 0.9
                ))
            }
            if let midPrice = tcgPrices.mid, midPrice > 0 {
                prices.append(PriceData(
                    price: midPrice,
                    condition: .nearMint,
                    currency: "USD",
                    marketplace: "TCGPlayer (Mid)",
                    url: nil,
                    confidence: 0.9
                ))
            }
        }

        guard !prices.isEmpty else {
            throw PricingError.noDataFound
        }

        return CardPricing(
            cardName: card.name,
            prices: prices,
            lastUpdated: Date(),
            source: .lorcanaAPI
        )
    }

    // MARK: - Lorcana Prices API Response Models

    struct LorcanaAPIResponse: Codable {
        let data: [LorcanaAPICard]
    }

    struct LorcanaAPICard: Codable {
        let id: Int?
        let name: String
        let name_numbered: String?
        let slug: String?
        let type: String?
        let card_number: String?
        let rarity: String?
        let prices: LorcanaAPIPrices?
        let episode: LorcanaAPIEpisode?
        let artist: LorcanaAPIArtist?
        let image: String?
    }

    struct LorcanaAPIPrices: Codable {
        let cardmarket: LorcanaCardmarketPrices?
        let tcgplayer: LorcanaTCGPlayerPrices?
    }

    struct LorcanaCardmarketPrices: Codable {
        let currency: String?
        let lowest_near_mint: Double?
        let lowest_near_mint_DE: Double?
        let lowest_near_mint_FR: Double?
        let lowest_near_mint_IT: Double?
    }

    struct LorcanaTCGPlayerPrices: Codable {
        let market: Double?
        let low: Double?
        let mid: Double?
        let high: Double?
    }

    struct LorcanaAPIEpisode: Codable {
        let id: Int?
        let name: String?
        let slug: String?
        let released_at: String?
    }

    struct LorcanaAPIArtist: Codable {
        let id: Int?
        let name: String?
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
        var totalMarket: Double = 0
        var pricedCount = 0
        var priceConfidences: [PriceConfidence] = []
        var topCards: [(card: LorcanaCard, price: Double)] = []

        for card in cards {
            guard let result = await getPriceWithConfidence(for: card) else { continue }
            totalMarket += result.price
            pricedCount += 1
            priceConfidences.append(result.confidence)
            topCards.append((card: card, price: result.price))
        }

        topCards.sort { $0.price > $1.price }
        let top5 = Array(topCards.prefix(5))

        let highConfidence = priceConfidences.filter { $0 == .high }.count
        let mediumConfidence = priceConfidences.filter { $0 == .medium }.count
        let lowConfidence = priceConfidences.filter { $0 == .low }.count
        let unpriced = cards.count - pricedCount

        return CollectionValue(
            totalValue: totalMarket,
            cardCount: cards.count,
            pricedCardCount: pricedCount,
            averageValue: pricedCount > 0 ? totalMarket / Double(pricedCount) : 0,
            topCards: top5,
            confidenceBreakdown: ConfidenceBreakdown(
                high: highConfidence,
                medium: mediumConfidence,
                low: lowConfidence,
                unpriced: unpriced
            )
        )
    }

    struct CollectionValue {
        let totalValue: Double
        let cardCount: Int
        let pricedCardCount: Int
        let averageValue: Double
        let topCards: [(card: LorcanaCard, price: Double)]
        let confidenceBreakdown: ConfidenceBreakdown

        var formattedTotalValue: String {
            PricingService.formatPrice(totalValue)
        }

        var formattedAverageValue: String {
            PricingService.formatPrice(averageValue)
        }
    }

    struct ConfidenceBreakdown {
        let high: Int
        let medium: Int
        let low: Int
        let unpriced: Int

        var total: Int {
            high + medium + low + unpriced
        }

        var marketDataPercent: Double {
            total > 0 ? Double(high + medium + low) / Double(total) * 100 : 0
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
    
    // MARK: - Cache Management

    func clearPricingCache() {
        pricingCache.removeAll()
    }

    func getCacheStats() -> (count: Int, oldestAge: TimeInterval?) {
        guard !pricingCache.isEmpty else {
            return (0, nil)
        }

        let now = Date()
        let oldestAge = pricingCache.values.map { now.timeIntervalSince($0.cachedAt) }.max()
        return (pricingCache.count, oldestAge)
    }

    // MARK: - Error Types
    enum PricingError: LocalizedError {
        case providerNotImplemented
        case invalidResponse
        case noDataFound
        case apiKeyRequired
        case rateLimitExceeded(resetTime: String?)

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
            case .rateLimitExceeded(let resetTime):
                if let resetTime = resetTime {
                    return "Pricing API rate limit exceeded. Resets at \(resetTime)"
                }
                return "Pricing API rate limit exceeded. Try again later"
            }
        }
    }
}

// MARK: - Extensions
extension PricingService.PricingProvider: CustomStringConvertible {
    var description: String {
        switch self {
        case .inkwellAPI: return "Inkwell Keeper Backend"
        case .lorcanaAPI: return "Lorcana Prices (Cardmarket)"
        }
    }
}
