//
//  PriceAlertOfferBanner.swift
//  Inkwell Keeper
//
//  "Want to know when it gets cheaper?" — offered once a card lands on the
//  wishlist, since those are the cards people wait to buy.
//

import SwiftUI

struct PriceAlertOfferBanner: View {
    let card: LorcanaCard
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.badge")
                .font(.title3)
                .foregroundStyle(.lorcanaGold)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Want to know when it gets cheaper?")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text(card.name)
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button("Set Alert", action: onAccept)
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(.lorcanaGold)
                .foregroundStyle(.black)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.caption.bold())
                .foregroundStyle(.gray)
        }
        .padding(12)
        .background(.lorcanaDark.opacity(0.95), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.lorcanaGold.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .padding(.horizontal)
    }
}
