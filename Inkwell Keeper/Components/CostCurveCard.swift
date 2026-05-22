//
//  CostCurveCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct CollectionCostCurveCard: View {
    let counts: [Int: Int]

    private var entries: [Entry] {
        (0...10).map { cost in
            Entry(cost: cost, count: counts[cost] ?? 0)
        }
    }

    private var hasData: Bool {
        entries.contains { $0.count > 0 }
    }

    var body: some View {
        StatsCardContainer(title: "Cost Curve", subtitle: "Distribution of ink costs across your collection") {
            if !hasData {
                StatsEmptyState(message: "Add cards to see your cost curve.")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Cost", entry.label),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(Color.lorcanaGold.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 180)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel().foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    private struct Entry: Identifiable {
        let cost: Int
        let count: Int
        var id: Int { cost }
        var label: String { cost >= 10 ? "10+" : "\(cost)" }
    }
}
