//
//  PaywallSupportingFeatures.swift
//  Inkwell Keeper
//
//  The rest of what Pro includes, listed compactly under the features the
//  current context leads with.
//

import SwiftUI

struct PaywallSupportingFeatures: View {
    let features: [PaywallFeature]

    private let columns = [GridItem(.adaptive(minimum: 150), alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Also included")
                .font(.caption)
                .foregroundStyle(Color.lorcanaGold)

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(features) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: feature.icon)
                            .font(.caption)
                            .foregroundStyle(Color.lorcanaGold.opacity(0.85))
                            .frame(width: 18)

                        Text(feature.title)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
