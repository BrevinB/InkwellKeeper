//
//  PortfolioValueChart.swift
//  Inkwell Keeper
//
//  The collection's value over time, plotted from PortfolioHistoryBuilder.
//

import SwiftUI
import Charts

struct PortfolioValueChart: View {
    let points: [PortfolioPoint]
    /// Axes are dropped for the locked preview, where the shape is the point
    /// and the figures are what unlocking buys.
    var showsAxes = true
    /// The locked preview draws a heavier line: it is dimmed and lightly
    /// blurred there, and a hairline stroke disappears entirely under that,
    /// leaving only the area fill — which reads as a smudge rather than data.
    var lineWidth: CGFloat = 2

    init(points: [PortfolioPoint], showsAxes: Bool = true, lineWidth: CGFloat = 2) {
        self.points = points
        self.showsAxes = showsAxes
        self.lineWidth = lineWidth
    }

    private var isUp: Bool {
        guard let first = points.first?.value, let last = points.last?.value else { return true }
        return last >= first
    }

    private var lineStyle: Color { isUp ? .green : .red }

    var body: some View {
        Chart(points) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(
                .linearGradient(
                    colors: [lineStyle.opacity(0.35), lineStyle.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(lineStyle)
            .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.monotone)
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            if showsAxes {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.gray)
                }
            }
        }
        .chartYAxis {
            if showsAxes {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: PricingService.preferredCurrency)
                                .precision(.fractionLength(0)))
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Collection value over time")
    }
}
