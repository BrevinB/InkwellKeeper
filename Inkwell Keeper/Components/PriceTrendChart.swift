//
//  PriceTrendChart.swift
//  Inkwell Keeper
//
//  Reusable market-price trend chart: gold line with a gradient fill over a
//  padded domain. Used by the card detail price history section and the
//  price trend share card.
//

import SwiftUI
import Charts

struct PriceTrendChart: View {
    let points: [PricingService.RemotePricePoint]

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                yStart: .value("Baseline", yDomain.lowerBound),
                yEnd: .value("Price", point.price)
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
        .chartPlotStyle { plot in
            plot.clipped()
        }
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
