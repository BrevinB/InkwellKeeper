//
//  DeckBuildStatusBar.swift
//  Inkwell Keeper
//
//  Under a deck's summary: is this an idea (uses none of your cards) or built into a
//  deck box, and how much of it is in the box.
//

import SwiftUI

struct DeckBuildStatusBar: View {
    /// The deck's box when built; nil for an idea deck.
    let box: StorageContainer?
    let inBox: Int
    let total: Int
    let onBuild: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let box {
                ContainerArtwork(kind: .deckBox, color: box.coverColor, style: box.cover)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Built · \(box.name)")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                    Text(inBox >= total ? "All \(total) cards in the box" : "\(inBox) of \(total) cards in the box")
                        .font(.caption2)
                        .foregroundStyle(inBox >= total ? .green : .gray)
                        .monospacedDigit()
                }
                Spacer()
                Button(inBox >= total ? "View" : "Pull Cards", action: onBuild)
                    .font(.caption)
                    .buttonStyle(.bordered)
            } else {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.lorcanaGold)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Idea deck")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.white)
                    Text("Doesn't use your cards until you build it")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
                Spacer()
                Button("Build", systemImage: "shippingbox", action: onBuild)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(total == 0)
            }
        }
        .tint(.lorcanaGold)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25))
        .accessibilityElement(children: .combine)
    }
}
