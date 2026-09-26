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
/// Expected records (public database), newest record wins — same publishing model as
/// `RulesDigestService` and `AIConfigService`, so `Scripts/publish_deck_rules.sh` can publish
/// with `cktool` (which can't choose record names):
/// - Record Type: `DeckRules`
/// - Fields (all `List<String>`):
///   - `coreLegalSets` — set names currently legal in Core Constructed
///   - `coreBannedCards` — full card names banned in Core Constructed
///   - `infinityBannedCards` — full card names banned in Infinity Constructed
///
/// Any field that is absent leaves the corresponding cached/default value unchanged.
final class DeckRulesService {
    static let shared = DeckRulesService()

    private let recordType = "DeckRules"

    private init() {}

    /// Fire-and-forget refresh suitable for app launch. Failures are non-fatal — the app keeps using
    /// the last cached values, or the baked-in defaults.
    func refresh() {
        Task { await refreshAsync() }
    }

    /// Fetches the newest rules record and applies any provided overrides to `LorcanaSetRegistry`.
    func refreshAsync() async {
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 25)
            let records = results.compactMap { try? $0.1.get() }
            guard let newest = records.max(by: {
                ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
            }) else {
                print("[DeckRules] No record; using cached/default rules.")
                return
            }

            LorcanaSetRegistry.applyOverrides(
                coreLegalSets: newest["coreLegalSets"] as? [String],
                coreBannedCards: newest["coreBannedCards"] as? [String],
                infinityBannedCards: newest["infinityBannedCards"] as? [String]
            )
            print("[DeckRules] Applied CloudKit rule overrides.")
        } catch {
            print("[DeckRules] Using cached/default rules (\(error.localizedDescription)).")
        }
    }
}
