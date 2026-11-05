//
//  PriceAlertTargetChart.swift
//  Inkwell Keeper
//
//  The card's recent price with the alert target drawn across it. The band
//  past the target shades the prices that would fire the alert, and dragging
//  anywhere on the chart moves the target.
//

import Charts
import SwiftUI

struct PriceAlertTargetChart: View {
    let points: [PricingService.RemotePricePoint]
    let threshold: Double
    let direction: PriceAlertDirection
    let onDrag: (Double) -> Void

    /// Held still while dragging, so the scale doesn't shift under the finger.
    @State private var frozenDomain: ClosedRange<Double>?

    private var fittedDomain: ClosedRange<Double> {
        let values = points.map(\.price) + [threshold]
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let padding = max((high - low) * 0.2, high * 0.08, 0.05)
        return max(0, low - padding)...(high + padding)
    }

    var body: some View {
        let domain = frozenDomain ?? fittedDomain
        let firstDate = points.first?.date ?? .now
        let lastDate = points.last?.date ?? .now

        Chart {
            RectangleMark(
                xStart: .value("Start", firstDate),
                xEnd: .value("End", lastDate),
                yStart: .value("Target", threshold),
                yEnd: .value("Edge", direction == .below ? domain.lowerBound : domain.upperBound)
            )
            .foregroundStyle(direction.tint.opacity(0.14))
            .accessibilityHidden(true)

            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Price", point.price)
                )
                .foregroundStyle(Color.lorcanaGold)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            if let latest = points.last {
                PointMark(
                    x: .value("Date", latest.date),
                    y: .value("Price", latest.price)
                )
                .foregroundStyle(Color.lorcanaGold)
                .symbolSize(50)
            }

            RuleMark(y: .value("Target", threshold))
                .foregroundStyle(direction.tint)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .annotation(
                    position: direction == .below ? .bottom : .top,
                    alignment: .leading,
                    spacing: 4,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    Label {
                        Text(threshold, format: .currency(code: "USD"))
                    } icon: {
                        Image(systemName: "bell.fill")
                    }
                    .font(.caption2.bold())
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(direction.tint, in: .capsule)
                }
                .accessibilityLabel("Alert target")
                .accessibilityValue(threshold.formatted(.currency(code: "USD")))
        }
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.gray)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .currency(code: "USD"))
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if frozenDomain == nil { frozenDomain = domain }
                                guard let plotFrame = proxy.plotFrame else { return }
                                let y = drag.location.y - geometry[plotFrame].minY
                                guard let price: Double = proxy.value(atY: y) else { return }
                                let held = frozenDomain ?? domain
                                onDrag(min(max(price, held.lowerBound), held.upperBound))
                            }
                            .onEnded { _ in
                                withAnimation(.snappy) { frozenDomain = nil }
                            }
                    )
            }
        }
    }
}
