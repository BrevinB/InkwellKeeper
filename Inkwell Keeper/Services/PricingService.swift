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
        case ximilar
        case priceCharting
        case tcgPlayer
        case eBayAverage
        case estimation
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
        let cacheKey = "\(card.id)_\(condition.rawValue)"

        // Check cache first
        if let cached = pricingCache[cacheKey] {
            let cacheAge = Date().timeIntervalSince(cached.cachedAt)
            if cacheAge < cacheExpirationMinutes * 60 {
                return cached.pricing
            } else {
            }
        }

        // Try multiple providers in order of preference
        // Lorcana Prices API provides real-time Cardmarket data (most accurate for Lorcana)
        // eBay provides actual sold listings as a fallback
        let providers: [PricingProvider] = [.inkwellAPI, .lorcanaAPI, .eBayAverage, .tcgPlayer, .ximilar, .priceCharting]

        var rateLimitHit = false

        for provider in providers {
            do {
                let pricing = try await fetchPricing(for: card, condition: condition, provider: provider)

                // Cache the successful result
                pricingCache[cacheKey] = (pricing, Date())

                return pricing
            } catch PricingError.rateLimitExceeded(let resetTime) {
                print("[Pricing] \(provider) rate limited for \(card.name)")
                rateLimitHit = true
                continue
            } catch {
                print("[Pricing] \(provider) failed for \(card.name): \(error)")
                continue
            }
        }

        // If all providers fail, return estimated pricing
        let uniqueId = buildUniqueId(for: card)
        print("[Pricing] All providers failed for \(card.name) (uniqueId: \(uniqueId), cardNumber: \(card.cardNumber ?? -1), id: \(card.id)) — using estimation")

        let estimatedPricing = generateEstimatedPricing(for: card, condition: condition)

        // Cache the estimation too (shorter duration)
        pricingCache[cacheKey] = (estimatedPricing, Date().addingTimeInterval(-50 * 60)) // Cache for 10 min only

        return estimatedPricing
    }
    
    func getMarketPrice(for card: LorcanaCard, condition: CardCondition = .nearMint) async -> Double? {
        do {
            guard let pricing = try await getPricing(for: card, condition: condition) else {
                return estimatePrice(for: card)
            }

            // Prefer prices matching the user's preferred currency
            let preferred = PricingService.preferredCurrency
            let preferredPrices = pricing.prices.filter { $0.currency == preferred && $0.condition == condition }
            let relevantPrices = preferredPrices.isEmpty ? pricing.prices.filter { $0.condition == condition } : preferredPrices

            guard !relevantPrices.isEmpty else {
                // If no prices for specific condition, use all preferred-currency prices or all prices
                let allPreferred = pricing.prices.filter { $0.currency == preferred }
                let allPrices = allPreferred.isEmpty ? pricing.prices : allPreferred
                let averagePrice = allPrices.map { $0.price }.reduce(0, +) / Double(allPrices.count)
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

            // Prefer prices matching the user's preferred currency
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

            if allPrices.isEmpty {
                return (estimatePrice(for: card), .estimated)
            }

            let averagePrice = allPrices.map { $0.price }.reduce(0, +) / Double(allPrices.count)
            let confidence: PriceConfidence

            // Determine confidence based on source first, then data quality
            switch pricing.source {
            case .estimation:
                // Pure estimation
                confidence = .estimated

            case .inkwellAPI:
                // Inkwell Keeper Backend — pre-cached, aggregated prices
                confidence = .high

            case .lorcanaAPI:
                // Lorcana Prices API - real-time Cardmarket data, highest confidence
                confidence = .high

            case .eBayAverage:
                // eBay sold listings - high confidence
                if allPrices.count >= 5 {
                    confidence = .high
                } else if allPrices.count >= 2 {
                    confidence = .medium
                } else {
                    confidence = .low
                }

            case .tcgPlayer:
                // TCGPlayer data (scraped or API)
                // Web scraping typically returns 1 price, but it's from a real marketplace
                if allPrices.count >= 3 {
                    confidence = .high
                } else {
                    confidence = .medium  // At least medium since it's real marketplace data
                }

            case .ximilar, .priceCharting:
                // Other providers - medium confidence
                confidence = .medium
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
            case .high: return "Based on multiple recent sales"
            case .medium: return "Based on marketplace data"
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
        case .inkwellAPI:
            return try await fetchInkwellAPIPricing(for: card, condition: condition)
        case .lorcanaAPI:
            return try await fetchLorcanaAPIPricing(for: card, condition: condition)
        case .ximilar:
            return try await fetchXimilarPricing(for: card, condition: condition)
        case .eBayAverage:
            return try await fetcheBayAveragePricing(for: card, condition: condition)
        case .tcgPlayer:
            return try await fetchTCGPlayerPricing(for: card, condition: condition)
        case .priceCharting:
            return try await fetchPriceChartingPricing(for: card, condition: condition)
        case .estimation:
            // Estimation is handled separately in getPricing, not as a provider
            return generateEstimatedPricing(for: card, condition: condition)
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
        "Fabled": "FAB",
        "Reign of Jafar": "ROJ",
        "Whispers in the Well": "WIW",
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

            return buildLorcanaAPIPricing(from: matched, card: card, condition: condition)

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

    private func buildLorcanaAPIPricing(from apiCard: LorcanaAPICard, card: LorcanaCard, condition: CardCondition) -> CardPricing {
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

        if prices.isEmpty {
        } else {
        }

        guard !prices.isEmpty else {
            // Card exists in API but has no pricing data yet
            let estimatedPrice = estimatePrice(for: card)
            return CardPricing(
                cardName: card.name,
                prices: [PriceData(
                    price: estimatedPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "Estimated (no market data)",
                    url: nil,
                    confidence: 0.6
                )],
                lastUpdated: Date(),
                source: .estimation
            )
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

        do {
            let (data, response) = try await session.data(from: url)

            let ebayResponse = try JSONDecoder().decode(EbayResponse.self, from: data)

            // Check for error response first
            if let errorMessages = ebayResponse.errorMessage,
               let firstError = errorMessages.first?.error.first {
                let errorId = firstError.errorId.first ?? "unknown"
                let errorMsg = firstError.message.first ?? "Unknown error"

                // Check if it's a rate limit error (error ID 10001)
                if errorId == "10001" {
                    throw PricingError.rateLimitExceeded(resetTime: nil)
                }

                throw PricingError.invalidResponse
            }

            guard let findCompletedResponse = ebayResponse.findCompletedItemsResponse,
                  let searchResult = findCompletedResponse.first,
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

        } catch let decodingError as DecodingError {
            throw PricingError.invalidResponse
        } catch {
            throw error
        }
    }
    
    private func getEbayAPIKey() -> String? {
        // eBay Finding API requires an App ID from eBay Developers Program
        // Production App ID for live eBay data
        let ebayAppID = "BrevinBl-DealScou-PRD-b118c3532-0162bb8b"

        return ebayAppID
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
        // Try official API first, fall back to web scraping if not configured
        if let publicKey = getTCGPlayerPublicKey(),
           let privateKey = getTCGPlayerPrivateKey() {
            return try await fetchTCGPlayerAPIPricing(for: card, condition: condition, publicKey: publicKey, privateKey: privateKey)
        } else {
            return try await fetchTCGPlayerWebPrice(for: card, condition: condition)
        }
    }

    private func getTCGPlayerPublicKey() -> String? {
        // TODO: Add your TCGPlayer Public Key here
        // Get it from https://developer.tcgplayer.com/apps
        return nil
    }

    private func getTCGPlayerPrivateKey() -> String? {
        // TODO: Add your TCGPlayer Private Key here
        // Get it from https://developer.tcgplayer.com/apps
        return nil
    }

    // TCGPlayer API Bearer Token cache
    private var tcgPlayerBearerToken: (token: String, expiresAt: Date)?

    private func getTCGPlayerBearerToken(publicKey: String, privateKey: String) async throws -> String {
        // Check if we have a valid cached token
        if let cached = tcgPlayerBearerToken,
           cached.expiresAt > Date() {
            return cached.token
        }

        // Request new bearer token
        let tokenURL = URL(string: "https://api.tcgplayer.com/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = "grant_type=client_credentials&client_id=\(publicKey)&client_secret=\(privateKey)"
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PricingError.invalidResponse
        }

        struct TokenResponse: Codable {
            let access_token: String
            let expires_in: Int
            let token_type: String
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Cache the token (expires_in is in seconds, usually 2 weeks)
        let expiresAt = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in - 300)) // 5 min buffer
        tcgPlayerBearerToken = (tokenResponse.access_token, expiresAt)

        return tokenResponse.access_token
    }

    // MARK: - TCGPlayer API Models
    struct TCGProductSearchResponse: Codable {
        let results: [TCGProduct]
        let totalItems: Int
    }

    struct TCGProduct: Codable {
        let productId: Int
        let name: String
        let cleanName: String
        let imageUrl: String?
        let categoryId: Int
        let groupId: Int
        let url: String?
        let modifiedOn: String?
    }

    struct TCGPricingResponse: Codable {
        let results: [TCGPricing]
    }

    struct TCGPricing: Codable {
        let productId: Int
        let lowPrice: Double?
        let midPrice: Double?
        let highPrice: Double?
        let marketPrice: Double?
        let directLowPrice: Double?
        let subTypeName: String
    }

    private func fetchTCGPlayerAPIPricing(for card: LorcanaCard, condition: CardCondition, publicKey: String, privateKey: String) async throws -> CardPricing {
        // Step 1: Get bearer token
        let bearerToken = try await getTCGPlayerBearerToken(publicKey: publicKey, privateKey: privateKey)

        // Step 2: Search for the card by name
        let searchQuery = "\(card.name)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = URL(string: "https://api.tcgplayer.com/catalog/products?categoryId=28&productName=\(searchQuery)&limit=10")!

        var searchRequest = URLRequest(url: searchURL)
        searchRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        searchRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (searchData, searchResponse) = try await session.data(for: searchRequest)

        guard let httpResponse = searchResponse as? HTTPURLResponse else {
            throw PricingError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Token expired, clear cache and retry
            tcgPlayerBearerToken = nil
            throw PricingError.apiKeyRequired
        }

        guard httpResponse.statusCode == 200 else {
            throw PricingError.invalidResponse
        }

        let searchResult = try JSONDecoder().decode(TCGProductSearchResponse.self, from: searchData)

        guard let product = searchResult.results.first else {
            throw PricingError.noDataFound
        }

        // Step 3: Get pricing for the product
        let priceURL = URL(string: "https://api.tcgplayer.com/pricing/product/\(product.productId)")!

        var priceRequest = URLRequest(url: priceURL)
        priceRequest.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        priceRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        let (priceData, priceResponse) = try await session.data(for: priceRequest)

        guard let pricingHttpResponse = priceResponse as? HTTPURLResponse,
              pricingHttpResponse.statusCode == 200 else {
            throw PricingError.invalidResponse
        }

        let pricingResult = try JSONDecoder().decode(TCGPricingResponse.self, from: priceData)

        // Filter pricing data based on condition (Normal vs Foil)
        let isCardFoil = card.variant == .foil
        let relevantPricing = pricingResult.results.filter { pricing in
            if isCardFoil {
                return pricing.subTypeName.lowercased().contains("foil")
            } else {
                return pricing.subTypeName.lowercased() == "normal"
            }
        }

        guard !relevantPricing.isEmpty else {
            // If no exact match, use all pricing data
            let allPricing = pricingResult.results
            guard !allPricing.isEmpty else {
                throw PricingError.noDataFound
            }

            return buildPricingResponse(from: allPricing, card: card, condition: condition, product: product)
        }

        return buildPricingResponse(from: relevantPricing, card: card, condition: condition, product: product)
    }

    private func buildPricingResponse(from pricingData: [TCGPricing], card: LorcanaCard, condition: CardCondition, product: TCGProduct) -> CardPricing {
        // Extract prices from TCGPricing objects
        var prices: [PriceData] = []

        for tcgPricing in pricingData {
            // Use market price as primary, fall back to mid price
            if let marketPrice = tcgPricing.marketPrice, marketPrice > 0 {
                prices.append(PriceData(
                    price: marketPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "TCGPlayer (Market)",
                    url: product.url,
                    confidence: 0.95
                ))
            }

            if let midPrice = tcgPricing.midPrice, midPrice > 0 {
                prices.append(PriceData(
                    price: midPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "TCGPlayer (Mid)",
                    url: product.url,
                    confidence: 0.9
                ))
            }

            if let lowPrice = tcgPricing.lowPrice, lowPrice > 0 {
                prices.append(PriceData(
                    price: lowPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "TCGPlayer (Low)",
                    url: product.url,
                    confidence: 0.85
                ))
            }
        }

        if prices.isEmpty {
            // If no prices extracted, use estimation
            let estimatedPrice = estimatePrice(for: card)
            prices.append(PriceData(
                price: estimatedPrice,
                condition: condition,
                currency: "USD",
                marketplace: "Estimated",
                url: nil,
                confidence: 0.6
            ))
        }

        return CardPricing(
            cardName: card.name,
            prices: prices,
            lastUpdated: Date(),
            source: .tcgPlayer
        )
    }
    
    private func fetchTCGPlayerWebPrice(for card: LorcanaCard, condition: CardCondition) async throws -> CardPricing {
        let searchQuery = "\(card.name) \(card.setName)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://www.tcgplayer.com/search/lorcana/product?q=\(searchQuery)"

        guard let url = URL(string: urlString) else {
            throw PricingError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        // Simple price extraction from HTML (basic implementation)
        if let htmlString = String(data: data, encoding: .utf8) {

            if let extractedPrice = extractPriceFromHTML(htmlString) {

                let priceData = PriceData(
                    price: extractedPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "TCGPlayer",
                    url: urlString,
                    confidence: 0.9
                )

                return CardPricing(
                    cardName: card.name,
                    prices: [priceData],
                    lastUpdated: Date(),
                    source: .tcgPlayer
                )
            } else {
                let estimatedPrice = estimatePrice(for: card)

                let priceData = PriceData(
                    price: estimatedPrice,
                    condition: condition,
                    currency: "USD",
                    marketplace: "Estimated (TCGPlayer unavailable)",
                    url: nil,
                    confidence: 0.6
                )

                return CardPricing(
                    cardName: card.name,
                    prices: [priceData],
                    lastUpdated: Date(),
                    source: .estimation  // Mark as estimation, not TCGPlayer!
                )
            }
        }

        throw PricingError.noDataFound
    }
    
    private func extractPriceFromHTML(_ html: String) -> Double? {
        // TCGPlayer uses JSON-LD structured data for product information
        // Look for application/ld+json script tag with price data
        if let jsonLDPrice = extractPriceFromJSONLD(html) {
            return jsonLDPrice
        }

        // Fallback: Look for market price in common TCGPlayer HTML patterns
        let marketPricePatterns = [
            #"market[- ]price[^$]*\$([0-9]+\.?[0-9]*)"#,  // "Market Price: $12.99"
            #"\"marketPrice\":([0-9]+\.?[0-9]*)"#,  // JSON: "marketPrice":12.99
            #"data-market-price=\"([0-9]+\.?[0-9]*)\""#,  // data-market-price="12.99"
            #"\"price\":\s*\"?\$?([0-9]+\.?[0-9]*)"#,  // "price": "$12.99" or "price": 12.99
        ]

        for pattern in marketPricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: html.count)),
               let priceRange = Range(match.range(at: 1), in: html) {
                let priceString = String(html[priceRange])
                if let price = Double(priceString), price > 0 {
                    return price
                }
            }
        }

        return nil
    }

    private func extractPriceFromJSONLD(_ html: String) -> Double? {
        // Look for JSON-LD structured data
        let jsonLDPattern = #"<script type=\"application/ld\+json\">(.*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: jsonLDPattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: html.count)),
              let jsonRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let jsonString = String(html[jsonRange])
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }

        // Look for offers.price or price in the JSON-LD
        if let offers = json["offers"] as? [String: Any],
           let price = offers["price"] as? Double {
            return price
        }

        if let offers = json["offers"] as? [String: Any],
           let priceString = offers["price"] as? String,
           let price = Double(priceString) {
            return price
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
            source: .estimation
        )
    }
    
    private func estimatePrice(for card: LorcanaCard) -> Double {
        // Conservative price estimation — avoid inflating cheap cards
        let basePrice = getBasePriceForRarity(card.rarity)
        let variantMultiplier = getVariantMultiplier(card.variant)
        let setMultiplier = getSetMultiplier(card.setName)

        // Only apply character/popularity/ability multipliers to rare+ cards
        // Common and uncommon cards are almost always bulk regardless of character
        let isHighRarity = card.rarity == .rare || card.rarity == .superRare ||
            card.rarity == .legendary || card.rarity == .enchanted
        let typeMultiplier = isHighRarity ? getTypeMultiplier(card.type) : 1.0
        let popularityMultiplier = isHighRarity ? getPopularityMultiplier(card.name) : 1.0
        let abilityMultiplier = isHighRarity ? getAbilityMultiplier(card) : 1.0

        let finalPrice = basePrice * variantMultiplier * setMultiplier * typeMultiplier * popularityMultiplier * abilityMultiplier

        // Apply minimum price floor
        return max(finalPrice, 0.02)
    }
    
    private func getBasePriceForRarity(_ rarity: CardRarity) -> Double {
        switch rarity {
        case .common:
            return 0.05
        case .uncommon:
            return 0.15
        case .rare:
            return 1.50
        case .superRare:
            return 6.00
        case .legendary:
            return 15.00
        case .enchanted:
            return 80.00
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
        case .epic:
            return 4.0  // Epic variants are premium special versions
        case .iconic:
            return 5.0  // Iconic variants are the rarest and most valuable
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
        let findCompletedItemsResponse: [FindCompletedItemsResponse]?
        let errorMessage: [EbayErrorMessage]?
    }

    struct EbayErrorMessage: Codable {
        let error: [EbayError]
    }

    struct EbayError: Codable {
        let errorId: [String]
        let message: [String]
        let domain: [String]?
        let severity: [String]?
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
                    return "eBay API rate limit exceeded. Resets at \(resetTime)"
                }
                return "eBay API rate limit exceeded. Try again tomorrow"
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
        case .ximilar: return "Ximilar AI"
        case .priceCharting: return "PriceCharting"
        case .tcgPlayer: return "TCGPlayer"
        case .eBayAverage: return "eBay Average"
        case .estimation: return "Estimation"
        }
    }
}
