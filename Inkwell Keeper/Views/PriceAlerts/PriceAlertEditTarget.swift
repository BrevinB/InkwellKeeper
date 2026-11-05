//
//  PriceAlertEditTarget.swift
//  Inkwell Keeper
//
//  The card and alert an editor sheet opens on.
//

import Foundation

struct PriceAlertEditTarget: Identifiable {
    let card: LorcanaCard
    let alert: PriceAlert?
    /// Where the editor is opened from, for analytics.
    var source: String

    var id: String { alert?.alertId ?? card.variantAwareId }

    /// Opens on the card's existing alert when there is one, so the user edits
    /// it rather than adding a duplicate. `alerts` should be the card's alerts;
    /// this printing's wins, else the other printing's — a collection screen
    /// showing normal and foil together should still find it.
    static func forCard(_ card: LorcanaCard, alerts: [PriceAlert], source: String) -> Self {
        let key = PricingService.shared.priceKey(for: card)
        guard let alert = alerts.first(where: { $0.priceKey == key }) ?? alerts.first(where: { $0.cardId == card.id }) else {
            return Self(card: card, alert: nil, source: source)
        }
        return Self(card: card.withVariant(alert.cardVariant), alert: alert, source: source)
    }
}
