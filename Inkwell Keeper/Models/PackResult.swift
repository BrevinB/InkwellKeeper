//
//  PackResult.swift
//  Inkwell Keeper
//
//  Value types describing a simulated booster pack opening.
//  This feature is purely cosmetic — opened cards are never added
//  to the user's collection.
//

import Foundation

/// A single card slot inside a simulated booster pack.
struct PackSlot: Identifiable, Hashable {
    let id = UUID()
    let card: LorcanaCard
    /// Whether this slot is the pack's guaranteed foil/holo card.
    let isFoil: Bool
}

/// The result of opening one simulated booster pack.
struct PackResult: Identifiable {
    let id = UUID()
    let setName: String
    let slots: [PackSlot]
    let openedAt: Date

    init(setName: String, slots: [PackSlot], openedAt: Date = .now) {
        self.setName = setName
        self.slots = slots
        self.openedAt = openedAt
    }

    /// The most exciting card in the pack — highest rarity, with foil breaking
    /// ties — used to highlight the "hit" on the summary screen.
    var bestSlot: PackSlot? {
        slots.max { lhs, rhs in
            if lhs.card.rarity.sortOrder != rhs.card.rarity.sortOrder {
                return lhs.card.rarity.sortOrder < rhs.card.rarity.sortOrder
            }
            return !lhs.isFoil && rhs.isFoil
        }
    }

    /// Card counts grouped by rarity, ordered from lowest to highest rarity.
    var rarityTally: [(rarity: CardRarity, count: Int)] {
        Dictionary(grouping: slots, by: { $0.card.rarity })
            .map { (rarity: $0.key, count: $0.value.count) }
            .sorted { $0.rarity.sortOrder < $1.rarity.sortOrder }
    }
}
