//
//  PriceAlertRow.swift
//  Inkwell Keeper
//
//  One alert in the price-alert list.
//

import SwiftUI

struct PriceAlertRow: View {
    let alert: PriceAlert

    var body: some View {
        HStack {
            Image(systemName: alert.alertDirection.systemImage)
                .foregroundStyle(alert.alertDirection.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(alert.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text(alert.setName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text("\(alert.alertDirection.title) \(alert.threshold.formatted(.currency(code: "USD")))")
                    .font(.subheadline)
                    .foregroundStyle(Color.lorcanaGold)
                if let triggeredAt = alert.triggeredAt {
                    Group {
                        if let price = alert.triggeredPrice {
                            Text("Hit \(price.formatted(.currency(code: "USD"))) · \(triggeredAt.formatted(.relative(presentation: .named)))")
                        } else {
                            Text("Triggered \(triggeredAt.formatted(.relative(presentation: .named)))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
