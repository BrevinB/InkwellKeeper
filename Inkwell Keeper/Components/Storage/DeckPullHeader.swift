//
//  DeckPullHeader.swift
//  Inkwell Keeper
//
//  The deck box at the top of the pull list: its lid opens while cards are still
//  going in, it pops as each one lands, and a bar fills toward a complete deck.
//

import SwiftUI

struct DeckPullHeader: View {
    let box: StorageContainer
    let plan: DeckPullPlan
    let pulledCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            AnimatableContainerArtwork(container: box, lidLift: plan.isComplete || reduceMotion ? 0 : 0.7)
                .frame(height: 96)
                .modifier(PopEffect(trigger: pulledCount, isEnabled: !reduceMotion, peak: 1.12))
                .animation(.bouncy, value: plan.isComplete)

            Text(box.name)
                .font(.headline)
                .foregroundStyle(.white)

            ProgressView(value: Double(plan.inBox), total: Double(max(1, plan.total)))
                .tint(plan.isComplete ? .green : .lorcanaGold)
                .padding(.horizontal, 40)
                .animation(.snappy, value: plan.inBox)

            Text("\(plan.inBox) of \(plan.total) cards in the box")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.gray)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
