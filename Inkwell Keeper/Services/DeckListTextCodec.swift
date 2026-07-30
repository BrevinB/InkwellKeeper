//
//  DeckListTextCodec.swift
//  Inkwell Keeper
//
//  Reads and writes the community deck-list text format — one card per line,
//  "4 Elsa - Snow Queen" — the format Dreamborn, inkdecks, and Discord pastes use.
//  Unlike Dreamborn's importer, unmatched lines are reported instead of silently dropped.
//

import Foundation

enum DeckListTextCodec {
    /// A line the parser recognized as a card entry but couldn't resolve against the card database.
    struct UnmatchedLine: Equatable {
        let lineNumber: Int
        let text: String
    }

    struct ParseResult {
        /// Resolved cards with their summed quantities, in first-appearance order.
        var entries: [(card: LorcanaCard, quantity: Int)]
        var unmatched: [UnmatchedLine]

        var totalMatchedCards: Int {
            entries.reduce(0) { $0 + $1.quantity }
        }
    }

    // MARK: - Export

    /// Renders a deck as community-format text: `{qty} {Name - Title}` per line,
    /// sorted by cost then name so lists diff cleanly.
    static func export(_ deck: Deck) -> String {
        (deck.cards ?? [])
            .sorted { ($0.cost, $0.name) < ($1.cost, $1.name) }
            .map { "\($0.quantity) \($0.name)" }
            .joined(separator: "\n")
    }

    // MARK: - Import

    /// Whether pasted text looks like a deck list (at least one `{qty} {name}` line).
    static func looksLikeDeckList(_ text: String) -> Bool {
        text.split(separator: "\n").contains { parseLine(String($0)) != nil }
    }

    /// Parses community-format text against the card database. Blank lines, comments, and
    /// header lines are skipped; card lines that can't be resolved are returned in `unmatched`.
    static func parse(_ text: String, cards: [LorcanaCard]) -> ParseResult {
        // Reprints share a name across sets; keep the first printing per normalized name.
        let normalCards = cards.filter { $0.variant == .normal }
        var byName: [String: LorcanaCard] = [:]
        var byUniqueId: [String: LorcanaCard] = [:]
        for card in normalCards {
            let key = normalize(card.name)
            if byName[key] == nil { byName[key] = card }
            if let uniqueId = card.uniqueId {
                byUniqueId[uniqueId.uppercased()] = card
            }
        }

        var quantities: [String: Int] = [:]
        var order: [String: LorcanaCard] = [:]
        var orderedIds: [String] = []
        var unmatched: [UnmatchedLine] = []

        for (index, rawLine) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !isNonCardLine(line) else { continue }

            guard let parsed = parseLine(line) else {
                unmatched.append(UnmatchedLine(lineNumber: index + 1, text: line))
                continue
            }

            guard let card = resolve(parsed, byName: byName, byUniqueId: byUniqueId, cards: normalCards) else {
                unmatched.append(UnmatchedLine(lineNumber: index + 1, text: line))
                continue
            }

            if order[card.id] == nil {
                order[card.id] = card
                orderedIds.append(card.id)
            }
            quantities[card.id, default: 0] += parsed.quantity
        }

        let entries = orderedIds.compactMap { id -> (card: LorcanaCard, quantity: Int)? in
            guard let card = order[id], let quantity = quantities[id] else { return nil }
            return (card, quantity)
        }
        return ParseResult(entries: entries, unmatched: unmatched)
    }

    // MARK: - Line parsing

    private struct ParsedLine {
        let quantity: Int
        let name: String
        /// Optional `(SET) number` suffix, e.g. ("TFC", 42).
        let setCode: String?
        let cardNumber: Int?
    }

    /// Header/footer lines emitted by known exporters (including our own detailed export),
    /// skipped without being reported as unmatched.
    private static let headerPrefixes = [
        "deck:", "format:", "colors:", "archetype:", "cards:", "exported from", "#", "//"
    ]

    private static func isNonCardLine(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return headerPrefixes.contains { lowered.hasPrefix($0) }
    }

    /// Accepts `4 Name`, `4x Name`, and an optional trailing `(SET) 42` / `(SET)` suffix.
    private static func parseLine(_ line: String) -> ParsedLine? {
        guard let match = line.wholeMatch(of: /(\d{1,3})\s*[xX]?\s+(.+)/) else { return nil }
        guard let quantity = Int(match.1), quantity > 0 else { return nil }

        var name = String(match.2).trimmingCharacters(in: .whitespaces)
        var setCode: String?
        var cardNumber: Int?

        if let suffix = name.firstMatch(of: /\s*\(([A-Za-z0-9]{1,8})\)\s*(\d{1,4})?\s*$/) {
            setCode = String(suffix.1)
            cardNumber = suffix.2.flatMap { Int($0) }
            name.removeSubrange(suffix.range)
            name = name.trimmingCharacters(in: .whitespaces)
        }

        guard !name.isEmpty else { return nil }
        return ParsedLine(quantity: quantity, name: name, setCode: setCode, cardNumber: cardNumber)
    }

    // MARK: - Card resolution

    private static func resolve(
        _ line: ParsedLine,
        byName: [String: LorcanaCard],
        byUniqueId: [String: LorcanaCard],
        cards: [LorcanaCard]
    ) -> LorcanaCard? {
        // 1. `(SET) number` suffix maps straight onto uniqueIds like "TFC-001".
        if let setCode = line.setCode, let number = line.cardNumber {
            let padded = String(repeating: "0", count: max(0, 3 - String(number).count)) + String(number)
            for candidate in ["\(setCode.uppercased())-\(padded)", "\(setCode.uppercased())-\(number)"] {
                if let card = byUniqueId[candidate] { return card }
            }
        }

        // 2. Exact match on the normalized full name.
        let normalized = normalize(line.name)
        if let card = byName[normalized] { return card }

        // 3. Closest name within a small edit distance, to absorb hand-typed lists.
        let maxDistance = max(1, min(3, normalized.count / 8))
        var best: (card: LorcanaCard, distance: Int)?
        for (name, card) in byName where abs(name.count - normalized.count) <= maxDistance {
            let distance = levenshteinDistance(normalized, name)
            if distance <= maxDistance && distance < (best?.distance ?? Int.max) {
                best = (card, distance)
                if distance == 1 { break }
            }
        }
        return best?.card
    }

    /// Normalization for name matching: dash/apostrophe/diacritic-insensitive,
    /// case-insensitive, whitespace-collapsed.
    static func normalize(_ name: String) -> String {
        DeckFormat.normalizeCardName(
            name
                .replacing("’", with: "'")
                .replacing("‘", with: "'")
                .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US"))
        )
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        let source = Array(lhs), target = Array(rhs)
        if source.isEmpty { return target.count }
        if target.isEmpty { return source.count }
        var previous = Array(0...target.count)
        var current = [Int](repeating: 0, count: target.count + 1)
        for row in 1...source.count {
            current[0] = row
            for col in 1...target.count {
                current[col] = source[row - 1] == target[col - 1]
                    ? previous[col - 1]
                    : 1 + min(previous[col], current[col - 1], previous[col - 1])
            }
            swap(&previous, &current)
        }
        return previous[target.count]
    }
}
