//
//  PriceAlertEditorModel.swift
//  Inkwell Keeper
//
//  State and decisions for creating or editing one price alert.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class PriceAlertEditorModel {
    enum SaveOutcome: Equatable {
        case saved
        /// A free user is at the alert limit; the paywall should open.
        case needsPro
    }

    /// The printing being watched. Switches between normal and foil while a
    /// new alert is set up; fixed once the alert exists.
    private(set) var card: LorcanaCard
    let alert: PriceAlert?

    var direction: PriceAlertDirection {
        didSet { suggestThresholdIfUntouched() }
    }

    var threshold: Double
    /// Once the user picks a threshold, changing direction stops overwriting it.
    var hasEditedThreshold = false
    private(set) var history: [PricingService.RemotePricePoint] = []
    private(set) var currentPrice: Double?
    private(set) var isLoadingPrice = false

    init(card: LorcanaCard, alert: PriceAlert? = nil) {
        self.card = card
        self.alert = alert
        direction = alert?.alertDirection ?? .below
        threshold = alert?.threshold ?? 0
        hasEditedThreshold = alert != nil
    }

    var isEditing: Bool { alert != nil }

    var displayName: String {
        PriceAlertRules.displayName(name: card.name, variant: card.variant)
    }

    var isValid: Bool { threshold > 0 }

    var isAlreadyCrossed: Bool {
        guard let currentPrice, isValid else { return false }
        return PriceAlertRules.isAlreadyCrossed(threshold: threshold, direction: direction, currentPrice: currentPrice)
    }

    /// Normal and foil for a new alert on a printing that has both; nothing
    /// to choose for special printings or an existing alert.
    var variantChoices: [CardVariant] {
        guard !isEditing, card.variant == .normal || card.variant == .foil else { return [] }
        return [.normal, .foil]
    }

    func selectVariant(_ variant: CardVariant) async {
        guard variant != card.variant else { return }
        card = card.withVariant(variant)
        hasEditedThreshold = false
        await loadPriceHistory()
    }

    /// The threshold's distance from today's price, as a fraction.
    var distanceFromCurrent: Double? {
        currentPrice.flatMap { PriceAlertRules.distance(of: threshold, from: $0) }
    }

    /// Quick picks: 10/20/30% under today's price for a drop, over it for a
    /// rise. On cheap cards several round to the same price; only the first
    /// of those is offered.
    var presets: [(distance: Double, price: Double)] {
        guard let currentPrice else { return [] }
        var seen: Set<Double> = []
        return PriceAlertRules.presetDistances.compactMap { distance in
            let price = PriceAlertRules.suggestedThreshold(currentPrice: currentPrice, direction: direction, distance: distance)
            let cents = (price * 100).rounded()
            guard seen.insert(cents).inserted else { return nil }
            return (distance, price)
        }
    }

    /// The USD market history the backend evaluates against — the same
    /// selection as the price-history chart, not the user's display currency.
    /// Today's price is its latest point.
    func loadPriceHistory() async {
        isLoadingPrice = true
        let points = await PricingService.shared.fetchPriceHistory(for: card)
        history = points
        currentPrice = points.last?.price
        isLoadingPrice = false
        suggestThresholdIfUntouched()
    }

    func suggestThresholdIfUntouched() {
        guard !hasEditedThreshold, let currentPrice else { return }
        threshold = PriceAlertRules.suggestedThreshold(currentPrice: currentPrice, direction: direction)
    }

    /// Sets a threshold the user picked by preset, drag or typing.
    func setThreshold(_ value: Double, snapping: Bool = true) {
        threshold = snapping ? PriceAlertRules.snapped(value) : value
        hasEditedThreshold = true
    }

    func nudge(up: Bool) {
        setThreshold(PriceAlertRules.nudged(max(threshold, 0), up: up), snapping: false)
    }

    /// Whether saving would add an armed alert, which counts against the free limit.
    var addsArmedAlert: Bool {
        guard let alert else { return true }
        return alert.isTriggered
    }

    /// Free alerts left before this one is saved, or nil for Pro.
    func freeAlertsRemaining(armedCount: Int, isSubscribed: Bool) -> Int? {
        guard !isSubscribed else { return nil }
        return max(0, PriceAlertRules.freeAlertLimit - armedCount)
    }

    /// Creates or updates the alert. Any save re-arms it, since the user just
    /// confirmed what they want to hear about.
    func save(in context: ModelContext, armedCount: Int, isSubscribed: Bool) -> SaveOutcome {
        if addsArmedAlert,
           !PriceAlertRules.canCreateAlert(armedCount: armedCount, isSubscribed: isSubscribed) {
            Analytics.send(.priceAlertLimitHit)
            return .needsPro
        }

        let rounded = (threshold * 100).rounded() / 100
        if let alert {
            alert.alertDirection = direction
            alert.threshold = rounded
            alert.rearm()
        } else {
            let created = PriceAlert(
                cardId: card.id,
                cardName: card.name,
                setName: card.setName,
                variant: card.variant,
                priceKey: PricingService.shared.priceKey(for: card),
                direction: direction,
                threshold: rounded
            )
            context.insert(created)
            Analytics.send(.priceAlertCreated(direction: direction.rawValue, foil: card.variant != .normal))
        }
        try? context.save()
        return .saved
    }
}
