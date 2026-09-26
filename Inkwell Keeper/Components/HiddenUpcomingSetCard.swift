//
//  HiddenUpcomingSetCard.swift
//  Inkwell Keeper
//
//  Sets-tab tile for an upcoming set whose spoilers are still shielded. Shows only the set
//  name, release date and how many cards have been revealed so far — no art, no card names.
//

import SwiftUI

struct HiddenUpcomingSetCard: View {
    let set: LorcanaSet
    let revealedCardCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(set.name)
                        .font(.headline)
                        .bold()
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    UpcomingSetBadge(set: set)

                    Text("\(revealedCardCount) cards revealed so far")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }

                Spacer()

                VStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                        .foregroundStyle(.lorcanaGold)
                    Text("Spoilers hidden")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lorcanaGold.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    )
            )
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Asks before showing spoilers for this set")
    }
}
