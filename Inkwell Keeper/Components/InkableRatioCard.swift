//
//  InkableRatioCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct InkableRatioCard: View {
    let inkable: Int
    let nonInkable: Int

    private var total: Int { inkable + nonInkable }

    private var entries: [Entry] {
        [
            Entry(category: "Inkable", count: inkable, color: Color.lorcanaGold),
            Entry(category: "Non-Inkable", count: nonInkable, color: Color.gray.opacity(0.6))
        ].filter { $0.count > 0 }
    }

    var body: some View {
        StatsCardContainer(title: "Inkable Ratio", subtitle: "How much of your collection is inkable") {
            if total == 0 {
                StatsEmptyState(message: "Inkable data isn't available for these cards yet.")
            } else {
                HStack(alignment: .center, spacing: 16) {
                    Chart(entries) { entry in
                        SectorMark(
                            angle: .value("Count", entry.count),
                            innerRadius: .ratio(0.6),
                            angularInset: 1.5
                        )
                        .foregroundStyle(entry.color)
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 120, height: 120)
                    .overlay {
                        VStack(spacing: 2) {
                            Text(inkablePercentText)
                                .font(.title3)
                                .bold()
                                .foregroundStyle(.white)
                            Text("inkable")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(entry.color)
                                    .frame(width: 10, height: 10)
                                Text(entry.category)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Spacer(minLength: 8)
                                Text("\(entry.count)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
    }

    private var inkablePercentText: String {
        guard total > 0 else { return "—" }
        let pct = Double(inkable) / Double(total) * 100
        return "\(Int(pct.rounded()))%"
    }

    private struct Entry: Identifiable {
        let category: String
        let count: Int
        let color: Color
        var id: String { category }
    }
}
