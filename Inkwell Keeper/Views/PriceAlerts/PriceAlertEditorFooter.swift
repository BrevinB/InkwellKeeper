//
//  PriceAlertEditorFooter.swift
//  Inkwell Keeper
//
//  Spells out what the alert will do in plain words, warns when it would
//  fire straight away, and explains how often prices are checked.
//

import SwiftUI

struct PriceAlertEditorFooter: View {
    let model: PriceAlertEditorModel

    private var summary: String {
        let price = model.threshold.formatted(.currency(code: "USD"))
        return switch model.direction {
        case .below: String(localized: "You'll get a notification when \(model.displayName) drops to \(price) or lower.")
        case .above: String(localized: "You'll get a notification when \(model.displayName) rises to \(price) or higher.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.isValid {
                Label(summary, systemImage: "bell.badge")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            if model.isAlreadyCrossed {
                Label(
                    model.direction == .below
                        ? "It's already at or below this price, so the alert would fire at the next check."
                        : "It's already at or above this price, so the alert would fire at the next check.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            Text("Prices update once a day and alerts use the USD market price. You'll get one notification in the morning, then the alert pauses until you re-arm it.")
                .font(.footnote)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }
}
