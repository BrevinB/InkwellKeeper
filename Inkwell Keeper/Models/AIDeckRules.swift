//
//  AIDeckRules.swift
//  Inkwell Keeper
//
//  Deterministic Lorcana deck-construction checks for AI deck output. The model is
//  prompted to follow the rules, but these helpers are the source of truth: they decide
//  which cards may enter a generated list and audit the final result.
//

import Foundation

enum AIDeckRules {

    /// One card in a deck under audit — either already in the deck or suggested by the AI.
    struct Entry: Sendable {
        let name: String
        let quantity: Int
        let setName: String
        let inkColor: String?
        let isInkable: Bool

        init(name: String, quantity: Int, setName: String, inkColor: String?, isInkable: Bool) {
            self.name = name
            self.quantity = quantity
            self.setName = setName
            self.inkColor = inkColor
            self.isInkable = isInkable
        }

        init(card: LorcanaCard, quantity: Int) {
            self.init(
                name: card.name,
                quantity: quantity,
                setName: card.setName,
                inkColor: card.inkColor,
                isInkable: card.inkwell ?? false
            )
        }

        init(deckCard: DeckCard) {
            self.init(
                name: deckCard.name,
                quantity: deckCard.quantity,
                setName: deckCard.setName,
                inkColor: deckCard.inkColor,
                isInkable: deckCard.inkwell
            )
        }
    }

    /// Below this share of inkable cards a deck regularly can't ink every turn.
    static let minimumInkableRatio = 0.6

    /// The ink colors a card belongs to. Dual-ink cards are stored as e.g. "Ruby-Steel" and
    /// belong to both colors.
    static func inks(of inkColor: String?) -> Set<String> {
        guard let inkColor else { return [] }
        let parts = inkColor
            .split(whereSeparator: { $0 == "-" || $0 == "," || $0 == "/" })
            .compactMap { InkColor.fromString($0.trimmingCharacters(in: .whitespaces))?.rawValue }
        return Set(parts)
    }

    /// Whether a card can go in a deck limited to `allowedColors`. A dual-ink card is only
    /// legal when the deck plays both of its inks.
    static func fits(inkColor: String?, allowedColors: Set<String>) -> Bool {
        let cardInks = inks(of: inkColor)
        return !cardInks.isEmpty && cardInks.isSubset(of: allowedColors)
    }

    /// The inks the AI committed to on its `[INKS] Ruby / Steel` line, when it was left to
    /// choose. Nil when the line is missing, names no real ink, or exceeds `limit` — callers
    /// then fall back to inferring the inks from the decklist.
    static func declaredInks(in response: String, limit: Int) -> Set<String>? {
        guard let tagRange = response.range(of: "[INKS]") else { return nil }
        let line = response[tagRange.upperBound...].prefix { $0 != "\n" }
        let words = line.split(whereSeparator: { !$0.isLetter })
        let inks = Set(words.compactMap { InkColor.fromString(String($0))?.rawValue })
        guard !inks.isEmpty, inks.count <= limit else { return nil }
        return inks
    }

    /// Combines suggestions that resolved to the same card (the AI listing a card twice, or two
    /// misspellings matching one card), so the copy limit sees the real total. Keeps the first
    /// suggestion's identity and position. Unmatched suggestions pass through untouched.
    static func mergeDuplicates(_ suggestions: [AIDeckSuggestion]) -> [AIDeckSuggestion] {
        var result: [AIDeckSuggestion] = []
        var indexByName: [String: Int] = [:]
        for suggestion in suggestions {
            guard let card = suggestion.matchedCard else {
                result.append(suggestion)
                continue
            }
            let key = DeckFormat.normalizeCardName(card.name)
            if let index = indexByName[key] {
                result[index] = result[index].withQuantity(result[index].quantity + suggestion.quantity)
            } else {
                indexByName[key] = result.count
                result.append(suggestion)
            }
        }
        return result
    }

    /// Audits a finished deck (existing cards plus accepted suggestions) against the format.
    static func audit(
        _ entries: [Entry],
        format: DeckFormat,
        allowedColors: Set<String>?,
        targetTotal: Int
    ) -> AIDeckRuleReport {
        var violations: [String] = []
        var warnings: [String] = []

        let total = entries.reduce(0) { $0 + $1.quantity }
        if total < format.minimumCards {
            violations.append("\(total) of \(format.minimumCards) cards — add \(format.minimumCards - total) more.")
        } else if total > targetTotal {
            warnings.append("\(total) cards — most decks run exactly \(targetTotal).")
        }

        // Copy limit is per card name: reprints in different sets share it.
        var copiesByName: [String: (name: String, quantity: Int)] = [:]
        for entry in entries {
            let key = DeckFormat.normalizeCardName(entry.name)
            copiesByName[key, default: (entry.name, 0)].quantity += entry.quantity
        }
        for (_, value) in copiesByName.sorted(by: { $0.key < $1.key })
        where value.quantity > format.maxCopiesPerCard {
            violations.append("\(value.name): \(value.quantity) copies (max \(format.maxCopiesPerCard)).")
        }

        if let legalSets = format.legalSets {
            let cards = entries.map { (name: $0.name, setName: $0.setName) }
            let illegal = FormatLegality.illegalSets(of: cards, legalSets: legalSets)
            if !illegal.isEmpty {
                violations.append("Cards from sets not legal in \(format.rawValue): \(illegal.sorted().joined(separator: ", ")).")
            }
        }

        let banned = Set(entries.map(\.name).filter { format.isBanned($0) })
        if !banned.isEmpty {
            violations.append("Banned in \(format.rawValue): \(banned.sorted().joined(separator: ", ")).")
        }

        let deckInks = entries.reduce(into: Set<String>()) { $0.formUnion(inks(of: $1.inkColor)) }
        if deckInks.count > format.maxInkColors {
            violations.append("Uses \(deckInks.count) inks (\(deckInks.sorted().joined(separator: ", "))) — \(format.rawValue) allows \(format.maxInkColors).")
        } else if let allowedColors {
            let offColor = entries.filter { !fits(inkColor: $0.inkColor, allowedColors: allowedColors) }
            if !offColor.isEmpty {
                let names = Set(offColor.map(\.name)).sorted().joined(separator: ", ")
                violations.append("Outside your inks: \(names).")
            }
        }

        let inkable = entries.filter(\.isInkable).reduce(0) { $0 + $1.quantity }
        if total > 0 {
            let ratio = Double(inkable) / Double(total)
            if ratio < minimumInkableRatio {
                warnings.append("Only \(inkable) of \(total) cards are inkable — most decks run 70%+.")
            }
        }

        return AIDeckRuleReport(
            violations: violations,
            warnings: warnings,
            totalCards: total,
            inkableCards: inkable
        )
    }
}

/// Result of `AIDeckRules.audit`: hard rule breaks plus softer deck-health warnings.
struct AIDeckRuleReport: Equatable, Sendable {
    let violations: [String]
    let warnings: [String]
    let totalCards: Int
    let inkableCards: Int

    var isLegal: Bool { violations.isEmpty }
}
