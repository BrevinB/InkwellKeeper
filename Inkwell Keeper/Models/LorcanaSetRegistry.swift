//
//  LorcanaSetRegistry.swift
//  Inkwell Keeper
//
//  Source of truth for rotating-format deck rules (Core legal sets + per-format banned cards),
//  with CloudKit-overridable values cached in UserDefaults. See `DeckRulesService`.
//

import Foundation

// MARK: - Lorcana Set Registry
/// Single source of truth for rotating-format rules: which sets are Core-legal and which cards are banned.
///
/// Values can be overridden remotely via CloudKit (see `DeckRulesService`); the overrides are cached in
/// `UserDefaults`. When no override has been fetched, the baked-in defaults below are used. This lets
/// rotations and bans ship without an app update while still working fully offline.
enum LorcanaSetRegistry {
    // MARK: Baked-in defaults

    /// Sets legal in Core Constructed by default.
    /// Update at each rotation (Sets 1–4 rotated out Sept 2025; Year 2 sets 5–8 rotate ~mid-2026).
    static let defaultCoreLegalSets: Set<String> = [
        "Shimmering Skies", "Azurite Sea", "Archazia's Island", "Reign of Jafar",
        "Fabled", "Whispers in the Well", "Winterspell"
    ]

    /// Cards banned in Core Constructed by default (banned 2025-04-08).
    static let defaultCoreBannedCards: [String] = [
        "Hiram Flaversham - Toymaker", "Fortisphere"
    ]

    /// Cards banned in Infinity Constructed by default (separate, shorter list; as of 2026-03-26).
    static let defaultInfinityBannedCards: [String] = [
        "Hiram Flaversham - Toymaker"
    ]

    // MARK: Cached / overridable values

    private static let coreLegalSetsKey = "deckRules.coreLegalSets"
    private static let coreBannedCardsKey = "deckRules.coreBannedCards"
    private static let infinityBannedCardsKey = "deckRules.infinityBannedCards"

    static var coreLegalSets: Set<String> {
        // Guard against an empty override wiping out all legal sets (which would invalidate every Core deck).
        if let stored = UserDefaults.standard.stringArray(forKey: coreLegalSetsKey), !stored.isEmpty {
            return Set(stored)
        }
        return defaultCoreLegalSets
    }

    static var coreBannedCards: [String] {
        // An empty override is meaningful (admin un-banned everything), so only fall back when unset.
        UserDefaults.standard.stringArray(forKey: coreBannedCardsKey) ?? defaultCoreBannedCards
    }

    static var infinityBannedCards: [String] {
        UserDefaults.standard.stringArray(forKey: infinityBannedCardsKey) ?? defaultInfinityBannedCards
    }

    /// Persists CloudKit-provided overrides. Pass `nil` for any value that wasn't supplied to leave it unchanged.
    static func applyOverrides(coreLegalSets: [String]?, coreBannedCards: [String]?, infinityBannedCards: [String]?) {
        let defaults = UserDefaults.standard
        if let coreLegalSets, !coreLegalSets.isEmpty {
            defaults.set(coreLegalSets, forKey: coreLegalSetsKey)
        }
        if let coreBannedCards {
            defaults.set(coreBannedCards, forKey: coreBannedCardsKey)
        }
        if let infinityBannedCards {
            defaults.set(infinityBannedCards, forKey: infinityBannedCardsKey)
        }
    }
}
