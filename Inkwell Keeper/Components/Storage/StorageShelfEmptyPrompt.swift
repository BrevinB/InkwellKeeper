//
//  StorageShelfEmptyPrompt.swift
//  Inkwell Keeper
//
//  First-run invitation on the shelf, before any container exists.
//

import SwiftUI

struct StorageShelfEmptyPrompt: View {
    let onCreate: () -> Void

    var body: some View {
        Button(action: onCreate) {
            HStack(spacing: 14) {
                HStack(alignment: .bottom, spacing: -10) {
                    ContainerArtwork(kind: .binder, color: .amethyst, style: .starlight)
                        .frame(height: 54)
                    ContainerArtwork(kind: .deckBox, color: .amber, style: .classic)
                        .frame(height: 40)
                    ContainerArtwork(kind: .trove, color: .sapphire, style: .leather)
                        .frame(height: 36)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Where are your cards?")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(.white)
                    Text("Add your binders, troves and boxes to find any card in seconds.")
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.lorcanaGold.opacity(0.7))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.lorcanaDark.opacity(0.8))
                    .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set up storage")
        .accessibilityHint("Add your binders, troves and boxes")
    }
}
