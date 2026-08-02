//
//  CoconutLeaderImageService.swift
//  Inkwell Keeper
//
//  Fetches official card images for the digital-only Format [Coconut] leaders from the
//  Lorcast API's "[Coconut]" set. Lorcast is ingesting the leaders gradually (they're
//  previewed weekly during the beta), so this refreshes at launch and caches what it
//  finds — images appear in the leader picker automatically as they become available.
//

import Foundation

@MainActor
final class CoconutLeaderImageService {
    static let shared = CoconutLeaderImageService()

    private let endpoint = URL(string: "https://api.lorcast.com/v0/sets/%5BCoconut%5D/cards")!
    private let cacheKey = "CoconutLeaderImageURLs"

    private init() {}

    /// Image URL for a leader, if Lorcast has ingested its card yet.
    func imageURL(for leader: CoconutLeader) -> URL? {
        let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String]
        return cached?[leader.name].flatMap { URL(string: $0) }
    }

    /// Fire-and-forget refresh suitable for app launch. Failures are non-fatal — the
    /// picker simply shows leaders without card art until images are available.
    func refresh() {
        Task { await refreshAsync() }
    }

    func refreshAsync() async {
        do {
            let (data, _) = try await URLSession.shared.data(from: endpoint)
            let cards = try JSONDecoder().decode([LorcastCoconutCard].self, from: data)

            let entries = cards.compactMap { card -> (fullName: String, imageUrl: String)? in
                guard let url = card.imageUris?.digital?.large else { return nil }
                let fullName = card.version.map { "\(card.name) - \($0)" } ?? card.name
                return (fullName, url)
            }
            let matched = Self.matchImages(apiCards: entries)
            guard !matched.isEmpty else { return }

            // Merge over the existing cache so a partial API response never loses images.
            var cache = (UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String]) ?? [:]
            cache.merge(matched) { _, new in new }
            UserDefaults.standard.set(cache, forKey: cacheKey)
            print("[CoconutImages] Cached \(cache.count)/\(CoconutLeaders.all.count) leader images.")
        } catch {
            print("[CoconutImages] Using cached images (\(error.localizedDescription)).")
        }
    }

    /// Matches API card names to leader names, dash/case-insensitively (leader data uses
    /// en dashes, the API uses hyphens). Pure for testability.
    static func matchImages(apiCards: [(fullName: String, imageUrl: String)]) -> [String: String] {
        let leadersByNormalizedName = Dictionary(
            CoconutLeaders.all.map { (DeckFormat.normalizeCardName($0.name), $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        var result: [String: String] = [:]
        for card in apiCards {
            let normalized = DeckFormat.normalizeCardName(card.fullName)
            if let leaderName = leadersByNormalizedName[normalized] {
                result[leaderName] = card.imageUrl
            }
        }
        return result
    }
}

/// Minimal Lorcast card shape for the Coconut set endpoint.
private struct LorcastCoconutCard: Decodable {
    let name: String
    let version: String?
    let imageUris: ImageUris?

    enum CodingKeys: String, CodingKey {
        case name
        case version
        case imageUris = "image_uris"
    }

    struct ImageUris: Decodable {
        let digital: Digital?

        struct Digital: Decodable {
            let large: String?
        }
    }
}
