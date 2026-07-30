//
//  PriceHistoryChartView.swift
//  Inkwell Keeper
//
//  Market price trend for a card's printing, fed by the pricing backend's
//  daily history. Foil cards chart the foil market; normals chart the
//  normal market.
//

import SwiftUI

struct PriceHistoryChartView: View {
    let card: LorcanaCard

    @State private var points: [PricingService.RemotePricePoint] = []
    @State private var isLoading = true
    @State private var showingShare = false

    private var change: Double? {
        guard let first = points.first?.price, let last = points.last?.price, first > 0 else { return nil }
        return last - first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Price History")
                    .font(.headline)
                    .foregroundStyle(Color.lorcanaGold)

                Spacer()

                if let change, points.count >= 2 {
                    PriceChangeBadge(change: change)
                }

                if points.count >= 2 {
                    Button("Share Trend", systemImage: "square.and.arrow.up") {
                        showingShare = true
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.lorcanaGold)
                }
            }

            if isLoading {
                ProgressView()
                    .tint(.lorcanaGold)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if points.count < 2 {
                Text("Not enough price history yet — daily tracking builds this out over time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                    .multilineTextAlignment(.center)
            } else {
                historyChart
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
        .task(id: card.variantAwareId) {
            isLoading = true
            let fetched = await PricingService.shared.fetchPriceHistory(for: card)
            guard !Task.isCancelled else { return }
            points = fetched
            isLoading = false
        }
        .sheet(isPresented: $showingShare) {
            PriceTrendShareView(card: card, points: points)
        }
    }

    private var historyChart: some View {
        PriceTrendChart(points: points)
            .frame(minHeight: 140, maxHeight: 200)
    }
}

/// Small green/red badge summarizing the price movement across the charted window.
struct PriceChangeBadge: View {
    let change: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text(abs(change), format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.caption)
                .bold()
        }
        .foregroundStyle(change >= 0 ? .green : .red)
        .accessibilityLabel(change >= 0 ? "Up" : "Down")
        .accessibilityValue(abs(change).formatted(.currency(code: "USD")))
    }
}
