//
//  PriceAlert.swift
//  Inkwell Keeper
//
//  A one-shot "tell me when this printing crosses $X" alert. Alerts sync
//  between the user's devices through iCloud; each device registers them with
//  the pricing backend under its own push token, which evaluates them daily.
//

import Foundation
import SwiftData

@Model
class PriceAlert {
    /// Shared with the backend, so a fire on any device can be matched back.
    var alertId: String = UUID().uuidString
    /// The catalog card's `LorcanaCard.id`, used to open it from a push.
    var cardId: String = ""
    var cardName: String = ""
    var setName: String = ""
    /// `CardVariant` raw value.
    var variant: String = CardVariant.normal.rawValue
    /// The backend's key for the printing ("TFC-1" / "TFC-1|foil").
    var priceKey: String = ""
    /// `PriceAlertDirection` raw value.
    var direction: String = PriceAlertDirection.below.rawValue
    var threshold: Double = 0
    var createdAt: Date = Date.now
    /// When the alert was last created, edited or re-armed. A fire reported by
    /// the backend only counts if it happened after this.
    var armedAt: Date = Date.now
    var triggeredAt: Date?
    var triggeredPrice: Double?

    init(
        cardId: String,
        cardName: String,
        setName: String,
        variant: CardVariant,
        priceKey: String,
        direction: PriceAlertDirection,
        threshold: Double
    ) {
        self.cardId = cardId
        self.cardName = cardName
        self.setName = setName
        self.variant = variant.rawValue
        self.priceKey = priceKey
        self.direction = direction.rawValue
        self.threshold = threshold
    }

    var alertDirection: PriceAlertDirection {
        get { PriceAlertDirection(rawValue: direction) ?? .below }
        set { direction = newValue.rawValue }
    }

    var cardVariant: CardVariant {
        CardVariant(rawValue: variant) ?? .normal
    }

    var isTriggered: Bool { triggeredAt != nil }

    /// "Elsa - Snow Queen (Foil)" — how pushes and lists name the printing.
    var displayName: String {
        PriceAlertRules.displayName(name: cardName, variant: cardVariant)
    }

    /// Arms the alert again after it fired or after its threshold changed.
    func rearm(now: Date = .now) {
        armedAt = now
        triggeredAt = nil
        triggeredPrice = nil
    }
}
