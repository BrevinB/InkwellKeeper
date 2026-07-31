//
//  AIConfigService.swift
//  Inkwell Keeper
//
//  Remote configuration for the AI features: which OpenAI models to use and the client-side
//  daily limits. Lives in CloudKit so models can be upgraded (and limits tuned) the day a
//  better/cheaper model ships, without an app release.
//

import Foundation
import CloudKit

/// Loads AI configuration from the public CloudKit database.
///
/// Expected records (public database), newest record wins — same publishing model as
/// `RulesDigestService`:
/// - Record Type: `AIConfig`
/// - Fields (all optional; absent fields keep the bundled defaults):
///   - `rulesModel` (`String`) — model for the Rules Assistant (default "gpt-4o")
///   - `deckModel` (`String`) — model for deck build/complete/strategy (default "gpt-4o-mini")
///   - `rulesDailyLimit` (`Int64`) — rules questions per day (default 50)
///   - `deckDailyLimit` (`Int64`) — deck/strategy generations per day (default 25)
@MainActor
final class AIConfigService {
    static let shared = AIConfigService()

    private let recordType = "AIConfig"

    // Bundled defaults, used until a remote record has been fetched.
    private static let defaultRulesModel = "gpt-4o"
    private static let defaultDeckModel = "gpt-4o-mini"
    private static let defaultRulesDailyLimit = 50
    private static let defaultDeckDailyLimit = 25

    private enum CacheKey {
        static let rulesModel = "AIConfigRulesModel"
        static let deckModel = "AIConfigDeckModel"
        static let rulesDailyLimit = "AIConfigRulesDailyLimit"
        static let deckDailyLimit = "AIConfigDeckDailyLimit"
    }

    private init() {}

    var rulesModel: String {
        cachedString(CacheKey.rulesModel) ?? Self.defaultRulesModel
    }

    var deckModel: String {
        cachedString(CacheKey.deckModel) ?? Self.defaultDeckModel
    }

    var rulesDailyLimit: Int {
        cachedInt(CacheKey.rulesDailyLimit) ?? Self.defaultRulesDailyLimit
    }

    var deckDailyLimit: Int {
        cachedInt(CacheKey.deckDailyLimit) ?? Self.defaultDeckDailyLimit
    }

    /// Fire-and-forget refresh suitable for app launch. Failures are non-fatal — the app
    /// keeps using the cached or bundled values.
    func refresh() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        let database = CKContainer.default().publicCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        do {
            let (results, _) = try await database.records(matching: query, resultsLimit: 25)
            let records = results.compactMap { try? $0.1.get() }
            guard let newest = records.max(by: {
                ($0.modificationDate ?? .distantPast) < ($1.modificationDate ?? .distantPast)
            }) else {
                print("[AIConfig] No record; using cached/bundled config.")
                return
            }

            let store = UserDefaults.standard
            if let model = newest["rulesModel"] as? String, !model.isEmpty {
                store.set(model, forKey: CacheKey.rulesModel)
            }
            if let model = newest["deckModel"] as? String, !model.isEmpty {
                store.set(model, forKey: CacheKey.deckModel)
            }
            if let limit = newest["rulesDailyLimit"] as? Int, limit > 0 {
                store.set(limit, forKey: CacheKey.rulesDailyLimit)
            }
            if let limit = newest["deckDailyLimit"] as? Int, limit > 0 {
                store.set(limit, forKey: CacheKey.deckDailyLimit)
            }
            print("[AIConfig] Applied remote config (rules: \(rulesModel), deck: \(deckModel)).")
        } catch {
            print("[AIConfig] Using cached/bundled config (\(error.localizedDescription)).")
        }
    }

    private func cachedString(_ key: String) -> String? {
        let value = UserDefaults.standard.string(forKey: key)
        return (value?.isEmpty ?? true) ? nil : value
    }

    private func cachedInt(_ key: String) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : nil
    }
}
