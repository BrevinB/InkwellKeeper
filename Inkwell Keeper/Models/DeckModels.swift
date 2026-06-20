//
//  DeckModels.swift
//  Inkwell Keeper
//
//  Deck building data models and enums
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Ink Colors
enum InkColor: String, Codable, CaseIterable, Hashable {
    case amber = "Amber"
    case amethyst = "Amethyst"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case steel = "Steel"

    var color: Color {
        switch self {
        case .amber: return Color(red: 1.0, green: 0.7, blue: 0.2)
        case .amethyst: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .emerald: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .ruby: return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .sapphire: return Color(red: 0.2, green: 0.5, blue: 1.0)
        case .steel: return Color(red: 0.6, green: 0.6, blue: 0.7)
        }
    }

    var systemImage: String {
        "circle.fill"
    }

    static func fromString(_ string: String) -> InkColor? {
        return InkColor(rawValue: string) ??
               InkColor.allCases.first { $0.rawValue.lowercased() == string.lowercased() }
    }
}

// MARK: - Deck Format
enum DeckFormat: String, Codable, CaseIterable {
    case casual = "Casual"
    case coreConstructed = "Core Constructed"
    case infinityConstructed = "Infinity Constructed"
    case tripleDeck = "Triple Deck"

    var description: String {
        switch self {
        case .casual:
            return "All sets, up to 2 inks"
        case .coreConstructed:
            return "Rotating format (Sets 5+)"
        case .infinityConstructed:
            return "All sets, all 6 inks"
        case .tripleDeck:
            return "3 decks, each a unique ink pair covering all 6 colors"
        }
    }

    var minimumCards: Int {
        60 // Per deck for Triple Deck
    }

    var maxInkColors: Int {
        switch self {
        case .casual, .coreConstructed:
            return 2
        case .infinityConstructed:
            return 6 // Infinity removes the two-ink limit
        case .tripleDeck:
            return 2 // Per deck, but all 6 total across 3 decks
        }
    }

    var maxCopiesPerCard: Int {
        return 4
    }

    /// Sets legal for this format; `nil` means all sets are legal (no rotation).
    var legalSets: Set<String>? {
        switch self {
        case .coreConstructed:
            return LorcanaSetRegistry.coreLegalSets
        case .casual, .infinityConstructed, .tripleDeck:
            return nil
        }
    }

    /// Individually banned cards (by full name) for this format. Casual and Triple Deck have no bans.
    var bannedCards: [String] {
        switch self {
        case .coreConstructed:
            return LorcanaSetRegistry.coreBannedCards
        case .infinityConstructed:
            return LorcanaSetRegistry.infinityBannedCards
        case .casual, .tripleDeck:
            return []
        }
    }

    /// Whether `cardName` is banned in this format. Matches on a normalized name so dash style and
    /// spacing differences (e.g. "–" vs "-") don't cause false negatives.
    func isBanned(_ cardName: String) -> Bool {
        guard !bannedCards.isEmpty else { return false }
        let normalized = Self.normalizeCardName(cardName)
        return bannedCards.contains { Self.normalizeCardName($0) == normalized }
    }

    /// Normalizes a card name for comparison: unifies dash characters, lowercases, and collapses whitespace.
    static func normalizeCardName(_ name: String) -> String {
        name
            .replacing("–", with: "-")
            .replacing("—", with: "-")
            .lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Deck Archetype (Optional tagging)
enum DeckArchetype: String, Codable, CaseIterable {
    case aggro = "Aggro"
    case midrange = "Midrange"
    case control = "Control"
    case combo = "Combo"
    case ramp = "Ramp"
    case other = "Other"

    var systemImage: String {
        switch self {
        case .aggro: return "bolt.fill"
        case .midrange: return "arrow.left.arrow.right"
        case .control: return "shield.fill"
        case .combo: return "gearshape.2.fill"
        case .ramp: return "chart.line.uptrend.xyaxis"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Deck Model
@Model
class Deck {
    var id: UUID = UUID()
    var name: String = ""
    var deckDescription: String = ""
    var format: String = DeckFormat.infinityConstructed.rawValue // DeckFormat rawValue
    var inkColors: [String] = [] // InkColor rawValues
    var archetype: String? // DeckArchetype rawValue
    var createdDate: Date = Date.now
    var lastModified: Date = Date.now
    var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \DeckCard.deck)
    var cards: [DeckCard]?

    // Computed properties
    var deckFormat: DeckFormat {
        get { DeckFormat(rawValue: format) ?? .infinityConstructed }
        set { format = newValue.rawValue }
    }

    var deckInkColors: [InkColor] {
        get { inkColors.compactMap { InkColor.fromString($0) } }
        set { inkColors = newValue.map { $0.rawValue } }
    }

    var deckArchetype: DeckArchetype? {
        get {
            guard let archetype = archetype else { return nil }
            return DeckArchetype(rawValue: archetype)
        }
        set { archetype = newValue?.rawValue }
    }

    var totalCards: Int {
        (cards ?? []).reduce(0) { $0 + $1.quantity }
    }

    var uniqueCards: Int {
        (cards ?? []).count
    }

    init(
        name: String,
        description: String = "",
        format: DeckFormat = .infinityConstructed,
        inkColors: [InkColor] = [],
        archetype: DeckArchetype? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.deckDescription = description
        self.format = format.rawValue
        self.inkColors = inkColors.map { $0.rawValue }
        self.archetype = archetype?.rawValue
        self.createdDate = Date()
        self.lastModified = Date()
        self.notes = notes
        self.cards = []
    }
}

// MARK: - Deck Card Model
@Model
class DeckCard {
    var cardId: String = ""
    var name: String = ""
    var cost: Int = 0
    var type: String = ""
    var rarity: String = ""
    var setName: String = ""
    var imageUrl: String = ""
    var inkColor: String?
    var inkwell: Bool = false
    var quantity: Int = 1
    var variant: String = CardVariant.normal.rawValue
    var price: Double?
    var cardNumber: Int?
    var uniqueId: String?

    @Relationship(deleteRule: .nullify)
    var deck: Deck?

    var cardRarity: CardRarity {
        get { CardRarity(rawValue: rarity) ?? .common }
        set { rarity = newValue.rawValue }
    }

    var cardInkColor: InkColor? {
        get {
            guard let inkColor = inkColor else { return nil }
            return InkColor.fromString(inkColor)
        }
        set { inkColor = newValue?.rawValue }
    }

    var cardVariant: CardVariant {
        get { CardVariant(rawValue: variant) ?? .normal }
        set { variant = newValue.rawValue }
    }

    init(from card: LorcanaCard, quantity: Int = 1) {
        self.cardId = card.id
        self.name = card.name
        self.cost = card.cost
        self.type = card.type
        self.rarity = card.rarity.rawValue
        self.setName = card.setName
        self.imageUrl = card.imageUrl
        self.inkColor = card.inkColor
        self.inkwell = card.inkwell ?? false
        self.quantity = quantity
        self.variant = card.variant.rawValue
        self.price = card.price
        self.cardNumber = card.cardNumber
        self.uniqueId = card.uniqueId
        self.deck = nil
    }

    var toLorcanaCard: LorcanaCard {
        LorcanaCard(
            id: cardId,
            name: name,
            cost: cost,
            type: type,
            rarity: cardRarity,
            setName: setName,
            imageUrl: imageUrl,
            price: price,
            variant: cardVariant,
            cardNumber: cardNumber,
            uniqueId: uniqueId,
            inkwell: inkwell,
            inkColor: inkColor
        )
    }

    /// Get the best available image URL - prefers local, falls back to remote
    func bestImageUrl() -> URL? {
        // Convert to LorcanaCard and use its bestImageUrl method
        return toLorcanaCard.bestImageUrl()
    }
}

// MARK: - Deck Statistics
struct DeckStatistics {
    let totalCards: Int
    let uniqueCards: Int
    let averageCost: Double
    let inkableCount: Int
    let inkableRatio: Double
    let costDistribution: [Int: Int] // Cost -> Count
    let typeDistribution: [String: Int] // Type -> Count
    let rarityDistribution: [CardRarity: Int]
    let totalValue: Double
    let ownedCards: Int
    let missingCards: Int
    let completionPercentage: Double
    let costToComplete: Double

    static func calculate(for deck: Deck, collectionManager: CollectionManager) -> DeckStatistics {
        let cards = deck.cards ?? []
        let totalCards = deck.totalCards

        // Cost distribution and average
        var costDist: [Int: Int] = [:]
        var totalCost = 0
        for card in cards {
            let cost = card.cost
            costDist[cost, default: 0] += card.quantity
            totalCost += cost * card.quantity
        }
        let avgCost = totalCards > 0 ? Double(totalCost) / Double(totalCards) : 0

        // Inkable cards
        let inkableCount = cards.filter { $0.inkwell }.reduce(0) { $0 + $1.quantity }
        let inkableRatio = totalCards > 0 ? Double(inkableCount) / Double(totalCards) : 0

        // Type distribution
        var typeDist: [String: Int] = [:]
        for card in cards {
            typeDist[card.type, default: 0] += card.quantity
        }

        // Rarity distribution
        var rarityDist: [CardRarity: Int] = [:]
        for card in cards {
            rarityDist[card.cardRarity, default: 0] += card.quantity
        }

        // Ownership and cost calculation
        var ownedCount = 0
        var totalValue = 0.0
        var costToComplete = 0.0

        for deckCard in cards {
            let neededQuantity = deckCard.quantity

            // Try ID match first, then fallback to name match
            var ownedQuantity = collectionManager.getCollectedQuantity(for: deckCard.cardId)
            if ownedQuantity == 0 {
                ownedQuantity = collectionManager.getCollectedQuantityByName(
                    deckCard.name,
                    setName: deckCard.setName,
                    variant: deckCard.cardVariant
                )
            }

            let missing = max(0, neededQuantity - ownedQuantity)

            ownedCount += min(ownedQuantity, neededQuantity)

            if let price = deckCard.price {
                totalValue += price * Double(neededQuantity)
                costToComplete += price * Double(missing)
            }
        }

        let completionPercentage = totalCards > 0 ? (Double(ownedCount) / Double(totalCards)) * 100 : 0

        return DeckStatistics(
            totalCards: totalCards,
            uniqueCards: cards.count,
            averageCost: avgCost,
            inkableCount: inkableCount,
            inkableRatio: inkableRatio,
            costDistribution: costDist,
            typeDistribution: typeDist,
            rarityDistribution: rarityDist,
            totalValue: totalValue,
            ownedCards: ownedCount,
            missingCards: totalCards - ownedCount,
            completionPercentage: completionPercentage,
            costToComplete: costToComplete
        )
    }
}
