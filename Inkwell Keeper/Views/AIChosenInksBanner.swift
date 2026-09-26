//
//  AIChosenInksBanner.swift
//  Inkwell Keeper
//
//  Shows the inks the AI picked when the player left the ink picker empty,
//  with a shortcut to rebuild the deck in different inks.
//

import SwiftUI

struct AIChosenInksBanner: View {
    let inks: [InkColor]
    /// Nil when there are no other inks left to try.
    let onTryDifferentInks: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Label("AI picked your inks", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold)

                HStack(spacing: 10) {
                    ForEach(inks, id: \.self) { ink in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(ink.color)
                                .frame(width: 12, height: 12)
                            Text(ink.rawValue)
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            Spacer()

            if let onTryDifferentInks {
                Button("Try Different Inks", systemImage: "arrow.triangle.2.circlepath", action: onTryDifferentInks)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.lorcanaGold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
        .accessibilityElement(children: .contain)
        .padding(.horizontal)
    }
}
