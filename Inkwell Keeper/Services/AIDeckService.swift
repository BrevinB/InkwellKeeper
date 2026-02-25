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
struct AIDeckSuggestion: Identifiable, Hashable {
    let id = UUID()
    let cardName: String
    let quantity: Int
    let reasoning: String?
    var matchedCard: LorcanaCard?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: AIDeckSuggestion, rhs: AIDeckSuggestion) -> Bool {
        lhs.id == rhs.id
    }
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
    @Published var colorConstraintNote: String?
    @Published var availability: RulesAssistantAvailability = .checking

    private var apiKey: String?
    private let dataManager = SetsDataManager.shared
    private var currentCollectionOnly = false
    private var currentOwnedCardQuantities: [String: Int] = [:]

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
    - A deck MUST have exactly 1 or 2 ink colors. NEVER use cards from 3 or more ink colors.
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

    CRITICAL CARD NAME RULES:
    - You will be given a list of AVAILABLE CARDS. You MUST copy card names EXACTLY, character-for-character, from that list.
    - Do NOT paraphrase, shorten, reword, or invent card names. If a card is listed as "Elsa - Snow Queen" you must write exactly "Elsa - Snow Queen", not "Elsa - The Snow Queen" or "Elsa - Ice Queen".
    - Do NOT combine a character's first name with a subtitle from a different card. Each "Name - Subtitle" pair is a unique card.
    - If you are unsure whether a card exists, do NOT include it. Only use cards you can see in the provided list.
    - The deck list must add up to exactly 60 cards.
    - When completing a partial deck, analyze what's already there and fill gaps in the strategy.
    """

    // MARK: - Generate Full Deck
    func generateDeck(
        description: String,
        format: DeckFormat,
        inkColors: [InkColor],
        archetype: DeckArchetype?,
        collectionOnly: Bool = false,
        ownedCardQuantities: [String: Int] = [:]
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
        prompt += buildCardCatalog(format: format, inkColors: inkColors, collectionOnly: collectionOnly, ownedCardQuantities: ownedCardQuantities)

        await streamCompletion(apiKey: apiKey, prompt: prompt, collectionOnly: collectionOnly, ownedCardQuantities: ownedCardQuantities)
    }

    // MARK: - Complete Existing Deck
    func completeDeck(
        existingCards: [DeckCard],
        format: DeckFormat,
        inkColors: [InkColor],
        archetype: DeckArchetype?,
        targetCount: Int = 60,
        collectionOnly: Bool = false,
        ownedCardQuantities: [String: Int] = [:]
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

        // Detect actual ink colors from existing cards if deck metadata colors are empty
        var effectiveColors = inkColors
        if effectiveColors.isEmpty {
            let detectedColors = Set(existingCards.compactMap { $0.inkColor })
            effectiveColors = detectedColors.compactMap { InkColor.fromString($0) }
        }

        var prompt = "I have a partial Disney Lorcana deck and need help completing it.\n\n"
        prompt += "Format: \(format.rawValue)\n"
        prompt += "Ink Colors: \(effectiveColors.map { $0.rawValue }.joined(separator: " / "))\n"
        prompt += "IMPORTANT: Only suggest cards that match these ink colors (\(effectiveColors.map { $0.rawValue }.joined(separator: " / "))). Do NOT add cards from other colors.\n"

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

        prompt += buildCardCatalog(format: format, inkColors: effectiveColors, collectionOnly: collectionOnly, ownedCardQuantities: ownedCardQuantities)

        await streamCompletion(apiKey: apiKey, prompt: prompt, collectionOnly: collectionOnly, ownedCardQuantities: ownedCardQuantities)
    }

    // MARK: - Generate Strategy for Existing Deck
    func generateStrategy(for deck: Deck) async {
        reset()
        isLoading = true
        errorMessage = nil

        guard let apiKey = apiKey else {
            errorMessage = "Service not available. Please try again later."
            isLoading = false
            return
        }

        let strategySystemPrompt = """
        You are a Disney Lorcana TCG strategy expert. You analyze decks and provide detailed play guides.

        When given a deck list, provide a thorough strategy guide covering:
        1. **Deck Overview** — What the deck is trying to do and its win condition
        2. **Key Cards & Combos** — The most important cards and how they work together
        3. **Mulligan Guide** — What to look for in your opening hand and what to send back
        4. **Early Game (Turns 1-3)** — What to prioritize in the opening turns, which cards to ink
        5. **Mid Game (Turns 4-6)** — How to transition and build your board
        6. **Late Game (Turn 7+)** — How to close out the game
        7. **Cards to Ink** — Which cards are best to put in the inkwell and which to always play
        8. **Weaknesses & Tips** — What the deck struggles against and how to play around it

        Use markdown formatting with bold headers. Be specific — reference actual card names from the deck.
        """

        var prompt = "Analyze this Disney Lorcana deck and provide a detailed strategy guide.\n\n"
        prompt += "Deck: \(deck.name)\n"
        prompt += "Format: \(deck.deckFormat.rawValue)\n"
        prompt += "Ink Colors: \(deck.deckInkColors.map { $0.rawValue }.joined(separator: " / "))\n"
        if let archetype = deck.deckArchetype {
            prompt += "Archetype: \(archetype.rawValue)\n"
        }
        prompt += "\nDeck List (\(deck.totalCards) cards):\n"
        for card in deck.cards.sorted(by: { $0.cost < $1.cost }) {
            prompt += "  \(card.quantity)x \(card.name) (Cost \(card.cost), \(card.type), \(card.inkColor ?? "Unknown"))\n"
        }

        let messages: [OpenAIChatMessage] = [
            OpenAIChatMessage(role: "system", content: strategySystemPrompt),
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
        } catch {
            if currentStreamingContent.isEmpty {
                errorMessage = "Failed to generate strategy. Please try again."
            } else {
                rawResponse = currentStreamingContent
                currentStreamingContent = ""
            }
        }

        isLoading = false
    }

    // MARK: - Build Card Catalog for AI Prompt
    private func buildCardCatalog(format: DeckFormat, inkColors: [InkColor], collectionOnly: Bool = false, ownedCardQuantities: [String: Int] = [:]) -> String {
        let legalSetNames: Set<String>
        if format == .coreConstructed {
            legalSetNames = ["Shimmering Skies", "Azurite Sea", "Fabled", "Archazia's Island", "Reign of Jafar", "Whispers in the Well", "Winterspell"]
        } else {
            legalSetNames = Set(dataManager.getAllCards().map { $0.setName })
        }

        var filteredCards = dataManager.getAllCards().filter {
            $0.variant == .normal && legalSetNames.contains($0.setName)
        }

        // Deduplicate cards by name (same card can appear in multiple sets)
        var seen = Set<String>()
        var uniqueCards: [LorcanaCard] = []
        for card in filteredCards.sorted(by: { $0.name < $1.name }) {
            if seen.insert(card.name).inserted {
                uniqueCards.append(card)
            }
        }
        filteredCards = uniqueCards

        // Filter to only owned cards when collection-only mode is active
        if collectionOnly && !ownedCardQuantities.isEmpty {
            filteredCards = filteredCards.filter { ownedCardQuantities[$0.name] != nil }
        }

        if !inkColors.isEmpty {
            // Colors specified: filter to only those colors
            let colorNames = Set(inkColors.map { $0.rawValue })
            filteredCards = filteredCards.filter { card in
                guard let inkColor = card.inkColor else { return false }
                return colorNames.contains(inkColor)
            }
            guard !filteredCards.isEmpty else { return "" }

            var catalog = "\n\nCRITICAL: ONLY use card names from the list below. Copy each name EXACTLY as written — do not modify, shorten, or invent names. Every card in your [DECKLIST] MUST appear in this list.\n"
            if collectionOnly && !ownedCardQuantities.isEmpty {
                catalog += "IMPORTANT: The number before each card is how many copies the player OWNS. You MUST NOT suggest more copies than the player owns. For example, if a card shows \"1x\", you can only use 1 copy in the deck.\n"
            }
            catalog += "AVAILABLE CARDS:\n"
            for card in filteredCards.sorted(by: { $0.name < $1.name }) {
                if collectionOnly, let qty = ownedCardQuantities[card.name] {
                    catalog += "- \(qty)x \(card.name)\n"
                } else {
                    catalog += "- \(card.name)\n"
                }
            }
            return catalog
        } else {
            // No colors specified: group by ink color so the AI clearly sees 2 choices to make
            guard !filteredCards.isEmpty else { return "" }

            var catalog = "\n\nCRITICAL RULE: You MUST choose EXACTLY 2 ink color sections below and use cards ONLY from those 2 sections. Every single card in your [DECKLIST] must come from the same 2 colors. Do NOT use cards from any other color section.\nCopy each card name EXACTLY as written — do not modify, shorten, or invent names. Every card in your [DECKLIST] MUST appear in this list.\n"
            if collectionOnly && !ownedCardQuantities.isEmpty {
                catalog += "IMPORTANT: The number before each card is how many copies the player OWNS. You MUST NOT suggest more copies than the player owns. For example, if a card shows \"1x\", you can only use 1 copy in the deck.\n"
            }
            catalog += "\nFirst, state which 2 colors you chose. Then provide the [DECKLIST] using ONLY cards from those 2 color sections.\n\nCHOOSE 2 COLORS AND USE ONLY THOSE:\n"

            let byColor = Dictionary(grouping: filteredCards) { $0.inkColor ?? "Unknown" }
            for colorName in byColor.keys.sorted() {
                let cards = byColor[colorName]!.sorted { $0.name < $1.name }
                catalog += "\n=== \(colorName.uppercased()) ===\n"
                for card in cards {
                    if collectionOnly, let qty = ownedCardQuantities[card.name] {
                        catalog += "- \(qty)x \(card.name)\n"
                    } else {
                        catalog += "- \(card.name)\n"
                    }
                }
            }
            return catalog
        }
    }

    // MARK: - Stream Completion
    private func streamCompletion(apiKey: String, prompt: String, collectionOnly: Bool = false, ownedCardQuantities: [String: Int] = [:]) async {
        currentCollectionOnly = collectionOnly
        currentOwnedCardQuantities = ownedCardQuantities
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
            enforceColorConstraint()
            autoFixUnmatched()
            enforceOwnedQuantities()
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
        enforceColorConstraint()
        autoFixUnmatched()
        enforceOwnedQuantities()
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
        let normalCards = allCards.filter { $0.variant == .normal }

        // Pre-build a lookup for fast exact matching
        let normalizedLookup: [String: LorcanaCard] = {
            var dict: [String: LorcanaCard] = [:]
            for card in normalCards {
                let key = normalizeName(card.name)
                if dict[key] == nil { dict[key] = card }
            }
            return dict
        }()

        for i in suggestions.indices {
            let rawName = suggestions[i].cardName
            let suggestionName = normalizeName(rawName)

            // 1. Exact match (normalized)
            if let match = normalizedLookup[suggestionName] {
                suggestions[i].matchedCard = match
                continue
            }

            // 2. Contains match (for slight name variations)
            if let match = normalCards.first(where: {
                let cardName = normalizeName($0.name)
                return cardName.contains(suggestionName) || suggestionName.contains(cardName)
            }) {
                suggestions[i].matchedCard = match
                continue
            }

            // 3. Split on " - " and match both parts independently
            let parts = suggestionName.components(separatedBy: " - ")
            if parts.count >= 2 {
                let firstName = parts[0].trimmingCharacters(in: .whitespaces)
                let subtitle = parts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)

                if let match = normalCards.first(where: {
                    let cardName = normalizeName($0.name)
                    return cardName.contains(firstName) && cardName.contains(subtitle)
                }) {
                    suggestions[i].matchedCard = match
                    continue
                }

                // 4. Edit-distance on character name, exact subtitle
                if let match = normalCards.first(where: {
                    let cardParts = normalizeName($0.name).components(separatedBy: " - ")
                    guard cardParts.count >= 2 else { return false }
                    let cardFirst = cardParts[0].trimmingCharacters(in: .whitespaces)
                    let cardSubtitle = cardParts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    let maxDist = max(1, min(2, firstName.count / 4))
                    return levenshteinDistance(firstName, cardFirst) <= maxDist && cardSubtitle == subtitle
                }) {
                    suggestions[i].matchedCard = match
                    continue
                }

                // 5. Exact character name, fuzzy subtitle
                if let match = normalCards.first(where: {
                    let cardParts = normalizeName($0.name).components(separatedBy: " - ")
                    guard cardParts.count >= 2 else { return false }
                    let cardFirst = cardParts[0].trimmingCharacters(in: .whitespaces)
                    let cardSubtitle = cardParts[1...].joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    let maxDist = max(1, min(2, subtitle.count / 3))
                    return cardFirst == firstName && levenshteinDistance(subtitle, cardSubtitle) <= maxDist
                }) {
                    suggestions[i].matchedCard = match
                    continue
                }
            }

            // 6. Word-overlap matching — find the card sharing the most words
            let suggestionWords = Set(suggestionName.components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty })
            if suggestionWords.count >= 2 {
                var bestMatch: LorcanaCard? = nil
                var bestOverlap = 0.0
                for card in normalCards {
                    let cardWords = Set(normalizeName(card.name).components(separatedBy: .alphanumerics.inverted).filter { !$0.isEmpty })
                    let shared = suggestionWords.intersection(cardWords).count
                    let total = max(suggestionWords.count, cardWords.count)
                    let overlap = Double(shared) / Double(total)
                    if overlap > bestOverlap {
                        bestOverlap = overlap
                        bestMatch = card
                    }
                }
                // Require at least 60% word overlap
                if bestOverlap >= 0.6, let match = bestMatch {
                    suggestions[i].matchedCard = match
                    continue
                }
            }

            // 7. Full-name edit distance fallback — find the closest card within a threshold
            let maxFullDist = max(3, suggestionName.count / 4)
            var bestEditMatch: LorcanaCard? = nil
            var bestDist = Int.max
            for card in normalCards {
                let dist = levenshteinDistance(suggestionName, normalizeName(card.name))
                if dist < bestDist {
                    bestDist = dist
                    bestEditMatch = card
                }
                if dist == 0 { break }
            }
            if bestDist <= maxFullDist, let match = bestEditMatch {
                suggestions[i].matchedCard = match
            }
        }
    }

    /// Levenshtein edit distance between two strings.
    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        if a == b { return 0 }
        let a = Array(a), b = Array(b)
        let m = a.count, n = b.count
        if m == 0 { return n }
        if n == 0 { return m }
        var dp = Array(repeating: Array(0...n), count: m + 1)
        for i in 1...m {
            dp[i][0] = i
            for j in 1...n {
                dp[i][j] = a[i-1] == b[j-1]
                    ? dp[i-1][j-1]
                    : 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
            }
        }
        return dp[m][n]
    }

    // MARK: - Enforce 2-Color Constraint
    private func enforceColorConstraint() {
        var colorCounts: [String: Int] = [:]
        for suggestion in suggestions {
            guard let card = suggestion.matchedCard, let inkColor = card.inkColor else { continue }
            colorCounts[inkColor, default: 0] += suggestion.quantity
        }

        guard colorCounts.count > 2 else { return }

        // Prefer colors the AI explicitly stated in its strategy text
        let intendedColors = detectIntendedColors(from: colorCounts)
        let removedColors = Set(colorCounts.keys).subtracting(intendedColors)

        suggestions = suggestions.filter { suggestion in
            guard let card = suggestion.matchedCard, let inkColor = card.inkColor else { return true }
            return intendedColors.contains(inkColor)
        }

        let colorList = intendedColors.sorted().joined(separator: " & ")
        colorConstraintNote = "Deck trimmed to 2 ink colors (\(colorList)). Removed cards from: \(removedColors.sorted().joined(separator: ", "))."
    }

    /// Detect the 2 ink colors the AI intended to use.
    /// Prefers colors explicitly mentioned in the strategy text; falls back to top 2 by card count.
    private func detectIntendedColors(from colorCounts: [String: Int]) -> Set<String> {
        let text = strategyText.lowercased()
        let mentionedColors = InkColor.allCases
            .map { $0.rawValue }
            .filter { colorCounts[$0] != nil && text.contains($0.lowercased()) }

        if mentionedColors.count == 2 {
            return Set(mentionedColors)
        }

        // Fall back to top 2 by total card count
        return Set(colorCounts.sorted { $0.value > $1.value }.prefix(2).map { $0.key })
    }

    // MARK: - Auto-Fix Unmatched Suggestions
    /// Replace any remaining unmatched suggestions with real cards that fit the deck's colors and cost range.
    private func autoFixUnmatched() {
        let unmatchedIndices = suggestions.indices.filter { suggestions[$0].matchedCard == nil }
        guard !unmatchedIndices.isEmpty else { return }

        // Determine the deck's ink colors from matched cards
        var deckColors = Set<String>()
        for suggestion in suggestions {
            if let color = suggestion.matchedCard?.inkColor {
                deckColors.insert(color)
            }
        }
        guard !deckColors.isEmpty else { return }

        // Collect names already used so we don't duplicate
        var usedNames = Set<String>()
        for suggestion in suggestions where suggestion.matchedCard != nil {
            usedNames.insert(suggestion.matchedCard!.name)
        }

        // Build a pool of eligible replacement cards
        var pool = dataManager.getAllCards().filter { card in
            card.variant == .normal
            && deckColors.contains(card.inkColor ?? "")
            && !usedNames.contains(card.name)
        }

        // Filter to only owned cards when collection-only mode is active
        if currentCollectionOnly && !currentOwnedCardQuantities.isEmpty {
            pool = pool.filter { currentOwnedCardQuantities[$0.name] != nil }
        }
        guard !pool.isEmpty else { return }

        // Group pool by cost for cost-appropriate replacements
        let poolByCost = Dictionary(grouping: pool) { $0.cost }

        for idx in unmatchedIndices {
            let originalQty = suggestions[idx].quantity
            // Try to find a card at a similar cost (guess from name patterns or use mid-range 3)
            let targetCost = suggestions[idx].matchedCard?.cost ?? 3
            let candidates = poolByCost[targetCost]
                ?? poolByCost[targetCost + 1]
                ?? poolByCost[targetCost - 1]
                ?? Array(pool.prefix(20))

            guard let replacement = candidates.first(where: { !usedNames.contains($0.name) }) else { continue }
            usedNames.insert(replacement.name)

            suggestions[idx] = AIDeckSuggestion(
                cardName: replacement.name,
                quantity: originalQty,
                reasoning: "Auto-replaced (original not found in database)",
                matchedCard: replacement
            )
        }
    }

    // MARK: - Enforce Owned Quantities
    /// Clamp each suggestion's quantity to the number the player actually owns.
    /// Removes suggestions entirely if the player owns 0 of that card.
    private func enforceOwnedQuantities() {
        guard currentCollectionOnly && !currentOwnedCardQuantities.isEmpty else { return }

        for i in suggestions.indices {
            guard let card = suggestions[i].matchedCard else { continue }
            let owned = currentOwnedCardQuantities[card.name] ?? 0
            if suggestions[i].quantity > owned {
                suggestions[i] = AIDeckSuggestion(
                    cardName: suggestions[i].cardName,
                    quantity: max(owned, 1),
                    reasoning: suggestions[i].reasoning,
                    matchedCard: suggestions[i].matchedCard
                )
            }
        }

        // Remove any suggestions where the player owns 0
        suggestions = suggestions.filter { suggestion in
            guard let card = suggestion.matchedCard else { return true }
            return (currentOwnedCardQuantities[card.name] ?? 0) > 0
        }
    }

    private func normalizeName(_ name: String) -> String {
        return name
            .replacingOccurrences(of: "\u{2013}", with: "-") // en dash → hyphen
            .replacingOccurrences(of: "\u{2014}", with: "-") // em dash → hyphen
            .replacingOccurrences(of: "\u{2018}", with: "'") // left single quote → apostrophe
            .replacingOccurrences(of: "\u{2019}", with: "'") // right single quote → apostrophe
            .replacingOccurrences(of: "'", with: "")         // remove apostrophes
            .replacingOccurrences(of: "'", with: "")         // remove straight apostrophes
            .lowercased()
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Replace Suggestion
    func replaceSuggestion(id: UUID, with card: LorcanaCard, quantity: Int) {
        guard let index = suggestions.firstIndex(where: { $0.id == id }) else { return }
        suggestions[index] = AIDeckSuggestion(
            cardName: card.name,
            quantity: quantity,
            reasoning: suggestions[index].reasoning,
            matchedCard: card
        )
    }

    // MARK: - Remove Suggestion
    func removeSuggestion(id: UUID) {
        suggestions.removeAll { $0.id == id }
    }

    // MARK: - Add Suggestion
    func addSuggestion(card: LorcanaCard, quantity: Int) {
        let suggestion = AIDeckSuggestion(
            cardName: card.name,
            quantity: quantity,
            reasoning: "Manually added",
            matchedCard: card
        )
        suggestions.append(suggestion)
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

    /// The strategy text portion of the response (everything before the decklist),
    /// with the "Part 2" / "Deck List" header stripped out.
    var strategyText: String {
        guard let range = rawResponse.range(of: "[DECKLIST]") else { return "" }
        var text = String(rawResponse[rawResponse.startIndex..<range.lowerBound])

        // Strip "Part 2 - Deck List" style headers the AI adds before [DECKLIST]
        if let partRange = text.range(of: #"(?i)\n*\**\s*part\s*2[^\n]*"#, options: .regularExpression) {
            text = String(text[text.startIndex..<partRange.lowerBound])
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Reset
    func reset() {
        suggestions = []
        rawResponse = ""
        currentStreamingContent = ""
        errorMessage = nil
        colorConstraintNote = nil
        isLoading = false
        currentCollectionOnly = false
        currentOwnedCardQuantities = [:]
    }
}
