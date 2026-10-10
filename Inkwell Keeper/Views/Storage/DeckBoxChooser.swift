//
//  DeckBoxChooser.swift
//  Inkwell Keeper
//
//  First step of building a deck: which deck box will hold it.
//

import SwiftUI

struct DeckBoxChooser: View {
    let deck: Deck

    @Environment(StorageManager.self) private var storageManager

    private var newBoxColor: StorageCoverColor {
        deck.deckInkColors.first.flatMap { StorageCoverColor(rawValue: $0.rawValue.lowercased()) } ?? .midnight
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    ContainerArtwork(kind: .deckBox, color: newBoxColor, style: .classic)
                        .frame(height: 110)
                        .modifier(SwayEffect(isEnabled: true, degrees: 8))
                    Text("Build \(deck.name)")
                        .font(.title3)
                        .bold()
                        .multilineTextAlignment(.center)
                    Text("Give the deck a box. You'll get a pull list showing where each card is — binder pages, boxes, or Unsorted — and check them off as you go.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    storageManager.createDeckBox(for: deck)
                    Analytics.send(.deckBuildStarted(newBox: true))
                } label: {
                    Label("New Deck Box", systemImage: "plus.rectangle.on.rectangle")
                        .foregroundStyle(.lorcanaGold)
                }
            } footer: {
                Text("Deck boxes that hold a deck don't count toward your free binder and box limit.")
            }
            .listRowBackground(Color.lorcanaDark.opacity(0.8))

            if !storageManager.availableDeckBoxes.isEmpty {
                Section("Use an Empty Deck Box") {
                    ForEach(storageManager.availableDeckBoxes) { box in
                        Button {
                            storageManager.link(box, to: deck)
                            Analytics.send(.deckBuildStarted(newBox: false))
                        } label: {
                            HStack(spacing: 12) {
                                ContainerArtwork(kind: box.kind, color: box.coverColor, style: box.cover)
                                    .frame(width: 36, height: 36)
                                VStack(alignment: .leading) {
                                    Text(box.name)
                                        .foregroundStyle(.white)
                                    Text("^[\(box.cardCount) card](inflect: true) inside")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.lorcanaDark.opacity(0.8))
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Build Deck")
        .navigationBarTitleDisplayMode(.inline)
    }
}
