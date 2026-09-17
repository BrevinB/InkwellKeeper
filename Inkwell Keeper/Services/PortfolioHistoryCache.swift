//
//  PortfolioHistoryCache.swift
//  Inkwell Keeper
//
//  On-disk cache for the fetched price series, so opening Stats does not
//  re-fetch several hundred KB of history every time.
//
//  The series is cached rather than the summed value line: the per-card
//  readings (movers, window extremes, the foil split) are derived from the
//  same data, and caching only the total would leave them unavailable on a
//  cache hit.
//

import Foundation

struct PortfolioHistoryCache {
    /// A cached series is reused until the backend has published a new day of
    /// prices — the cron runs daily.
    static let maxAge: TimeInterval = 60 * 60 * 12

    private let fileURL: URL

    init(fileName: String = "portfolio-history.json") {
        fileURL = URL.cachesDirectory.appending(path: fileName)
    }

    private struct Payload: Codable {
        let signature: Int
        let savedAt: Date
        let series: [String: [PricingService.PortfolioPricePoint]]
    }

    func load(signature: Int) -> [String: [PricingService.PortfolioPricePoint]]? {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.signature == signature,
              Date.now.timeIntervalSince(payload.savedAt) < Self.maxAge else {
            return nil
        }
        return payload.series
    }

    func save(series: [String: [PricingService.PortfolioPricePoint]], signature: Int) {
        let payload = Payload(signature: signature, savedAt: .now, series: series)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
