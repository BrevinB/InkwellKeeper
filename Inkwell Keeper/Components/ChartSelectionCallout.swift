//
//  ChartSelectionCallout.swift
//  Inkwell Keeper
//
//  The bubble over a scrubbed point on a value-history chart: the date, the value
//  then, and how far that was from the start of the window.
//

import SwiftUI

struct ChartSelectionCallout: View {
    let point: PortfolioPoint
    let change: ValueHistoryChartModel.Change?
    let currencyCode: String

    var body: some View {
        VStack(spacing: 1) {
            Text(point.date, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2)
                .foregroundStyle(.gray)
            Text(point.value, format: .currency(code: currencyCode).precision(.fractionLength(2)))
                .font(.subheadline)
                .bold()
                .monospacedDigit()
                .foregroundStyle(.white)
            if let change, change.amount != 0 {
                HStack(spacing: 3) {
                    Text(change.amount, format: .currency(code: currencyCode).precision(.fractionLength(2)).sign(strategy: .always()))
                    if let percent = change.percent {
                        Text("(\(percent, format: .percent.precision(.fractionLength(1)).sign(strategy: .always())))")
                    }
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(change.amount > 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.lorcanaDark.opacity(0.95))
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }
}
