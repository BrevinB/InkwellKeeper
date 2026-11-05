//
//  PriceAlertOfferModifier.swift
//  Inkwell Keeper
//
//  Hosts the post-wishlist alert offer on a screen that adds to the wishlist:
//  a banner along the bottom that hides itself after a few seconds, and the
//  alert editor when it's taken up.
//

import SwiftUI

struct PriceAlertOfferModifier: ViewModifier {
    @Binding var card: LorcanaCard?
    @State private var editing: LorcanaCard?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let card {
                    PriceAlertOfferBanner(card: card, onAccept: accept, onDismiss: dismiss)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: card.variantAwareId) {
                            Analytics.send(.priceAlertOfferShown)
                            // An offer left alone counts as waved off.
                            try? await Task.sleep(for: .seconds(8))
                            guard !Task.isCancelled else { return }
                            dismiss()
                        }
                }
            }
            .animation(.snappy, value: card?.variantAwareId)
            .sheet(item: $editing) { card in
                PriceAlertEditorView(card: card, source: "wishlistOffer")
            }
    }

    private func accept() {
        PriceAlertService.shared.recordWishlistOffer(accepted: true)
        editing = card
        card = nil
    }

    private func dismiss() {
        guard card != nil else { return }
        PriceAlertService.shared.recordWishlistOffer(accepted: false)
        card = nil
    }
}

extension View {
    /// Offers a price alert on `card` after it's added to the wishlist. Set it
    /// from `PriceAlertService.wishlistOfferCandidate(_:)`.
    func priceAlertOffer(for card: Binding<LorcanaCard?>) -> some View {
        modifier(PriceAlertOfferModifier(card: card))
    }
}
