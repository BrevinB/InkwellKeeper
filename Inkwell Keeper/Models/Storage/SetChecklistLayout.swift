//
//  SetChecklistLayout.swift
//  Inkwell Keeper
//
//  Which pocket each card of a set belongs in, for a set checklist binder.
//
//  One per card (default): card #N goes in pocket N, whichever printing you have.
//  Master set: each card with a normal printing gets two neighbouring pockets —
//  normal, then foil — while foil-only printings (Epic, Enchanted, Iconic, promos)
//  get one. Pockets run in card-number order.
//

import Foundation

struct SetChecklistLayout {
    /// The printing each card number is in this set (Normal for the main run).
    let printings: [Int: CardVariant]
    let hasFoilPockets: Bool

    /// A pocket's purpose: which card number, and whether it's that card's foil pocket.
    struct Pocket: Equatable {
        let number: Int
        let isFoilPocket: Bool
    }

    /// Master-set pockets in order, built once.
    private let pairedPockets: [Pocket]
    private let pairedSlots: [Int: (normal: Int, foil: Int?)]

    init(printings: [Int: CardVariant], hasFoilPockets: Bool) {
        self.printings = printings
        self.hasFoilPockets = hasFoilPockets

        var pockets: [Pocket] = []
        var slots: [Int: (normal: Int, foil: Int?)] = [:]
        if hasFoilPockets {
            for number in printings.keys.sorted() {
                let first = pockets.count
                if printings[number] == .normal {
                    pockets.append(Pocket(number: number, isFoilPocket: false))
                    pockets.append(Pocket(number: number, isFoilPocket: true))
                    slots[number] = (first, first + 1)
                } else {
                    pockets.append(Pocket(number: number, isFoilPocket: false))
                    slots[number] = (first, nil)
                }
            }
        }
        pairedPockets = pockets
        pairedSlots = slots
    }

    /// Pockets the binder needs to hold the whole set.
    var pocketCount: Int {
        hasFoilPockets ? pairedPockets.count : (printings.keys.max() ?? 0)
    }

    /// The pocket for a card number and printing, or nil if this binder has none for it.
    /// `variant` is the copy's printing; foils of normal cards use the foil pocket in a
    /// master set and share the card's pocket otherwise.
    func slot(forNumber number: Int, variant: CardVariant) -> Int? {
        if let expected = printings[number] {
            let printing = variant == .foil ? CardVariant.normal : variant
            guard printing == expected else { return nil }
        }
        guard hasFoilPockets else { return number - 1 }
        guard let slots = pairedSlots[number] else { return nil }
        return variant == .foil ? slots.foil : slots.normal
    }

    /// What belongs in a pocket, for drawing the "missing" ghost.
    func pocket(atSlot slot: Int) -> Pocket? {
        if hasFoilPockets {
            return pairedPockets.indices.contains(slot) ? pairedPockets[slot] : nil
        }
        return printings[slot + 1] == nil ? nil : Pocket(number: slot + 1, isFoilPocket: false)
    }
}

extension SetChecklistLayout {
    /// Which printing each card number is in a set, from the loaded catalog.
    @MainActor
    static func catalogPrintings(for setName: String) -> [Int: CardVariant] {
        var printings: [Int: CardVariant] = [:]
        for card in SetsDataManager.shared.getCardsForSet(setName) {
            if let number = card.cardNumber, printings[number] == nil {
                printings[number] = card.variant
            }
        }
        return printings
    }
}
