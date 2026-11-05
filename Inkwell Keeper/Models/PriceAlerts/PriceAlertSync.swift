//
//  PriceAlertSync.swift
//  Inkwell Keeper
//
//  Wire format for the pricing backend's `/alerts` endpoints.
//

import CryptoKit
import Foundation

enum PriceAlertSync {
    struct DeviceRequest: Encodable, Sendable {
        let apnsToken: String?
        let apnsEnv: String
        let platform = "ios"
        let rcUserId: String?
        let timezone: String
        let moversEnabled: Bool
        let moveThresholdPct: Int
        let digestEnabled: Bool
        let targets: [Target]
    }

    struct Target: Encodable, Sendable {
        let alertId: String
        let priceKey: String
        let cardId: String
        let cardName: String
        let direction: String
        let threshold: Double
        let armedAt: Date
        let createdAt: Date

        init(_ alert: PriceAlert) {
            alertId = alert.alertId
            priceKey = alert.priceKey
            cardId = alert.cardId
            cardName = alert.displayName
            direction = alert.direction
            threshold = alert.threshold
            armedAt = alert.armedAt
            createdAt = alert.createdAt
        }
    }

    struct DeviceResponse: Decodable, Sendable {
        let isPro: Bool
        let freeTargetLimit: Int
        let fired: [FiredAlert]
    }

    struct FiredAlert: Decodable, Sendable {
        let alertId: String
        let triggeredAt: Date
        let triggeredPrice: Double?
    }

    struct HoldingsRequest: Encodable, Sendable {
        let holdings: [Holding]
    }

    struct Holding: Encodable, Sendable, Hashable {
        let priceKey: String
        let cardId: String
        let name: String
        let quantity: Int
    }

    struct TestResponse: Decodable, Sendable {
        let result: String
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // The backend sends fire times as epoch seconds.
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    /// The holdings the owned-card and digest alerts watch, one entry per
    /// printing with quantities summed across conditions.
    static func holdings(from cards: [CollectedCard], priceKey: (LorcanaCard) -> String) -> [Holding] {
        var merged: [String: Holding] = [:]
        for record in cards where !record.isWishlisted {
            let card = record.toLorcanaCard
            let key = priceKey(card)
            let name = PriceAlertRules.displayName(name: card.name, variant: card.variant)
            let quantity = max(record.quantity, 1) + (merged[key]?.quantity ?? 0)
            merged[key] = Holding(priceKey: key, cardId: card.id, name: name, quantity: quantity)
        }
        return merged.values.sorted { $0.priceKey < $1.priceKey }
    }

    /// Changes whenever the set of held printings or their quantities change,
    /// so holdings are only uploaded when there is something new to say.
    /// Stable across launches (unlike `Hasher`), since it is persisted.
    static func signature(of holdings: [Holding]) -> String {
        let text = holdings.map { "\($0.priceKey)=\($0.quantity)" }.joined(separator: ",")
        return SHA256.hash(data: Data(text.utf8)).map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
    }
}
