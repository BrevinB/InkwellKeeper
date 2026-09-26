//
//  AIDeckRuleCheckBanner.swift
//  Inkwell Keeper
//
//  Shows the deterministic rule audit for AI deck results: a green "legal" line, or the
//  specific rule breaks and deck-health warnings.
//

import SwiftUI

struct AIDeckRuleCheckBanner: View {
    let report: AIDeckRuleReport
    let format: DeckFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(headline)
                    .font(.subheadline)
                    .bold()
            } icon: {
                Image(systemName: report.isLegal ? "checkmark.seal.fill" : "xmark.octagon.fill")
            }
            .foregroundStyle(report.isLegal ? .green : .red)

            ForEach(report.violations, id: \.self) { violation in
                Label(violation, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            ForEach(report.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (report.isLegal ? Color.green : Color.red).opacity(0.1),
            in: .rect(cornerRadius: 10)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        if report.isLegal {
            return "Legal for \(format.rawValue) · \(report.inkableCards)/\(report.totalCards) inkable"
        }
        let count = report.violations.count
        return "\(count) rule issue\(count == 1 ? "" : "s") for \(format.rawValue)"
    }
}
