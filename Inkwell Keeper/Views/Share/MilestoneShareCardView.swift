//
//  MilestoneShareCardView.swift
//  Inkwell Keeper
//
//  Share-card template celebrating a `ShareMilestone`. Presentation-only: all copy and
//  formatting come from the milestone model. Rendered off-screen by `ShareImageRenderer`.
//

import SwiftUI

struct MilestoneShareCardView: View {
    let milestone: ShareMilestone

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            Image(systemName: milestone.iconName)
                .font(.system(size: 64))
                .foregroundStyle(.lorcanaGold)
                .shadow(color: .lorcanaGold.opacity(0.5), radius: 16)

            Text(milestone.heroValue)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            VStack(spacing: 6) {
                Text(milestone.headline)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(.lorcanaGold)
                    .multilineTextAlignment(.center)

                Text(milestone.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
