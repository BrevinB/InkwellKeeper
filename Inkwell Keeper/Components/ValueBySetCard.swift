//
//  ValueBySetCard.swift
//  Inkwell Keeper
//

import SwiftUI
import Charts

struct ValueBySetCard: View {
    let valueBySet: [String: Double]

    private static let setShortNames: [String: String] = [
        "The First Chapter": "TFC",
        "Rise of the Floodborn": "ROF",
        "Into the Inklands": "ITI",
        "Ursula's Return": "URR",
        "Shimmering Skies": "SSK",
        "Azurite Sea": "AZS",
        "Archazia's Island": "ARI",
        "Reign of Jafar": "ROJ",
        "Fabled": "FAB",
        "Whispers in the Well": "WIW",
        "Winterspell": "WIN",
        "Wilds Unknown": "WU"
    ]

    private var entries: [Entry] {
        valueBySet
            .map { Entry(setName: $0.key, value: $0.value) }
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }
    }

    var body: some View {
        StatsCardContainer(
            title: "Value by Set",
            subtitle: "Which sets you've invested the most in"
        ) {
            if entries.isEmpty {
                StatsEmptyState(message: "No priced cards yet — refresh prices to populate this chart.")
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Value", entry.value),
                        y: .value("Set", shortName(for: entry.setName))
                    )
                    .foregroundStyle(Color.lorcanaGold.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(PricingService.formatPrice(entry.value))
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
                .frame(height: CGFloat(entries.count) * 30 + 16)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
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

    private func shortName(for setName: String) -> String {
        Self.setShortNames[setName] ?? setName
    }

    private struct Entry: Identifiable {
        let setName: String
        let value: Double
        var id: String { setName }
    }
}
