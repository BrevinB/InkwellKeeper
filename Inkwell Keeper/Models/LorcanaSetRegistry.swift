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
    /// Update at each rotation (Sets 1–4 rotated out Sept 2025; sets 5–8 rotated out July 2026,
    /// leaving sets 9–13 per Comprehensive Rules 2.2.0). Names must match the bundled set data
    /// exactly — `LorcanaSetRegistryTests` checks this.
    ///
    /// New sets can be listed before release: `DeckFormat.legalSets` drops any set whose release
    /// day hasn't arrived, so Hyperia City becomes Core-legal on its own on 2026-10-16.
    static let defaultCoreLegalSets: Set<String> = [
        "Fabled", "Whispers in the Well", "Winterspell", "Wilds Unknown", "Attack of the Vine!",
        "Hyperia City"
    ]

    /// Illumineer's Quest boxes: co-op boss decks played against the game itself. They're
    /// collectible, so they stay in the catalog, but they aren't legal in any sanctioned
    /// format — only Casual decks may include them.
    static let nonConstructedSets: Set<String> = [
        "Illumineer's Quest: Deep Trouble", "Illumineer's Quest: Palace Heist",
        "Illumineer's Quest: The Great Hunny Rescue"
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
