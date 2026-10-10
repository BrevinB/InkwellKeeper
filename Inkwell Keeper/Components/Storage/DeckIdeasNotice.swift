//
//  DeckIdeasNotice.swift
//  Inkwell Keeper
//
//  Shown once on the Decks list after decks became "ideas until built".
//

import SwiftUI

struct DeckIdeasNotice: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(.lorcanaGold)

            VStack(alignment: .leading, spacing: 4) {
                Text("Decks are ideas until you build them")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Text("Experiment freely — idea decks don't tie up your cards. When you sleeve one up, tap Build to give it a deck box and get a pull list of where every card is.")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }

            Spacer(minLength: 0)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.caption)
                .foregroundStyle(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lorcanaDark.opacity(0.9))
                .stroke(Color.lorcanaGold.opacity(0.4), lineWidth: 1)
        )
    }
}
