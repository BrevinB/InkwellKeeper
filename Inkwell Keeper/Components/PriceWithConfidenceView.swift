//
//  PriceWithConfidenceView.swift
//  Inkwell Keeper
//
//  Displays card price with a confidence indicator.
//  Cards without real market data render an "unavailable" placeholder
//  rather than an estimated value.
//

import SwiftUI

/// Displays a price with a confidence indicator badge.
struct PriceWithConfidenceView: View {
    let price: Double
    let confidence: PricingService.PriceConfidence
    let style: DisplayStyle

    enum DisplayStyle {
        case inline       // Small, for card tiles
        case detailed     // Larger, for detail views
    }

    var body: some View {
        switch style {
        case .inline:
            inlineView
        case .detailed:
            detailedView
        }
    }

    private var inlineView: some View {
        Text(PricingService.formatPrice(price))
            .font(.caption)
            .foregroundStyle(Color.lorcanaGold)
            .bold()
    }

    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(PricingService.formatPrice(price))
                    .font(.headline)
                    .foregroundStyle(Color.lorcanaGold)

                confidenceBadge
            }

            Text(confidence.description)
                .font(.caption2)
                .foregroundStyle(.gray)
        }
    }

    private var confidenceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: confidenceIcon)
                .font(.caption2)
            Text(confidence.rawValue.uppercased())
                .font(.caption2)
                .bold()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(confidenceColor))
    }

    private var confidenceIcon: String {
        switch confidence {
        case .high: return "checkmark.circle.fill"
        case .medium: return "chart.bar.fill"
        case .low: return "exclamationmark.triangle.fill"
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
}

/// Compact "price unavailable" placeholder for when no provider returned market data.
struct PriceUnavailableView: View {
    let style: PriceWithConfidenceView.DisplayStyle

    var body: some View {
        switch style {
        case .inline:
            Text("—")
                .font(.caption)
                .foregroundStyle(.gray)
        case .detailed:
            VStack(alignment: .leading, spacing: 4) {
                Text("No price available")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                Text("Market data couldn't be retrieved for this card.")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.8))
            }
        }
    }
}

/// Async wrapper that fetches the price with confidence and renders the appropriate state.
struct AsyncPriceWithConfidenceView: View {
    let card: LorcanaCard
    let style: PriceWithConfidenceView.DisplayStyle

    @State private var result: (price: Double, confidence: PricingService.PriceConfidence)?
    @State private var isLoading = true

    private let pricingService = PricingService.shared

    var body: some View {
        Group {
            if let result {
                PriceWithConfidenceView(price: result.price, confidence: result.confidence, style: style)
            } else if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading…")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            } else {
                PriceUnavailableView(style: style)
            }
        }
        .task {
            let fetched = await pricingService.getPriceWithConfidence(for: card)
            await MainActor.run {
                self.result = fetched
                self.isLoading = false
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PriceWithConfidenceView(price: 24.99, confidence: .high, style: .inline)
        PriceWithConfidenceView(price: 24.99, confidence: .high, style: .detailed)
        PriceUnavailableView(style: .inline)
        PriceUnavailableView(style: .detailed)
    }
    .padding()
    .background(Color.black)
}
