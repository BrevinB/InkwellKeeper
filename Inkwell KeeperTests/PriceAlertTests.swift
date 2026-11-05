//
//  PriceAlertTests.swift
//  Inkwell KeeperTests
//
//  Price-alert rules: default thresholds, the free limit, reconciling fires
//  reported by the backend, and the wire format the backend expects.
//

import Foundation
import SwiftData
import Testing
@testable import Inkwell_Keeper

@MainActor
struct PriceAlertTests {
    private func makeAlert(armedAt: Date = .now) -> PriceAlert {
        let alert = PriceAlert(
            cardId: "TFC_001_N",
            cardName: "Elsa - Snow Queen",
            setName: "The First Chapter",
            variant: .foil,
            priceKey: "TFC-1|foil",
            direction: .below,
            threshold: 40
        )
        alert.armedAt = armedAt
        return alert
    }

    // MARK: - Thresholds

    @Test func suggestionsSitTenPercentAwayOnARoundStep() {
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 45, direction: .below) == 40)
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 45, direction: .above) == 50)
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 3.10, direction: .below) == 2.75)
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 250, direction: .above) == 275)
    }

    @Test func belowSuggestionsNeverReachZero() {
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 0.04, direction: .below) == 0.05)
        #expect(PriceAlertRules.suggestedThreshold(currentPrice: 0, direction: .below) == 1)
    }

    @Test func presetsStepFurtherFromTodaysPrice() {
        let below = PriceAlertRules.presetDistances.map {
            PriceAlertRules.suggestedThreshold(currentPrice: 45, direction: .below, distance: $0)
        }
        let above = PriceAlertRules.presetDistances.map {
            PriceAlertRules.suggestedThreshold(currentPrice: 45, direction: .above, distance: $0)
        }
        #expect(below == [40, 36, 31])
        #expect(above == [50, 54, 59])
    }

    @Test func draggedThresholdsSnapToAPriceSizedStep() {
        #expect(abs(PriceAlertRules.snapped(41.4) - 41) < 0.001)
        #expect(abs(PriceAlertRules.snapped(3.13) - 3.25) < 0.001)
        #expect(abs(PriceAlertRules.snapped(0.42) - 0.40) < 0.001)
        #expect(abs(PriceAlertRules.snapped(0.001) - 0.05) < 0.001)
    }

    @Test func nudgesUseTheStepOfThePriceBeingLeft() {
        #expect(abs(PriceAlertRules.nudged(1, up: false) - 0.95) < 0.001)
        #expect(abs(PriceAlertRules.nudged(10, up: false) - 9.75) < 0.001)
        #expect(abs(PriceAlertRules.nudged(10, up: true) - 11) < 0.001)
        #expect(abs(PriceAlertRules.nudged(9.75, up: true) - 10) < 0.001)
        #expect(abs(PriceAlertRules.nudged(0.05, up: false) - 0.05) < 0.001)
    }

    @Test func measuresDistanceFromTodaysPrice() {
        #expect(abs((PriceAlertRules.distance(of: 36, from: 45) ?? 0) + 0.2) < 0.0001)
        #expect(PriceAlertRules.distance(of: 36, from: 0) == nil)
    }

    @Test func wishlistOffersStopForWatchedCardsAndAfterBeingIgnored() {
        #expect(PriceAlertRules.shouldOfferWishlistAlert(hasAlert: false, ignoredOffers: 0))
        #expect(PriceAlertRules.shouldOfferWishlistAlert(hasAlert: false, ignoredOffers: 2))
        #expect(!PriceAlertRules.shouldOfferWishlistAlert(hasAlert: false, ignoredOffers: 3))
        #expect(!PriceAlertRules.shouldOfferWishlistAlert(hasAlert: true, ignoredOffers: 0))
    }

    @Test func detectsThresholdsTheMarketHasAlreadyCrossed() {
        #expect(PriceAlertRules.isAlreadyCrossed(threshold: 50, direction: .below, currentPrice: 45))
        #expect(!PriceAlertRules.isAlreadyCrossed(threshold: 40, direction: .below, currentPrice: 45))
        #expect(PriceAlertRules.isAlreadyCrossed(threshold: 40, direction: .above, currentPrice: 45))
    }

    @Test func freeUsersGetThreeArmedAlerts() {
        #expect(PriceAlertRules.canCreateAlert(armedCount: 2, isSubscribed: false))
        #expect(!PriceAlertRules.canCreateAlert(armedCount: 3, isSubscribed: false))
        #expect(PriceAlertRules.canCreateAlert(armedCount: 300, isSubscribed: true))
    }

    // MARK: - Reconciling fires

    @Test func appliesFiresThatHappenedAfterArming() {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let alert = makeAlert(armedAt: armedAt)
        let fired = PriceAlertSync.FiredAlert(alertId: alert.alertId, triggeredAt: armedAt.addingTimeInterval(60), triggeredPrice: 38)

        #expect(PriceAlertRules.reconcile([alert], with: [fired]) == 1)
        #expect(alert.isTriggered)
        #expect(alert.triggeredPrice == 38)
    }

    /// The user re-armed on another device after the fire; that wins.
    @Test func ignoresFiresFromBeforeTheLatestArming() {
        let alert = makeAlert(armedAt: Date(timeIntervalSince1970: 2_000))
        let fired = PriceAlertSync.FiredAlert(alertId: alert.alertId, triggeredAt: Date(timeIntervalSince1970: 1_000), triggeredPrice: 38)

        #expect(PriceAlertRules.reconcile([alert], with: [fired]) == 0)
        #expect(!alert.isTriggered)
    }

    @Test func rearmingClearsTheFire() {
        let alert = makeAlert()
        alert.triggeredAt = .now
        alert.triggeredPrice = 38
        alert.rearm()
        #expect(!alert.isTriggered)
        #expect(alert.triggeredPrice == nil)
    }

    // MARK: - Wire format

    @Test func encodesTargetsInTheBackendsSnakeCase() throws {
        let alert = makeAlert(armedAt: Date(timeIntervalSince1970: 0))
        let data = try PriceAlertSync.encoder.encode(PriceAlertSync.Target(alert))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json["price_key"] as? String == "TFC-1|foil")
        #expect(json["card_name"] as? String == "Elsa - Snow Queen (Foil)")
        #expect(json["direction"] as? String == "below")
        #expect(json["armed_at"] as? String == "1970-01-01T00:00:00Z")
    }

    @Test func decodesTheDeviceResponse() throws {
        let body = #"{"is_pro": true, "free_target_limit": 3, "fired": [{"alert_id": "a", "triggered_at": 1700000000.5, "triggered_price": 12.5}]}"#
        let response = try PriceAlertSync.decoder.decode(PriceAlertSync.DeviceResponse.self, from: Data(body.utf8))

        #expect(response.isPro)
        #expect(response.fired.first?.triggeredAt == Date(timeIntervalSince1970: 1_700_000_000.5))
        #expect(response.fired.first?.triggeredPrice == 12.5)
    }

    // MARK: - Holdings

    @Test func holdingsMergeConditionsAndSkipTheWishlist() throws {
        let container = try ModelContainer(
            for: CollectedCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        func record(_ condition: String, quantity: Int, wishlisted: Bool = false) -> CollectedCard {
            let card = CollectedCard(
                cardId: "TFC_001_N", name: "Elsa", cost: 8, type: "Character", rarity: .legendary,
                setName: "The First Chapter", imageUrl: "", quantity: quantity, condition: condition,
                isWishlisted: wishlisted
            )
            context.insert(card)
            return card
        }
        let cards = [
            record("Near Mint", quantity: 2),
            record("Lightly Played", quantity: 1),
            record("Near Mint", quantity: 4, wishlisted: true)
        ]

        let holdings = PriceAlertSync.holdings(from: cards) { _ in "TFC-1" }

        #expect(holdings == [PriceAlertSync.Holding(priceKey: "TFC-1", cardId: "TFC_001_N", name: "Elsa", quantity: 3)])
    }

    @Test func holdingsSignatureIsStableAndChangesWithQuantity() {
        let one = [PriceAlertSync.Holding(priceKey: "TFC-1", cardId: "x", name: "Elsa", quantity: 1)]
        let two = [PriceAlertSync.Holding(priceKey: "TFC-1", cardId: "x", name: "Elsa", quantity: 2)]
        #expect(PriceAlertSync.signature(of: one) == PriceAlertSync.signature(of: one))
        #expect(PriceAlertSync.signature(of: one) != PriceAlertSync.signature(of: two))
    }
}
