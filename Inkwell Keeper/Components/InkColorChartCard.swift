//
//  InkColorChartCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct InkColorChartCard: View {
    let counts: [String: Int]

    private static let canonicalOrder: [InkColorFilter] = [
        .amber, .amethyst, .emerald, .ruby, .sapphire, .steel
    ]

    private var entries: [Entry] {
        Self.canonicalOrder.compactMap { ink in
            let count = counts[ink.rawValue] ?? 0
            guard count > 0 else { return nil }
            return Entry(ink: ink, count: count)
        }
    }

    var body: some View {
        StatsCardContainer(title: "Ink Distribution", subtitle: "Cards owned per ink color") {
            if entries.isEmpty {
                StatsEmptyState(message: "No ink color data available.")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Ink", entry.ink.displayName),
                        y: .value("Count", entry.count)
                    )
                    .foregroundStyle(entry.ink.color)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text("\(entry.count)")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let name = value.as(String.self),
                               let ink = Self.canonicalOrder.first(where: { $0.displayName == name }) {
                                Image(systemName: ink.icon)
                                    .foregroundStyle(ink.color)
                            }
                        }
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
        let ink: InkColorFilter
        let count: Int
        var id: String { ink.rawValue }
    }
}
