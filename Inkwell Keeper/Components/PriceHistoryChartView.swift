//
//  PriceHistoryChartView.swift
//  Inkwell Keeper
//
//  Market price trend for a card's printing, fed by the pricing backend's
//  daily history. Foil cards chart the foil market; normals chart the
//  normal market.
//

import SwiftUI
import Charts

struct PriceHistoryChartView: View {
    let card: LorcanaCard

    @State private var points: [PricingService.RemotePricePoint] = []
    @State private var isLoading = true

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
    }

    private var historyChart: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.price)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [Color.lorcanaGold.opacity(0.35), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.price)
            )
            .foregroundStyle(Color.lorcanaGold)
            .interpolationMethod(.monotone)
            .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(point.price.formatted(.currency(code: "USD")))
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.gray.opacity(0.2))
                AxisValueLabel(format: .currency(code: "USD").precision(.fractionLength(0)))
                    .foregroundStyle(.gray)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.gray)
            }
        }
        .frame(minHeight: 140, maxHeight: 200)
    }

    /// Pad the price range so the line doesn't hug the chart edges. Market
    /// trends don't need a zero baseline; the padded domain keeps small
    /// movements visible without exaggerating them.
    private var yDomain: ClosedRange<Double> {
        let prices = points.map(\.price)
        let low = prices.min() ?? 0
        let high = prices.max() ?? 1
        let pad = Swift.max((high - low) * 0.15, high * 0.05, 0.05)
        return Swift.max(0, low - pad)...(high + pad)
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
