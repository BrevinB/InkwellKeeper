//
//  TypeBreakdownCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct TypeBreakdownCard: View {
    let counts: [String: Int]

    private static let preferredOrder = ["Character", "Action", "Item", "Location", "Song"]

    private var entries: [Entry] {
        let sorted = counts
            .map { Entry(type: $0.key, count: $0.value) }
            .filter { $0.count > 0 }
        return sorted.sorted { lhs, rhs in
            let lhsIndex = Self.preferredOrder.firstIndex(of: lhs.type) ?? Self.preferredOrder.count
            let rhsIndex = Self.preferredOrder.firstIndex(of: rhs.type) ?? Self.preferredOrder.count
            if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
            return lhs.count > rhs.count
        }
    }

    private var totalCount: Int { entries.map(\.count).reduce(0, +) }

    var body: some View {
        StatsCardContainer(title: "Card Types", subtitle: "What kinds of cards you're collecting") {
            if entries.isEmpty {
                StatsEmptyState(message: "No card type data yet.")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Count", entry.count),
                        y: .value("Type", entry.type)
                    )
                    .foregroundStyle(color(for: entry.type).gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(percent(entry))
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(height: CGFloat(entries.count) * 36 + 16)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel().foregroundStyle(.gray)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel().foregroundStyle(.white)
                    }
                }
            }
        }
    }

    private func color(for type: String) -> Color {
        switch type {
        case "Character": return Color(red: 1.0, green: 0.55, blue: 0.0)
        case "Action": return Color(red: 0.45, green: 0.55, blue: 0.95)
        case "Item": return Color(red: 0.0, green: 0.7, blue: 0.55)
        case "Location": return Color(red: 0.85, green: 0.25, blue: 0.45)
        case "Song": return Color(red: 0.65, green: 0.4, blue: 0.85)
        default: return .gray
        }
    }

    private func percent(_ entry: Entry) -> String {
        guard totalCount > 0 else { return "" }
        let pct = Double(entry.count) / Double(totalCount) * 100
        return "\(entry.count) · \(Int(pct.rounded()))%"
    }

    private struct Entry: Identifiable {
        let type: String
        let count: Int
        var id: String { type }
    }
}
