//
//  ChartStoryline.swift
//  Inkwell Keeper
//
//  The caption under a value-history chart saying what happened in the window
//  ("Peaked at $4.20 on Sep 10 · 18% below that now").
//

import SwiftUI

struct ChartStoryline: View {
    let points: [PortfolioPoint]
    let formatValue: (Double) -> String

    var body: some View {
        if let line = ValueHistoryChartModel(points: points).storyline(formatValue: formatValue) {
            Label(line, systemImage: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
