//
//  DeckBoxChecklist.swift
//  Inkwell Keeper
//
//  For a deck box linked to a deck: how much of the deck is in the box, and which
//  cards still need to go in.
//

import SwiftUI

struct DeckBoxChecklist: View {
    let deck: Deck
    let container: StorageContainer
    let onPull: () -> Void

    private struct Line: Identifiable {
        let id: String
        let name: String
        let missing: Int
    }

    var body: some View {
        let deckCards = deck.cards ?? []
        let inBox = Dictionary(grouping: container.items ?? []) { "\($0.name)||\($0.setName)" }
            .mapValues { rows in rows.reduce(0) { $0 + $1.quantity } }

        let lines: [Line] = deckCards.compactMap { card in
            let key = "\(card.name)||\(card.setName)"
            let missing = card.quantity - (inBox[key] ?? 0)
            return missing > 0 ? Line(id: key, name: card.name, missing: missing) : nil
        }
        let total = deckCards.reduce(0) { $0 + $1.quantity }
        let present = total - lines.reduce(0) { $0 + $1.missing }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(deck.name, systemImage: "rectangle.stack.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.white)
                Spacer()
                if lines.isEmpty {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            ProgressView(value: Double(present), total: Double(max(1, total))) {
                Text("\(present) of \(total) deck cards in this box")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .tint(lines.isEmpty ? .green : .lorcanaGold)

            if !lines.isEmpty {
                Button("Pull Cards", systemImage: "tray.and.arrow.down", action: onPull)
                    .font(.subheadline)
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(Color.lorcanaDark)
                    .tint(.lorcanaGold)
                DisclosureGroup("^[\(lines.count) card](inflect: true) still to pack") {
                    ForEach(lines) { line in
                        HStack {
                            Text(line.name)
                            Spacer()
                            Text("×\(line.missing)")
                                .monospacedDigit()
                                .foregroundStyle(.gray)
                        }
                        .font(.caption)
                    }
                }
                .font(.caption)
                .tint(.lorcanaGold)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.lorcanaDark.opacity(0.8))
                .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
        )
    }
}
