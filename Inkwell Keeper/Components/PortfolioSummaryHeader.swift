//
//  PortfolioSummaryHeader.swift
//  Inkwell Keeper
//
//  Current collection value and how far it has moved across the charted window.
//

import SwiftUI

struct PortfolioSummaryHeader: View {
    let summary: PortfolioSummary
    /// Start of the charted window. The badge covers the whole window while the
    /// card's subtitle covers the past week, so the window is named here rather
    /// than leaving two unlabelled numbers side by side.
    let since: Date?

    private var changeCaption: String? {
        guard let since else {
            return summary.percentChange.map {
                $0.formatted(.percent.precision(.fractionLength(1)))
            }
        }
        // A short range names the day ("since Oct 18"); a long one the month.
        let isRecent = Date.now.timeIntervalSince(since) < 45 * 86_400
        let month = since.formatted(isRecent ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).year())
        guard let percent = summary.percentChange else { return "since \(month)" }
        let formatted = (percent / 100).formatted(.percent.precision(.fractionLength(1)))
        return "\(formatted) since \(month)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(
                summary.currentValue,
                format: .currency(code: PricingService.preferredCurrency)
                    .precision(.fractionLength(2))
            )
            .font(.title2)
            .bold()
            .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                PriceChangeBadge(change: summary.change)
                if let changeCaption {
                    Text(changeCaption)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}
