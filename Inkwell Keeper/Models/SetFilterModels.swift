//
//  SetFilterModels.swift
//  Inkwell Keeper
//
//  Filter and sort options for browsing a set's cards, plus the pure
//  filtering engine so the logic is unit-testable.
//

import Foundation

/// Ownership scope for browsing a set.
enum SetOwnershipFilter: String, CaseIterable {
    case all = "All Cards"
    case owned = "Owned"
    case missing = "Missing"

    var systemImage: String {
        switch self {
        case .all: return "rectangle.grid.3x2"
        case .owned: return "checkmark.circle"
        case .missing: return "xmark.circle"
        }
    }
}

/// Market-price buckets, matched against the backend's bulk set prices.
enum PriceFilter: String, CaseIterable {
    case all = "Any Price"
    case underOne = "Under $1"
    case oneToFive = "$1–5"
    case fiveToTwenty = "$5–20"
    case twentyPlus = "$20+"

    /// Cards without a known price only match "Any Price".
    func matches(_ price: Double?) -> Bool {
        switch self {
        case .all:
            return true
        case .underOne:
            guard let price else { return false }
            return price < 1
        case .oneToFive:
            guard let price else { return false }
            return price >= 1 && price < 5
        case .fiveToTwenty:
            guard let price else { return false }
            return price >= 5 && price < 20
        case .twentyPlus:
            guard let price else { return false }
            return price >= 20
        }
    }
}

enum SetSortOption: String, CaseIterable {
    case cardNumber = "Card Number"
    case priceHighToLow = "Price: High to Low"
    case priceLowToHigh = "Price: Low to High"
    case rarity = "Rarity"

    var displayName: String { rawValue }
}

/// Pure filtering/sorting over a set's cards. `prices` is keyed by card id.
enum SetCardFilterEngine {
    // swiftlint:disable:next function_parameter_count
    static func apply(
        to cards: [LorcanaCard],
        ownership: SetOwnershipFilter,
        inkColor: InkColorFilter,
        rarity: CardRarity?,
        variant: VariantFilter,
        price: PriceFilter,
        searchText: String,
        prices: [String: Double],
        isOwned: (LorcanaCard) -> Bool
    ) -> [LorcanaCard] {
        var result = cards

        switch ownership {
        case .all: break
        case .owned: result = result.filter(isOwned)
        case .missing: result = result.filter { !isOwned($0) }
        }

        if inkColor != .all {
            result = result.filter { card in
                guard let ink = card.inkColor, !ink.isEmpty else { return false }
                // Dual-ink cards may join colors with "-" or ","
                let colors = ink
                    .split(whereSeparator: { $0 == "-" || $0 == "," })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                return colors.contains(inkColor.rawValue)
            }
        }

        if let rarity {
            result = result.filter { $0.rarity == rarity }
        }

        if variant != .all {
            result = result.filter { variant.matches($0.variant) }
        }

        if price != .all {
            result = result.filter { price.matches(prices[$0.id]) }
        }

        if !searchText.isEmpty {
            result = result.filter { card in
                card.name.localizedStandardContains(searchText) ||
                card.cardText.localizedStandardContains(searchText) ||
                card.cardNumber.map { String($0).localizedStandardContains(searchText) } ?? false
            }
        }

        return result
    }

    static func sort(_ cards: [LorcanaCard], by option: SetSortOption, prices: [String: Double]) -> [LorcanaCard] {
        switch option {
        case .cardNumber:
            return cards.sorted { ($0.cardNumber ?? Int.max) < ($1.cardNumber ?? Int.max) }
        case .priceHighToLow:
            return cards.sorted { (prices[$0.id] ?? -1) > (prices[$1.id] ?? -1) }
        case .priceLowToHigh:
            // Unpriced cards sort last, not first
            return cards.sorted { (prices[$0.id] ?? .greatestFiniteMagnitude) < (prices[$1.id] ?? .greatestFiniteMagnitude) }
        case .rarity:
            return cards.sorted {
                if $0.rarity.sortOrder != $1.rarity.sortOrder {
                    return $0.rarity.sortOrder > $1.rarity.sortOrder
                }
                return ($0.cardNumber ?? Int.max) < ($1.cardNumber ?? Int.max)
            }
        }
    }
}
