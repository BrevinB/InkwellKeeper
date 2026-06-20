//
//  DeckValidation.swift
//  Inkwell Keeper
//
//  Format-aware validation for a deck (size, ink colors, set legality/rotation, banned cards, copy limits).
//

import Foundation

// MARK: - Deck Validation
struct DeckValidation {
    let isValid: Bool
    let warnings: [String]
    let errors: [String]

    static func validate(_ deck: Deck) -> DeckValidation {
        var warnings: [String] = []
        var errors: [String] = []

        let format = deck.deckFormat
        let totalCards = deck.totalCards

        // Check minimum deck size
        if totalCards < format.minimumCards {
            errors.append("Deck has only \(totalCards) cards. Minimum is \(format.minimumCards).")
        }

        // Warn if under 60 but over minimum (shouldn't happen for standard formats)
        if totalCards > 0 && totalCards < 60 {
            warnings.append("Most competitive decks run exactly 60 cards.")
        }

        // Check ink color restrictions
        let deckInkColors = deck.deckInkColors
        if deckInkColors.count > format.maxInkColors {
            errors.append("Deck has \(deckInkColors.count) ink colors. Maximum is \(format.maxInkColors).")
        }

        if deckInkColors.isEmpty && totalCards > 0 {
            warnings.append("No ink colors selected. Cards may not match deck colors.")
        }

        // Check set legality (rotation) and individually banned cards for the format
        errors.append(contentsOf: setLegalityErrors(deck, format: format))
        errors.append(contentsOf: bannedCardErrors(deck, format: format))

        // Check for max copies per card
        for card in deck.cards ?? [] where card.quantity > format.maxCopiesPerCard {
            errors.append("\(card.name): \(card.quantity) copies (max \(format.maxCopiesPerCard))")
        }

        // Check ink color consistency
        let cardsWithWrongInk = (deck.cards ?? []).filter { card in
            guard let cardInk = card.cardInkColor else { return false }
            return !deckInkColors.contains(cardInk)
        }
        if !cardsWithWrongInk.isEmpty && !deckInkColors.isEmpty {
            warnings.append("\(cardsWithWrongInk.count) cards don't match deck ink colors")
        }

        // Check inkable ratio
        let inkableCards = (deck.cards ?? []).filter { $0.inkwell }.reduce(0) { $0 + $1.quantity }
        let inkableRatio = totalCards > 0 ? Double(inkableCards) / Double(totalCards) : 0
        if inkableRatio < 0.3 && totalCards >= 30 {
            warnings.append("Low inkable ratio (\(Int(inkableRatio * 100))%). Recommended 30-40%.")
        }

        return DeckValidation(
            isValid: errors.isEmpty,
            warnings: warnings,
            errors: errors
        )
    }

    /// Errors for cards from sets that aren't legal in a rotating format (none if `legalSets` is nil).
    private static func setLegalityErrors(_ deck: Deck, format: DeckFormat) -> [String] {
        guard let legalSets = format.legalSets else { return [] }
        let illegalSets = Set((deck.cards ?? []).map { $0.setName }).subtracting(legalSets)
        guard !illegalSets.isEmpty else { return [] }
        return ["Contains cards from rotated/illegal sets: \(illegalSets.sorted().joined(separator: ", "))"]
    }

    /// Errors for individually banned cards in the format's ban list.
    private static func bannedCardErrors(_ deck: Deck, format: DeckFormat) -> [String] {
        guard !format.bannedCards.isEmpty else { return [] }
        let banned = Set((deck.cards ?? []).map { $0.name }.filter { format.isBanned($0) })
        guard !banned.isEmpty else { return [] }
        return ["Contains banned cards: \(banned.sorted().joined(separator: ", "))"]
    }
}
