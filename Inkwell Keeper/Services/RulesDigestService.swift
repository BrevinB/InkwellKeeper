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
/// Expected record (public database):
/// - Record Type: `RulesDigest`
/// - Record Name (ID): `rulesDigest`
/// - Fields:
///   - `digest` (`String`) — the full system-prompt rules text
///   - `version` (`String`, optional) — human-readable version for logging (e.g. "2026-07-30")
///
/// Until the record exists, the bundled digest is used — same behavior as `DeckRulesService`.
@MainActor
final class RulesDigestService {
    static let shared = RulesDigestService()

    private let recordName = "rulesDigest"
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
        let recordID = CKRecord.ID(recordName: recordName)

        do {
            let record = try await database.record(for: recordID)
            guard let digest = record["digest"] as? String, !digest.isEmpty else {
                print("[RulesDigest] Record found but no digest field; using cached/bundled.")
                return
            }
            UserDefaults.standard.set(digest, forKey: cacheKey)
            let version = record["version"] as? String ?? "unversioned"
            UserDefaults.standard.set(version, forKey: cacheVersionKey)
            print("[RulesDigest] Applied remote digest (\(version)).")
        } catch {
            print("[RulesDigest] Using cached/bundled digest (\(error.localizedDescription)).")
        }
    }
}
