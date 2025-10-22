//
//  LorcanaAPIService.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import Foundation
import Combine


class LorcanaAPIService: ObservableObject {
    private let baseURL = "https://api.lorcana-api.com"
    private let session = URLSession.shared
    
    func searchCards(query: String) async throws -> [LorcanaCard] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // Try exact name match first with original query
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        do {
            guard let url = URL(string: "\(baseURL)/cards/fetch?strict=\(encodedQuery)") else {
                throw APIError.invalidURL
            }
            
            let (data, _) = try await session.data(from: url)
            let apiCards = try JSONDecoder().decode([APICard].self, from: data)
            
            let results = apiCards.map { apiCard in
                let variant = determineVariant(from: apiCard)
                return LorcanaCard(
                    id: "\(apiCard.Set_Name ?? "unknown")_\(apiCard.Card_Num ?? apiCard.Set_Num)_\(variant.rawValue)_\(apiCard.Name.replacingOccurrences(of: " ", with: "_"))",
                    name: apiCard.Name,
                    cost: apiCard.Cost ?? 0,
                    type: apiCard.Type ?? "Unknown",
                    rarity: CardRarity.fromString(apiCard.Rarity ?? ""),
                    setName: apiCard.Set_Name ?? "Unknown Set",
                    cardText: apiCard.Body_Text ?? "",
                    imageUrl: apiCard.Image ?? "",
                    price: nil,
                    variant: variant,
                    cardNumber: apiCard.Card_Num,
                    uniqueId: apiCard.Unique_ID
                )
            }
            
            // If we got results, return them
            if !results.isEmpty {
                return results
            }
        } catch {
            // If exact match fails, continue to fuzzy search
        }
        
        // Also try exact match with normalized query format
        let normalizedQuery = query.lowercased()
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " - ")
        
        if normalizedQuery != query {
            let encodedNormalizedQuery = normalizedQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            
            do {
                guard let url = URL(string: "\(baseURL)/cards/fetch?strict=\(encodedNormalizedQuery)") else {
                    throw APIError.invalidURL
                }
                
                let (data, _) = try await session.data(from: url)
                let apiCards = try JSONDecoder().decode([APICard].self, from: data)
                
                let results = apiCards.map { apiCard in
                    let variant = determineVariant(from: apiCard)
                    return LorcanaCard(
                        id: "\(apiCard.Set_Name ?? "unknown")_\(apiCard.Card_Num ?? apiCard.Set_Num)_\(variant.rawValue)_\(apiCard.Name.replacingOccurrences(of: " ", with: "_"))",
                        name: apiCard.Name,
                        cost: apiCard.Cost ?? 0,
                        type: apiCard.Type ?? "Unknown",
                        rarity: CardRarity.fromString(apiCard.Rarity ?? ""),
                        setName: apiCard.Set_Name ?? "Unknown Set",
                        cardText: apiCard.Body_Text ?? "",
                        imageUrl: apiCard.Image ?? "",
                        price: nil,
                        variant: variant,
                        cardNumber: apiCard.Card_Num,
                        uniqueId: apiCard.Unique_ID
                    )
                }
                
                if !results.isEmpty {
                    return results
                }
            } catch {
                // Continue to fuzzy search
            }
        }
        
        // If no exact match, try fuzzy search by getting all cards and filtering
        return try await fuzzySearch(query: query)
    }
    
    private func fuzzySearch(query: String) async throws -> [LorcanaCard] {
        let allCards = try await getAllCards()
        let normalizedQuery = normalizeSearchQuery(query)
        
        // Filter cards using multiple matching strategies
        let matchingCards = allCards.filter { card in
            let normalizedCardName = normalizeCardName(card.name)
            
            // Strategy 1: Exact match after normalization
            if normalizedCardName == normalizedQuery {
                return true
            }
            
            // Strategy 2: Contains match
            if normalizedCardName.contains(normalizedQuery) {
                return true
            }
            
            // Strategy 3: Word-based matching (all query words must be in card name)
            let queryWords = normalizedQuery.components(separatedBy: " ").filter { !$0.isEmpty }
            let cardWords = normalizedCardName.components(separatedBy: " ")
            
            let allQueryWordsPresent = queryWords.allSatisfy { queryWord in
                cardWords.contains { cardWord in
                    cardWord.contains(queryWord) || queryWord.contains(cardWord)
                }
            }
            
            return allQueryWordsPresent
        }
        
        // Group by card name and pick the first variant for each unique card
        var uniqueCardsByName: [String: LorcanaCard] = [:]
        for card in matchingCards {
            if uniqueCardsByName[card.name] == nil {
                uniqueCardsByName[card.name] = card
            }
        }
        
        // Sort by relevance
        let uniqueCards = Array(uniqueCardsByName.values)
        return uniqueCards.sorted { card1, card2 in
            let name1 = normalizeCardName(card1.name)
            let name2 = normalizeCardName(card2.name)
            
            // Exact matches first
            if name1 == normalizedQuery && name2 != normalizedQuery {
                return true
            } else if name1 != normalizedQuery && name2 == normalizedQuery {
                return false
            }
            
            // Then by how well the query matches (starts with > contains)
            let query1StartsWithQuery = name1.hasPrefix(normalizedQuery)
            let query2StartsWithQuery = name2.hasPrefix(normalizedQuery)
            
            if query1StartsWithQuery && !query2StartsWithQuery {
                return true
            } else if !query1StartsWithQuery && query2StartsWithQuery {
                return false
            }
            
            // Finally alphabetical
            return name1 < name2
        }
    }
    
    private func normalizeSearchQuery(_ query: String) -> String {
        return query.lowercased()
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func normalizeCardName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: " - ", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getCardByName(name: String) async throws -> LorcanaCard? {
        let results = try await searchCards(query: name)
        return results.first { $0.name.lowercased() == name.lowercased() }
    }
    
    func getAllCards() async throws -> [LorcanaCard] {
        guard let url = URL(string: "\(baseURL)/cards/all") else {
            throw APIError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        let apiCards = try JSONDecoder().decode([APICard].self, from: data)
        
        return apiCards.map { apiCard in
            let variant = determineVariant(from: apiCard)
            return LorcanaCard(
                id: "\(apiCard.Set_Name ?? "unknown")_\(apiCard.Card_Num ?? apiCard.Set_Num)_\(variant.rawValue)_\(apiCard.Name.replacingOccurrences(of: " ", with: "_"))",
                name: apiCard.Name,
                cost: apiCard.Cost ?? 0,
                type: apiCard.Type ?? "Unknown",
                rarity: CardRarity.fromString(apiCard.Rarity ?? ""),
                setName: apiCard.Set_Name ?? "Unknown Set",
                cardText: apiCard.Body_Text ?? "",
                imageUrl: apiCard.Image ?? "",
                price: nil,
                variant: variant,
                cardNumber: apiCard.Card_Num,
                uniqueId: apiCard.Unique_ID
            )
        }
    }
    
    func getRandomCards(count: Int = 10) async throws -> [LorcanaCard] {
        let allCards = try await getAllCards()
        return Array(allCards.shuffled().prefix(count))
    }
    
    private func determineVariant(from apiCard: APICard) -> CardVariant {
        let rarity = apiCard.Rarity?.lowercased() ?? ""
        let name = apiCard.Name.lowercased()
        let classifications = apiCard.Classifications?.lowercased() ?? ""
        
        // Use heuristics to determine variant based on available data
        if rarity.contains("enchanted") || name.contains("enchanted") {
            return .enchanted
        } else if rarity.contains("super rare") && (name.contains("promo") || classifications.contains("promo")) {
            return .promo
        } else if rarity.contains("super rare") || rarity.contains("legendary") {
            // High rarity cards could be borderless variants
            return .borderless
        } else {
            // For now, default everything else to normal
            // In a real app, you'd want better logic here based on more API data
            return .normal
        }
    }
}

// MARK: - API Models
extension LorcanaAPIService {
    struct APICard: Codable {
        let Name: String
        let Set_Num: Int
        let Card_Num: Int?
        let Unique_ID: String?
        let Cost: Int?
        let `Type`: String?
        let Rarity: String?
        let Set_Name: String?
        let Body_Text: String?
        let Image: String?
        let Classifications: String?
        let Flavor_Text: String?
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case noData
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .decodingError:
                return "Failed to decode response"
            }
        }
    }
}

// MARK: - CardRarity Extension
extension CardRarity {
    static func fromString(_ string: String) -> CardRarity {
        switch string.lowercased() {
        case "common":
            return .common
        case "uncommon":
            return .uncommon
        case "rare":
            return .rare
        case "super rare":
            return .superRare
        case "legendary":
            return .legendary
        case "enchanted":
            return .enchanted
        default:
            return .common
        }
    }
}
