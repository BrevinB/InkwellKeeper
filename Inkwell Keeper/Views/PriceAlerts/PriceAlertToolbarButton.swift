//
//  PriceAlertToolbarButton.swift
//  Inkwell Keeper
//
//  A bell in a card screen's toolbar, so a price alert is one tap away
//  without scrolling. Fills in once the card has an alert.
//

import SwiftData
import SwiftUI

struct PriceAlertToolbarButton: View {
    let card: LorcanaCard

    @Query private var alerts: [PriceAlert]
    @State private var editing: PriceAlertEditTarget?

    init(card: LorcanaCard) {
        self.card = card
        let cardId = card.id
        _alerts = Query(filter: #Predicate<PriceAlert> { $0.cardId == cardId }, sort: \.createdAt)
    }

    var body: some View {
        let target = PriceAlertEditTarget.forCard(card, alerts: alerts)
        Button(
            target.alert == nil ? "Set Price Alert" : "Edit Price Alert",
            systemImage: target.alert.map { $0.isTriggered ? "bell.badge.fill" : "bell.fill" } ?? "bell"
        ) {
            editing = target
        }
        .sheet(item: $editing) { target in
            PriceAlertEditorView(card: target.card, alert: target.alert)
        }
    }
}
