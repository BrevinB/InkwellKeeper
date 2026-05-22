//
//  PricingInfoView.swift
//  Inkwell Keeper
//
//  Explains where collection pricing comes from and why some cards may not have data.
//

import SwiftUI

struct PricingInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    section(title: "Where prices come from") {
                        Text("Inkwell Keeper pulls live market data from Cardmarket — the largest Lorcana marketplace, used primarily in Europe. Prices are served by a backend we run that pre-aggregates Cardmarket listings, with a direct API fallback when a card isn't in the cache yet.")
                    }

                    section(title: "Why not TCGPlayer?") {
                        Text("TCGPlayer doesn't offer public API access for indie apps, so we can't pull their North American prices directly. We've intentionally avoided unreliable scraping and don't substitute prices from elsewhere. If TCGPlayer opens up access in the future, it'll be added as a source.")
                    }

                    section(title: "Why some cards show \u{201C}—\u{201D}") {
                        Text("If a card has no listings on Cardmarket — common for very new releases, certain promos, and obscure variants — Inkwell Keeper shows a dash instead of a price. We never fabricate or estimate a value; an empty result is more honest than a guess.")
                    }

                    section(title: "Work in progress") {
                        Text("Pricing coverage is improving with every update. If a card you own consistently shows no price, please report it from Settings → Report an Issue and we'll work to add coverage.")
                    }

                    section(title: "Refreshing prices") {
                        Text("Tap the refresh icon at the top of the Stats tab to re-fetch prices for every card in your collection. Refreshes are rate-limited so they may take a moment for large collections.")
                    }
                }
                .padding(20)
            }
            .background(LorcanaBackground())
            .navigationTitle("About Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("How collection value works", systemImage: "tag.fill")
                .font(.title3)
                .bold()
                .foregroundStyle(Color.lorcanaGold)
            Text("A quick rundown of where the numbers in your Stats tab come from — and why some cards don't have one.")
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder body: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            body()
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.lorcanaGold.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

#Preview {
    PricingInfoView()
}
