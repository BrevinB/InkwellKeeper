//
//  StatsCardContainer.swift
//  Inkwell Keeper
//

import SwiftUI

/// Shared visual container that gives every stats card the same Lorcana dark/gold treatment.
struct StatsCardContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.lorcanaDark.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct StatsEmptyState: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.gray)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
    }
}
