//
//  SpoilerPlaceholderRow.swift
//  Inkwell Keeper
//
//  Stand-in for a search result from an upcoming set: no art, no name — just the set and its
//  release date. Tapping reveals that one card.
//

import SwiftUI

struct SpoilerPlaceholderRow: View {
    let card: LorcanaCard
    var thumbnailWidth: CGFloat = 50

    private var releaseDate: String? {
        SetsDataManager.shared.getSet(byName: card.setName)?.releaseDateFormatted
    }

    var body: some View {
        Button {
            withAnimation {
                SpoilerSettings.shared.reveal(card)
            }
        } label: {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.lorcanaDark)
                    .overlay {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.lorcanaGold)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
                    }
                    .frame(width: thumbnailWidth, height: thumbnailWidth * 1.4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Spoiler from \(card.setName)")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if let releaseDate {
                        Text("Releases \(releaseDate)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Text("Tap to reveal")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(.lorcanaGold)
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hidden spoiler from \(card.setName)")
        .accessibilityHint("Reveals this card")
    }
}
