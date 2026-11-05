//
//  PriceAlertCallout.swift
//  Inkwell Keeper
//
//  The price-alert entry point that sits right under a card's price, so
//  setting one doesn't depend on scrolling down to the price chart. Shows the
//  card's alert once there is one.
//

import SwiftData
import SwiftUI

struct PriceAlertCallout: View {
    let card: LorcanaCard

    @Query private var alerts: [PriceAlert]
    @State private var editing: PriceAlertEditTarget?

    init(card: LorcanaCard) {
        self.card = card
        let cardId = card.id
        _alerts = Query(filter: #Predicate<PriceAlert> { $0.cardId == cardId }, sort: \.createdAt)
    }

    private var alert: PriceAlert? {
        PriceAlertEditTarget.forCard(card, alerts: alerts, source: "callout").alert
    }

    var body: some View {
        Button {
            editing = PriceAlertEditTarget.forCard(card, alerts: alerts, source: "callout")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3)
                    .foregroundStyle(iconTint)
                    .symbolEffect(.bounce, value: alert?.isTriggered)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .lineLimit(2)
                }

                Spacer()

                Text(alert == nil ? "Set" : "Edit")
                    .font(.caption.bold())
                    .foregroundStyle(.lorcanaGold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.lorcanaGold.opacity(0.15), in: .capsule)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(item: $editing) { target in
            PriceAlertEditorView(card: target.card, alert: target.alert, source: target.source)
        }
    }

    private var iconName: String {
        guard let alert else { return "bell" }
        return alert.isTriggered ? "bell.badge.fill" : "bell.fill"
    }

    private var iconTint: Color {
        alert?.alertDirection.tint ?? .lorcanaGold
    }

    private var title: String {
        guard let alert else { return String(localized: "Price Alert") }
        let price = alert.threshold.formatted(.currency(code: "USD"))
        return switch alert.alertDirection {
        case .below: String(localized: "Alert when it drops to \(price)")
        case .above: String(localized: "Alert when it rises to \(price)")
        }
    }

    private var subtitle: String {
        guard let alert else { return String(localized: "Get a notification when the price drops or rises") }
        if let triggeredAt = alert.triggeredAt {
            let when = triggeredAt.formatted(.relative(presentation: .named))
            if let price = alert.triggeredPrice {
                return String(localized: "Hit \(price.formatted(.currency(code: "USD"))) \(when) · tap to re-arm")
            }
            return String(localized: "Triggered \(when) · tap to re-arm")
        }
        return alert.cardVariant == .normal
            ? String(localized: "Watching the market price")
            : String(localized: "Watching the \(alert.cardVariant.displayName.lowercased()) market price")
    }
}
