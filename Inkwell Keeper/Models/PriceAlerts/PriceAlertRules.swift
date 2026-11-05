//
//  PriceAlertRules.swift
//  Inkwell Keeper
//
//  The pure decisions behind price alerts — default thresholds, the free
//  tier's limit and reconciling fires reported by the backend — kept apart
//  from views and networking so they can be tested directly.
//

import Foundation

enum PriceAlertRules {
    /// Armed target alerts a free user may have; Pro is unlimited. The backend
    /// enforces the same number.
    static let freeAlertLimit = 3

    /// Percent moves the owned-card alert can be set to. Matches the backend.
    static let moveThresholds = [10, 20, 30]
    static let defaultMoveThreshold = 20

    /// How far from today's price a new alert starts.
    static let defaultDistance = 0.10

    /// The quick picks the editor offers, as distances from today's price.
    static let presetDistances = [0.10, 0.20, 0.30]

    /// "Elsa - Snow Queen (Foil)" — how pushes and lists name a printing.
    static func displayName(name: String, variant: CardVariant) -> String {
        variant == .normal ? name : "\(name) (\(variant.rawValue))"
    }

    static func canCreateAlert(armedCount: Int, isSubscribed: Bool) -> Bool {
        isSubscribed || armedCount < freeAlertLimit
    }

    /// A sensible starting threshold: 10% below (or above) the current price,
    /// rounded to a step that suits the price so it reads like a number a
    /// person would pick.
    static func suggestedThreshold(
        currentPrice: Double,
        direction: PriceAlertDirection,
        distance: Double = defaultDistance
    ) -> Double {
        guard currentPrice > 0 else { return 1 }
        let step = roundingStep(for: currentPrice)
        switch direction {
        case .below:
            let target = currentPrice * (1 - distance)
            return max(step, (target / step).rounded(.down) * step)
        case .above:
            let target = currentPrice * (1 + distance)
            return (target / step).rounded(.up) * step
        }
    }

    /// Rounds a dragged or nudged threshold to the step that suits its price,
    /// never letting it reach zero.
    static func snapped(_ value: Double) -> Double {
        let step = roundingStep(for: value)
        return max(step, (value / step).rounded() * step)
    }

    /// Moves a threshold one step up or down. Steps are sized for the price
    /// being left, so going down from $1 lands on $0.95 rather than $0.75.
    static func nudged(_ threshold: Double, up: Bool) -> Double {
        let step = up ? roundingStep(for: threshold) : roundingStep(for: threshold - 0.0001)
        let snappedValue = (threshold / step).rounded() * step
        return snapped(snappedValue + (up ? step : -step))
    }

    /// How far a threshold sits from today's price, as a fraction (-0.2 is 20% below).
    static func distance(of threshold: Double, from currentPrice: Double) -> Double? {
        guard currentPrice > 0, threshold > 0 else { return nil }
        return threshold / currentPrice - 1
    }

    static func roundingStep(for price: Double) -> Double {
        switch price {
        case ..<1: 0.05
        case ..<10: 0.25
        case ..<100: 1
        default: 5
        }
    }

    /// Whether the alert would fire on the very next check, which usually
    /// means the direction was picked the wrong way round.
    static func isAlreadyCrossed(threshold: Double, direction: PriceAlertDirection, currentPrice: Double) -> Bool {
        switch direction {
        case .below: currentPrice <= threshold
        case .above: currentPrice >= threshold
        }
    }

    /// Applies fires the backend reported to the local alerts. A fire only
    /// counts if it happened after the alert was last armed — otherwise the
    /// user re-armed it on another device since, and that wins.
    /// - Returns: How many alerts changed.
    @discardableResult
    static func reconcile(_ alerts: [PriceAlert], with fired: [PriceAlertSync.FiredAlert]) -> Int {
        let byId = Dictionary(fired.map { ($0.alertId, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = 0
        for alert in alerts where alert.triggeredAt == nil {
            guard let fire = byId[alert.alertId], fire.triggeredAt >= alert.armedAt else { continue }
            alert.triggeredAt = fire.triggeredAt
            alert.triggeredPrice = fire.triggeredPrice
            changed += 1
        }
        return changed
    }
}
