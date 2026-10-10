//
//  BuildDeckSheet.swift
//  Inkwell Keeper
//
//  Turns an idea deck into a built one: pick (or make) its deck box, then pull the
//  cards from wherever they are. Also opens straight to the pull list for decks
//  that are already built.
//

import SwiftUI

struct BuildDeckSheet: View {
    let deck: Deck

    @Environment(StorageManager.self) private var storageManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let box = storageManager.deckBox(for: deck.id) {
                    DeckPullListView(deck: deck, box: box)
                } else {
                    DeckBoxChooser(deck: deck)
                }
            }
            .background(LorcanaBackground())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.lorcanaGold)
    }
}
