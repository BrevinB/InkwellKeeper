//
//  PackSetPickerView.swift
//  Inkwell Keeper
//
//  First step of the pack-opening flow: choose which set to open.
//

import SwiftUI

struct PackSetPickerView: View {
    let simulator: PackSimulator
    @ObservedObject private var setsManager = SetsDataManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PackDisclaimerCard()

                if !setsManager.isDataLoaded {
                    ProgressView("Loading sets…")
                        .tint(Color.lorcanaGold)
                        .foregroundStyle(.white)
                        .padding(.top, 60)
                } else {
                    ForEach(simulator.boosterSets) { set in
                        Button {
                            simulator.selectSet(set)
                        } label: {
                            PackSetRow(
                                set: set,
                                cardCount: setsManager.getLocalCardCount(for: set.name)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .scrollIndicators(.hidden)
    }
}

/// Reminder that this feature does not affect the real collection.
struct PackDisclaimerCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.lorcanaGold)

            Text("Just for fun! Cards you rip here are randomized and are **not** added to your collection.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)
        }
        .padding()
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
        )
    }
}

/// A single selectable set row.
struct PackSetRow: View {
    let set: LorcanaSet
    let cardCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(Color.lorcanaGold)
                .frame(width: 44, height: 44)
                .background(Color.lorcanaGold.opacity(0.12), in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(set.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(cardCount) cards")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.bold())
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding()
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 14))
    }
}
