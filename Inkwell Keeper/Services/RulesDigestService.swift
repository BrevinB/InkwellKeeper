//
//  RulesDigestService.swift
//  Inkwell Keeper
//
//  Fetches the Rules Assistant's comprehensive-rules digest from CloudKit so rulings can be
//  updated the day a new set ships, without an app release. Falls back to the digest bundled
//  in `RulesAssistantService` and works fully offline once a copy is cached.
//

import Foundation
import CloudKit

/// Loads the AI rules digest from the public CloudKit database.
///
/// Expected records (public database), published by `Scripts/publish_rules_digest.sh`:
/// - Record Type: `RulesDigest`
/// - Fields:
///   - `digest` (`String`) — the full system-prompt rules text
///   - `version` (`String`) — human-readable version for logging (e.g. "2026-07-30")
///
/// The newest record wins, so publishing an update is just creating a new record (cktool
/// can't edit records in place). Until any record exists, the bundled digest is used —
/// same behavior as `DeckRulesService`.
@MainActor
final class RulesDigestService {
    static let shared = RulesDigestService()

    private let recordType = "RulesDigest"
    private let cacheKey = "RulesDigestCachedText"
    private let cacheVersionKey = "RulesDigestCachedVersion"

    private init() {}

    /// The digest the assistant should use right now: the last remotely-fetched copy when one
    /// exists, otherwise the digest bundled with this app version.
    var currentDigest: String {
        if let cached = UserDefaults.standard.string(forKey: cacheKey), !cached.isEmpty {
            return cached
        }
        return RulesAssistantService.bundledRulesDigest
    }

    /// Fire-and-forget refresh suitable for app launch. Failures are non-fatal — the assistant
    /// keeps using the cached or bundled digest.
    func refresh() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            // A handful of records at most; pick the newest client-side so publishing
            // never has to delete or edit old ones.
            let (results, _) = try await database.records(matching: query, resultsLimit: 25)
            let records = results.compactMap { try? $0.1.get() }
            guard let newest = records.max(by: {
                ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
            }), let digest = newest["digest"] as? String, !digest.isEmpty else {
                print("[RulesDigest] No usable record; using cached/bundled digest.")
                return
            }

            UserDefaults.standard.set(digest, forKey: cacheKey)
            let version = newest["version"] as? String ?? "unversioned"
            UserDefaults.standard.set(version, forKey: cacheVersionKey)
            print("[RulesDigest] Applied remote digest (\(version)).")
        } catch {
            print("[RulesDigest] Using cached/bundled digest (\(error.localizedDescription)).")
        }
    }
}
