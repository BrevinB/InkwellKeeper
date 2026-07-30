//
//  PriceTrendShareView.swift
//  Inkwell Keeper
//
//  "Price trend" sharing: a branded snapshot of a card's market history — art,
//  current market price, the change over the charted window, and the trend
//  chart itself. Presented from the price history section on card detail.
//

import SwiftUI
import UIKit

// MARK: - Template

struct PriceTrendShareCardView: View {
    let card: LorcanaCard
    let points: [PricingService.RemotePricePoint]
    let image: UIImage?

    private var change: Double? {
        guard let first = points.first?.price, let last = points.last?.price, first > 0 else { return nil }
        return last - first
    }

    private var dateRange: String? {
        guard let first = points.first?.date, let last = points.last?.date else { return nil }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(first.formatted(format)) – \(last.formatted(format))"
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 96)
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(color: card.rarity.color.opacity(0.5), radius: 10)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(card.setName)
                        .font(.caption)
                        .foregroundStyle(.lorcanaGold)

                    HStack(spacing: 6) {
                        Text(card.rarity.displayName)
                        if card.variant != .normal {
                            Text("· \(card.variant.displayName)")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.gray)
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Market")
                        .font(.caption)
                        .foregroundStyle(.gray)

                    Spacer()

                    if let change {
                        PriceChangeBadge(change: change)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let last = points.last?.price {
                        Text(PricingService.formatPrice(last))
                            .font(.title)
                            .bold()
                            .foregroundStyle(.lorcanaGold)
                    }

                    if let dateRange {
                        Text(dateRange)
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PriceTrendChart(points: points)
                .frame(height: 150)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Presenter

struct PriceTrendShareView: View {
    let card: LorcanaCard
    let points: [PricingService.RemotePricePoint]

    @Environment(\.dismiss) private var dismiss
    @State private var artwork: UIImage?
    @State private var rendered: UIImage?
    @State private var shareURL: URL?
    @State private var isPreparing = true
    @State private var showShareSheet = false

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
                        ProgressView("Preparing your chart…")
                            .tint(.lorcanaGold)
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
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems) { completed in
                if completed { Analytics.send(.shareCompleted(type: "priceTrend")) }
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
        Analytics.send(.shareCardPresented(type: "priceTrend"))
        artwork = await ShareImageRenderer.loadImage(from: card.bestImageUrl())
        renderCard()
        isPreparing = false
    }

    @MainActor
    private func renderCard() {
        let composed = ShareCardChrome(
            qrPayload: AppLinks.cardQRPayload(id: card.id),
            tagline: "Every card's price, tracked daily"
        ) {
            PriceTrendShareCardView(card: card, points: points, image: artwork)
        }
        guard let image = ShareImageRenderer.render(composed) else { return }
        rendered = image
        shareURL = ShareImageRenderer.temporaryFileURL(for: image, name: "InkwellKeeper-\(card.name)-trend")
    }
}

// MARK: - Previews

private let previewCard = LorcanaCard(
    id: "WUN-241",
    name: "Buzz Lightyear - Jungle Ranger",
    cost: 7,
    type: "Character",
    rarity: .common,
    setName: "Wilds Unknown",
    imageUrl: "",
    variant: .normal,
    cardNumber: 241
)

private let previewPoints: [PricingService.RemotePricePoint] = {
    let start = Date(timeIntervalSince1970: 1_747_000_000)
    return (0..<60).map { day in
        PricingService.RemotePricePoint(
            date: start.addingTimeInterval(Double(day) * 86_400),
            price: 1200 + Double(day * day) * 0.66
        )
    }
}()

#Preview("Card Template") {
    ShareCardChrome(qrPayload: "https://apps.apple.com/app/inkwell-keeper") {
        PriceTrendShareCardView(card: previewCard, points: previewPoints, image: nil)
    }
}

#Preview("Share View") {
    PriceTrendShareView(card: previewCard, points: previewPoints)
}
