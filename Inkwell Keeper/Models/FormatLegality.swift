//
//  FormatLegality.swift
//  Inkwell Keeper
//
//  Set legality for rotating formats. Core Constructed legality is per card NAME: any printing
//  of a card is legal when that card was printed in at least one legal set, so an old printing
//  of a card reprinted in a Core set is fine (Comprehensive Rules 2.2.0).
//

import Foundation

enum FormatLegality {

    /// Set names of the cards that are illegal under `legalSets`. A card is legal when its own
    /// printing is in a legal set, or when its name appears in `legalCardNames` (normalized
    /// names of every card printed in a legal set).
    static func illegalSets(
        of cards: [(name: String, setName: String)],
        legalSets: Set<String>,
        legalCardNames: Set<String>
    ) -> Set<String> {
        Set(cards.compactMap { card -> String? in
            if legalSets.contains(card.setName) { return nil }
            if legalCardNames.contains(DeckFormat.normalizeCardName(card.name)) { return nil }
            return card.setName
        })
    }

    /// `illegalSets` using the bundled card data for the reprint check.
    static func illegalSets(of cards: [(name: String, setName: String)], legalSets: Set<String>) -> Set<String> {
        illegalSets(of: cards, legalSets: legalSets, legalCardNames: legalCardNames(in: legalSets))
    }

    /// Normalized names of every card printed in `legalSets`, cached per set list. Empty until the
    /// card data has loaded — callers then fall back to the stricter per-printing check.
    static func legalCardNames(in legalSets: Set<String>) -> Set<String> {
        if let cached = cachedNames, cached.sets == legalSets { return cached.names }
        let manager = SetsDataManager.shared
        let names = Set(legalSets.flatMap { manager.getCardsForSet($0) }.map { DeckFormat.normalizeCardName($0.name) })
        // Don't cache before the data has loaded, or the empty result would stick.
        if !names.isEmpty {
            cachedNames = (legalSets, names)
        }
        return names
    }

    private static var cachedNames: (sets: Set<String>, names: Set<String>)?
}
