//
//  ValueHistoryChart.swift
//  Inkwell Keeper
//
//  A value over time — a card's market price or the whole collection's value.
//  Beyond the line itself it tells the story of the window: a dashed line at the
//  starting value (so you can see when it was up or down), the high and low
//  called out, and drag-to-scrub for the value on any day. The y-axis is scaled
//  to the data, with cents when the values are small.
//

import SwiftUI
import Charts

struct ValueHistoryChart: View {
    let points: [PortfolioPoint]
    let tint: Color
    let currencyCode: String
    /// Axes, the start line and the high/low labels. Off for the locked preview.
    var showsAxes = true
    /// Drag to scrub. Off for previews and share images.
    var isInteractive = true
    var lineWidth: CGFloat = 2

    @State private var selectedDate: Date?

    var body: some View {
        let model = ValueHistoryChartModel(points: points)
        let domain = model.yDomain
        let selected = isInteractive ? selectedDate.flatMap(model.nearest) : nil

        Chart {
            if showsAxes, let start = model.start {
                RuleMark(y: .value("Start", start.value))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .accessibilityHidden(true)
            }

            ForEach(model.points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Baseline", domain.lowerBound),
                    yEnd: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [tint.opacity(0.3), tint.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)
                .accessibilityHidden(true)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(tint)
                .lineStyle(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
                .accessibilityLabel(point.date.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(point.value.formatted(.currency(code: currencyCode)))
            }

            if let selected {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(tint)
                .symbolSize(70)
                .annotation(
                    position: .top,
                    spacing: 8,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    ChartSelectionCallout(point: selected, change: model.change(at: selected), currencyCode: currencyCode)
                }
            } else if showsAxes {
                ForEach(model.markedExtremes) { extreme in
                    PointMark(
                        x: .value("Date", extreme.point.date),
                        y: .value("Value", extreme.point.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(24)
                    .annotation(
                        position: extreme.kind == .high ? .top : .bottom,
                        spacing: 3,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        Text(extremeLabel(extreme))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .accessibilityLabel(extreme.kind == .high ? "High" : "Low")
                    .accessibilityValue(extreme.point.value.formatted(.currency(code: currencyCode)))
                }

                if let latest = model.latest {
                    PointMark(
                        x: .value("Date", latest.date),
                        y: .value("Value", latest.value)
                    )
                    .foregroundStyle(tint)
                    .symbolSize(40)
                    .accessibilityHidden(true)
                }
            }
        }
        .chartYScale(domain: domain)
        .chartXSelection(value: $selectedDate)
        .chartXAxis {
            if showsAxes {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(.gray)
                }
            }
        }
        .chartYAxis {
            if showsAxes {
                AxisMarks(position: .trailing, values: model.axisValues) { value in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currencyCode)
                                .precision(.fractionLength(model.axisFractionDigits)))
                                .foregroundStyle(.gray)
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.date)
    }

    private func extremeLabel(_ extreme: ValueHistoryChartModel.Extreme) -> String {
        let value = extreme.point.value.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
        return extreme.kind == .high ? String(localized: "High \(value)") : String(localized: "Low \(value)")
    }
}

#Preview("Under $1") {
    let start = Date.now.addingTimeInterval(-60 * 86_400)
    let values = [0.22, 0.24, 0.23, 0.31, 0.38, 0.35, 0.29, 0.27, 0.30, 0.28]
    ValueHistoryChart(
        points: values.enumerated().map { index, value in
            PortfolioPoint(date: start.addingTimeInterval(Double(index) * 6 * 86_400), value: value)
        },
        tint: .lorcanaGold,
        currencyCode: "USD"
    )
    .frame(height: 200)
    .padding()
    .background(Color.lorcanaDark)
}
