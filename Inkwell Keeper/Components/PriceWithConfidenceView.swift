//
//  PriceWithConfidenceView.swift
//  Inkwell Keeper
//
//  Displays card price with confidence indicator
//

import SwiftUI

/// Displays a price with a confidence indicator badge
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
        HStack(spacing: 4) {
            Text("$\(price, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.lorcanaGold)
                .fontWeight(.semibold)

            if confidence == .estimated {
                Text("EST")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(confidenceColor)
                    )
            }
        }
    }

    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("$\(price, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)

                confidenceBadge
            }

            if confidence == .estimated {
                Text("Based on algorithmic estimation")
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .italic()
            } else {
                Text(confidence.description)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
    }

    private var confidenceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: confidenceIcon)
                .font(.caption2)
            Text(confidence.rawValue.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(confidenceColor)
        )
    }

    private var confidenceIcon: String {
        switch confidence {
        case .high:
            return "checkmark.circle.fill"
        case .medium:
            return "chart.bar.fill"
        case .low:
            return "exclamationmark.triangle.fill"
        case .estimated:
            return "function"
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        case .estimated:
            return .gray
        }
    }
}

/// Simple price display that fetches confidence data and displays it
struct AsyncPriceWithConfidenceView: View {
    let card: LorcanaCard
    let style: PriceWithConfidenceView.DisplayStyle

    private let pricingService = PricingService.shared
    @State private var price: Double?
    @State private var confidence: PricingService.PriceConfidence = .estimated
    @State private var isLoading = true

    var body: some View {
        Group {
            if let price = price {
                PriceWithConfidenceView(price: price, confidence: confidence, style: style)
            } else if isLoading {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else {
                Text("Price unavailable")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .task {
            await loadPrice()
        }
    }

    private func loadPrice() async {
        let result = await pricingService.getPriceWithConfidence(for: card)
        await MainActor.run {
            self.price = result.price
            self.confidence = result.confidence
            self.isLoading = false
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // High confidence
        PriceWithConfidenceView(
            price: 24.99,
            confidence: .high,
            style: .inline
        )

        PriceWithConfidenceView(
            price: 24.99,
            confidence: .high,
            style: .detailed
        )

        // Estimated
        PriceWithConfidenceView(
            price: 3.50,
            confidence: .estimated,
            style: .inline
        )

        PriceWithConfidenceView(
            price: 3.50,
            confidence: .estimated,
            style: .detailed
        )
    }
    .padding()
    .background(Color.black)
}
