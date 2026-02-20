//
//  AIDeckService.swift
//  Inkwell Keeper
//
//  AI-powered deck creation and completion service
//

import Foundation
import SwiftUI
import Combine

// MARK: - AI Deck Suggestion Model
struct AIDeckSuggestion: Identifiable {
    let id = UUID()
    let cardName: String
    let quantity: Int
    let reasoning: String?
    var matchedCard: LorcanaCard?
}

// MARK: - AI Deck Service
@MainActor
class AIDeckService: ObservableObject {
    static let shared = AIDeckService()

    @Published var isLoading = false
    @Published var currentStreamingContent: String = ""
    @Published var suggestions: [AIDeckSuggestion] = []
    @Published var rawResponse: String = ""
    @Published var errorMessage: String?
    @Published var availability: RulesAssistantAvailability = .checking

    private var apiKey: String?
    private let dataManager = SetsDataManager.shared

    private init() {
        checkAvailability()
    }

    // MARK: - Availability
    func checkAvailability() {
        Task {
            do {
                let key = try await CloudKitKeyService.shared.fetchAPIKey("openai")
                self.apiKey = key
                self.availability = .available
            } catch let error as CloudKitKeyError {
                switch error {
                case .noNetwork:
                    self.availability = .unavailableNoNetwork
                case .recordNotFound, .iCloudUnavailable, .unknownError:
                    self.availability = .unavailableServiceError
                }
            } catch {
                self.availability = .unavailableServiceError
            }
        }
    }

    // MARK: - System Instructions
    private let systemInstructions = """
    You are a Disney Lorcana TCG deck building expert. You help players create competitive and fun decks.

    IMPORTANT RULES:
    - A deck must contain exactly 60 cards
    - A deck can have at most 2 ink colors
    - Maximum 4 copies of any card (by full name, e.g., "Elsa - Snow Queen")
    - Cards must be inkable to go into the inkwell
    - A good deck should have 30-40% inkable cards
    - Cost curve matters: a good mix of low, mid, and high cost cards

    DECK FORMATS:
    - Core Constructed: Only sets 5+ are legal (Shimmering Skies, Azurite Sea, Fabled, Archazia's Island, Reign of Jafar, Whispers in the Well, Winterspell). Sets 1-4 (The First Chapter, Rise of the Floodborn, Into the Inklands, Ursula's Return) are BANNED.
    - Infinity Constructed: All sets are legal.

    RESPONSE FORMAT:
    You MUST respond in two parts:

    PART 1 - Strategy overview (2-3 paragraphs explaining the deck strategy, key synergies, and how to play it)

    PART 2 - Deck list in EXACTLY this format (one card per line):
    [DECKLIST]
    4x Card Full Name (Set Name)
    3x Another Card - Subtitle (Set Name)
    ...
    [/DECKLIST]

    GUIDELINES:
    - Use real Disney Lorcana card names. Be precise with full names including the subtitle after the dash.
    - Always include the set name in parentheses.
    - The deck list must add up to exactly 60 cards.
    - Prioritize cards from legal sets for the specified format.
    - Consider the meta and common strategies when building decks.
    - When completing a partial deck, analyze what's already there and fill gaps in the strategy.
    """

    // MARK: - Generate Full Deck
    func generateDeck(
        description: String,
        format: DeckFormat,
        inkColors: [InkColor],
        archetype: DeckArchetype?
    ) async {
        reset()
        isLoading = true
        errorMessage = nil

        guard let apiKey = apiKey else {
            errorMessage = "Service not available. Please try again later."
            isLoading = false
            return
        }

        var prompt = "Create a 60-card Disney Lorcana deck with the following requirements:\n"
        prompt += "- Format: \(format.rawValue)\n"

        if !inkColors.isEmpty {
            prompt += "- Ink Colors: \(inkColors.map { $0.rawValue }.joined(separator: " / "))\n"
        } else {
            prompt += "- Choose the best 2 ink colors for the strategy\n"
        }

        if let archetype = archetype {
            prompt += "- Archetype: \(archetype.rawValue)\n"
        }

        if format == .coreConstructed {
            prompt += "- IMPORTANT: Only use cards from legal sets (Sets 5+: Shimmering Skies, Azurite Sea, Fabled, Archazia's Island, Reign of Jafar, Whispers in the Well, Winterspell)\n"
        }

        prompt += "\nPlayer's description: \(description)"

        await streamCompletion(apiKey: apiKey, prompt: prompt)
    }

    // MARK: - Complete Existing Deck
    func completeDeck(
        existingCards: [DeckCard],
        format: DeckFormat,
        inkColors: [InkColor],
        archetype: DeckArchetype?,
        targetCount: Int = 60
    ) async {
        reset()
        isLoading = true
        errorMessage = nil

        guard let apiKey = apiKey else {
            errorMessage = "Service not available. Please try again later."
            isLoading = false
            return
        }

        let currentCount = existingCards.reduce(0) { $0 + $1.quantity }
        let remaining = targetCount - currentCount

        guard remaining > 0 else {
            errorMessage = "Deck already has \(currentCount) cards."
            isLoading = false
            return
        }

        var prompt = "I have a partial Disney Lorcana deck and need help completing it.\n\n"
        prompt += "Format: \(format.rawValue)\n"
        prompt += "Ink Colors: \(inkColors.map { $0.rawValue }.joined(separator: " / "))\n"

        if let archetype = archetype {
            prompt += "Archetype: \(archetype.rawValue)\n"
        }

        prompt += "Current cards (\(currentCount)/\(targetCount)):\n"
        for card in existingCards.sorted(by: { $0.cost < $1.cost }) {
            prompt += "  \(card.quantity)x \(card.name) (\(card.setName))\n"
        }

        prompt += "\nI need \(remaining) more cards to reach \(targetCount). "
        prompt += "Suggest ONLY the additional cards needed (totaling \(remaining) cards). "
        prompt += "Analyze the existing cards, identify the deck's strategy, and fill in gaps. "
        prompt += "Consider the cost curve, inkable ratio, and synergies with existing cards."

        if format == .coreConstructed {
            prompt += "\nIMPORTANT: Only suggest cards from legal sets (Sets 5+)."
        }

        await streamCompletion(apiKey: apiKey, prompt: prompt)
    }

    // MARK: - Stream Completion
    private func streamCompletion(apiKey: String, prompt: String) async {
        let messages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "system", content: systemInstructions),
            OpenAIChatMessage(role: "user", content: prompt)
        ]

        do {
            let stream = OpenAIService.shared.streamChatCompletion(
                apiKey: apiKey,
                messages: messages
            )

            for try await chunk in stream {
                currentStreamingContent += chunk
            }

            rawResponse = currentStreamingContent
            currentStreamingContent = ""
            parseSuggestions()
        } catch {
            if currentStreamingContent.isEmpty {
                errorMessage = "Failed to generate deck. Please try again."
            } else {
                rawResponse = currentStreamingContent
                currentStreamingContent = ""
                parseSuggestions()
            }
        }

        isLoading = false
    }

    // MARK: - Parse Suggestions
    private func parseSuggestions() {
        suggestions = []

        // Extract decklist block
        guard let startRange = rawResponse.range(of: "[DECKLIST]"),
              let endRange = rawResponse.range(of: "[/DECKLIST]") else {
            // Try to parse without markers as fallback
            parseFallbackSuggestions()
            return
        }

        let decklistContent = String(rawResponse[startRange.upperBound..<endRange.lowerBound])
        parseCardLines(decklistContent)
    }

    private func parseFallbackSuggestions() {
        // Try to find lines that look like "4x Card Name (Set)"
        let lines = rawResponse.components(separatedBy: "\n")
        var foundCards = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let suggestion = parseCardLine(trimmed) {
                suggestions.append(suggestion)
                foundCards = true
            }
        }

        if foundCards {
            matchCardsToDatabase()
        }
    }

    private func parseCardLines(_ content: String) {
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let suggestion = parseCardLine(trimmed) {
                suggestions.append(suggestion)
            }
        }

        matchCardsToDatabase()
    }

    private func parseCardLine(_ line: String) -> AIDeckSuggestion? {
        // Match patterns like "4x Card Name (Set Name)" or "4x Card Name - Subtitle (Set Name)"
        let pattern = #"^(\d+)x\s+(.+?)(?:\s+\((.+?)\))?\s*$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let quantityRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let quantity = Int(line[quantityRange]) ?? 0
        let cardName = String(line[nameRange]).trimmingCharacters(in: .whitespaces)

        guard quantity > 0 && !cardName.isEmpty else { return nil }

        return AIDeckSuggestion(
            cardName: cardName,
            quantity: quantity,
            reasoning: nil,
            matchedCard: nil
        )
    }

    // MARK: - Match Cards to Database
    private func matchCardsToDatabase() {
        let allCards = dataManager.getAllCards()

        for i in suggestions.indices {
            let suggestionName = suggestions[i].cardName.lowercased()
                .trimmingCharacters(in: .whitespaces)

            // Try exact match first
            if let match = allCards.first(where: {
                $0.name.lowercased() == suggestionName && $0.variant == .normal
            }) {
                suggestions[i].matchedCard = match
                continue
            }

            // Try contains match (for slight name variations)
            if let match = allCards.first(where: {
                $0.variant == .normal && (
                    $0.name.lowercased().contains(suggestionName) ||
                    suggestionName.contains($0.name.lowercased())
                )
            }) {
                suggestions[i].matchedCard = match
                continue
            }

            // Try fuzzy match - split on " - " and match both parts
            let parts = suggestionName.components(separatedBy: " - ")
            if parts.count == 2 {
                let firstName = parts[0].trimmingCharacters(in: .whitespaces)
                let subtitle = parts[1].trimmingCharacters(in: .whitespaces)

                if let match = allCards.first(where: {
                    $0.variant == .normal &&
                    $0.name.lowercased().contains(firstName) &&
                    $0.name.lowercased().contains(subtitle)
                }) {
                    suggestions[i].matchedCard = match
                }
            }
        }
    }

    // MARK: - Apply Suggestions to Deck
    func applySuggestions(to deck: Deck, deckManager: DeckManager) {
        for suggestion in suggestions {
            guard let card = suggestion.matchedCard else { continue }
            deckManager.addCard(card, to: deck, quantity: suggestion.quantity)
        }
    }

    // MARK: - Stats
    var totalSuggestedCards: Int {
        suggestions.reduce(0) { $0 + $1.quantity }
    }

    var matchedCount: Int {
        suggestions.filter { $0.matchedCard != nil }.count
    }

    var unmatchedCount: Int {
        suggestions.filter { $0.matchedCard == nil }.count
    }

    /// The strategy text portion of the response (everything before the decklist)
    var strategyText: String {
        if let range = rawResponse.range(of: "[DECKLIST]") {
            return String(rawResponse[rawResponse.startIndex..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    // MARK: - Reset
    func reset() {
        suggestions = []
        rawResponse = ""
        currentStreamingContent = ""
        errorMessage = nil
        isLoading = false
    }
}
