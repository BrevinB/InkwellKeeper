//
//  HaulShareView.swift
//  Inkwell Keeper
//
//  "Share your haul" sharing: a recap of a multi-scan session — how many cards were pulled,
//  their combined market value, and the standout "top pull". Contains the data snapshot, the
//  presentation-only template, and a dedicated presenter that fetches live prices, owns the
//  Include-prices toggle, and renders the card off-screen via `ShareImageRenderer`.
//

import SwiftUI
import UIKit

/// Immutable snapshot of a scan haul, built by `HaulShareView` once live prices resolve.
struct HaulShareData {
    let uniqueCards: Int
    let totalCards: Int
    /// Combined market value of the haul, or nil when no card is priced (or prices are hidden).
    let totalValue: Double?
    /// The standout card in the haul, surfaced as the hero "top pull".
    let topCard: TopCard?

    struct TopCard {
        let name: String
        let setName: String
        let rarity: CardRarity
        /// Market price of this card, or nil when unavailable / hidden.
        let price: Double?
    }
}

// MARK: - Template

struct HaulShareCardView: View {
    let data: HaulShareData
    /// Preloaded artwork for the top pull, if any.
    let topImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("My Haul")
                    .font(.title3)
                    .foregroundStyle(.white)
                Text("Just Scanned")
                    .font(.largeTitle)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
            }

            HStack(spacing: 10) {
                HaulStatTile(value: data.totalCards.formatted(.number), label: "Cards")
                HaulStatTile(value: data.uniqueCards.formatted(.number), label: "Unique")
                if let totalValue = data.totalValue {
                    HaulStatTile(value: PricingService.formatPrice(totalValue), label: "Value")
                }
            }

            if let top = data.topCard {
                TopPullRow(card: top, image: topImage)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One of the headline metric tiles (Cards / Unique / Value).
private struct HaulStatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .bold()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.lorcanaGold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 12))
    }
}

/// The hero "top pull": the most valuable (or rarest) card in the haul.
private struct TopPullRow: View {
    let card: HaulShareData.TopCard
    let image: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.06))
                        .aspectRatio(0.72, contentMode: .fit)
                }
            }
            .frame(width: 84)
            .clipShape(.rect(cornerRadius: 8))
            .shadow(color: card.rarity.color.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Label("Top Pull", systemImage: "crown.fill")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.lorcanaGold)

                Text(card.name)
                    .font(.headline)
                    .bold()
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Circle()
                        .fill(card.rarity.color)
                        .frame(width: 8, height: 8)
                    Text(card.rarity.displayName)
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)
                }

                if let price = card.price {
                    Text(PricingService.formatPrice(price))
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.lorcanaGold)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Presenter

struct HaulShareView: View {
    let entries: [ScannedCardEntry]

    @Environment(\.dismiss) private var dismiss
    @AppStorage("shareIncludePrices") private var includePrices = true

    /// Live market prices keyed by entry id, fetched once in `prepare()`.
    @State private var prices: [UUID: Double] = [:]
    @State private var topImage: UIImage?
    @State private var rendered: UIImage?
    @State private var shareURL: URL?
    @State private var isPreparing = true
    @State private var showShareSheet = false

    private let pricing = PricingService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 20) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 20))
                            .shadow(radius: 12, y: 6)
                            .padding(.horizontal, 32)
                    } else if isPreparing {
                        ProgressView("Preparing your haul…")
                            .tint(.lorcanaGold)
                    }

                    if !prices.isEmpty {
                        Toggle("Include prices", isOn: $includePrices)
                            .tint(.lorcanaGold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                    }

                    Button("Share", systemImage: "square.and.arrow.up") {
                        showShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.lorcanaGold)
                    .foregroundStyle(.black)
                    .disabled(rendered == nil)
                }
                .padding(.vertical, 24)
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await prepare() }
        .onChange(of: includePrices) { _, _ in renderCard() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems) { completed in
                if completed { Analytics.send(.shareCompleted(type: "haul")) }
            }
        }
    }

    private var shareItems: [Any] {
        if let shareURL { return [shareURL] }
        if let rendered { return [rendered] }
        return []
    }

    @MainActor
    private func prepare() async {
        Analytics.send(.shareCardPresented(type: "haul"))

        var fetched: [UUID: Double] = [:]
        for entry in entries {
            if let price = await pricing.getMarketPrice(for: entry.card) {
                fetched[entry.id] = price
            }
        }
        prices = fetched

        if let top = topEntry(using: fetched) {
            topImage = await ShareImageRenderer.loadImage(from: top.card.bestImageUrl())
        }

        renderCard()
        isPreparing = false
    }

    /// The card to feature: the most valuable, falling back to the rarest when nothing is priced.
    private func topEntry(using prices: [UUID: Double]) -> ScannedCardEntry? {
        if let mostValuable = entries
            .filter({ prices[$0.id] != nil })
            .max(by: { (prices[$0.id] ?? 0) < (prices[$1.id] ?? 0) }) {
            return mostValuable
        }
        return entries.max { $0.card.rarity.sortOrder < $1.card.rarity.sortOrder }
    }

    private func makeData() -> HaulShareData {
        let totalCards = entries.reduce(0) { $0 + $1.quantity }
        let showPrices = includePrices && !prices.isEmpty

        let total: Double? = showPrices
            ? entries.reduce(0.0) { sum, entry in sum + (prices[entry.id] ?? 0) * Double(entry.quantity) }
            : nil

        let top = topEntry(using: prices).map { entry in
            HaulShareData.TopCard(
                name: entry.card.name,
                setName: entry.card.setName,
                rarity: entry.card.rarity,
                price: showPrices ? prices[entry.id] : nil
            )
        }

        return HaulShareData(
            uniqueCards: entries.count,
            totalCards: totalCards,
            totalValue: total,
            topCard: top
        )
    }

    @MainActor
    private func renderCard() {
        let composed = ShareCardChrome(qrPayload: AppLinks.appStoreURLString) {
            HaulShareCardView(data: makeData(), topImage: topImage)
        }
        guard let image = ShareImageRenderer.render(composed) else { return }
        rendered = image
        shareURL = ShareImageRenderer.temporaryFileURL(for: image, name: "InkwellKeeper-Haul")
    }
}

// MARK: - Previews

private extension HaulShareData {
    static let preview = HaulShareData(
        uniqueCards: 5,
        totalCards: 12,
        totalValue: 47.99,
        topCard: HaulShareData.TopCard(
            name: "Elsa - Spirit of Winter",
            setName: "Archazia's Island",
            rarity: .legendary,
            price: 18.50
        )
    )

    static let previewNoPrice = HaulShareData(
        uniqueCards: 3,
        totalCards: 6,
        totalValue: nil,
        topCard: HaulShareData.TopCard(
            name: "Mickey Mouse - Brave Little Tailor",
            setName: "The First Chapter",
            rarity: .rare,
            price: nil
        )
    )
}

@MainActor
private func makePreviewEntries() -> [ScannedCardEntry] {
    [
        ScannedCardEntry(
            card: LorcanaCard(
                id: "ARI-001",
                name: "Elsa - Spirit of Winter",
                cost: 6,
                type: "Character",
                rarity: .legendary,
                setName: "Archazia's Island",
                imageUrl: "",
                price: 18.50,
                variant: .foil,
                cardNumber: 1
            ),
            quantity: 1,
            scannedAt: Date()
        ),
        ScannedCardEntry(
            card: LorcanaCard(
                id: "TFC-043",
                name: "Moana - Of Motunui",
                cost: 4,
                type: "Character",
                rarity: .superRare,
                setName: "Rise of the Floodborn",
                imageUrl: "",
                price: 3.75,
                variant: .foil,
                cardNumber: 7
            ),
            quantity: 2,
            scannedAt: Date(),
            variant: .foil
        ),
        ScannedCardEntry(
            card: LorcanaCard(
                id: "TFC-001",
                name: "Be Our Guest",
                cost: 3,
                type: "Action",
                rarity: .common,
                setName: "The First Chapter",
                imageUrl: "",
                price: 0.25,
                cardNumber: 32
            ),
            quantity: 3,
            scannedAt: Date()
        ),
    ]
}

#Preview("Haul Template") {
    HaulShareCardView(data: .preview, topImage: nil)
        .frame(width: 300, height: 400)
        .background(.black)
}

#Preview("Haul Template – No Prices") {
    HaulShareCardView(data: .previewNoPrice, topImage: nil)
        .frame(width: 300, height: 400)
        .background(.black)
}

#Preview("Share View") {
    HaulShareView(entries: makePreviewEntries())
}
