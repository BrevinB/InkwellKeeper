//
//  PortfolioValueChart.swift
//  Inkwell Keeper
//
//  The collection's value over time, plotted from PortfolioHistoryBuilder: green
//  when the window ends up, red when it ends down.
//

import SwiftUI

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

    var body: some View {
        ValueHistoryChart(
            points: points,
            tint: ValueHistoryChartModel(points: points).isUp ? .green : .red,
            currencyCode: PricingService.preferredCurrency,
            showsAxes: showsAxes,
            isInteractive: showsAxes,
            lineWidth: lineWidth
        )
        .frame(height: 180)
        .accessibilityLabel("Collection value over time")
    }
}
