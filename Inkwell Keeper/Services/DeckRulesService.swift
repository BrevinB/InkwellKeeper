//
//  DeckRulesService.swift
//  Inkwell Keeper
//
//  Fetches deck-construction rules (Core rotation + per-format banned lists) from CloudKit so they
//  can be updated without shipping an app release. Falls back to the baked-in defaults in
//  `LorcanaSetRegistry` and works fully offline.
//

import Foundation
import CloudKit

/// Loads deck rules from the public CloudKit database.
///
/// Expected record (public database):
/// - Record Type: `DeckRules`
/// - Record Name (ID): `deckRules`
/// - Fields (all `List<String>`):
///   - `coreLegalSets` — set names currently legal in Core Constructed
///   - `coreBannedCards` — full card names banned in Core Constructed
///   - `infinityBannedCards` — full card names banned in Infinity Constructed
///
/// Any field that is absent leaves the corresponding cached/default value unchanged.
final class DeckRulesService: Sendable {
    static let shared = DeckRulesService()

    private let recordName = "deckRules"

    private init() {}

    /// Fire-and-forget refresh suitable for app launch. Failures are non-fatal — the app keeps using
    /// the last cached values, or the baked-in defaults.
    func refresh() {
        Task { await refreshAsync() }
    }

    /// Fetches the rules record and applies any provided overrides to `LorcanaSetRegistry`.
    func refreshAsync() async {
        let database = CKContainer.default().publicCloudDatabase
        let recordID = CKRecord.ID(recordName: recordName)

        do {
            let record = try await database.record(for: recordID)
            LorcanaSetRegistry.applyOverrides(
                coreLegalSets: record["coreLegalSets"] as? [String],
                coreBannedCards: record["coreBannedCards"] as? [String],
                infinityBannedCards: record["infinityBannedCards"] as? [String]
            )
            print("[DeckRules] Applied CloudKit rule overrides.")
        } catch {
            print("[DeckRules] Using cached/default rules (\(error.localizedDescription)).")
        }
    }
}
