//
//  PortfolioProTeaser.swift
//  Inkwell Keeper
//
//  The locked state shared by the portfolio cards that have no chart of their
//  own to blur.
//

import SwiftUI

struct PortfolioProTeaser: View {
    let icon: String
    let headline: String
    let detail: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Color.lorcanaGold)

            Text(headline)
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)

            Button("Unlock with Pro", systemImage: "sparkles", action: onUnlock)
                .buttonStyle(.borderedProminent)
                .tint(.lorcanaGold)
                .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
