//
//  OpeningHandView.swift
//  Inkwell Keeper
//
//  Deals sample opening hands from a deck so players can feel their curve before
//  sleeving up. Tap cards to set them aside for the one allowed mulligan.
//

import SwiftUI

struct OpeningHandView: View {
    let deck: Deck

    @Environment(\.dismiss) private var dismiss
    @State private var simulator: OpeningHandSimulator?
    @State private var selectedIndices: Set<Int> = []
    @State private var handID = 0
    @State private var viewingCard: LorcanaCard?

    var body: some View {
        NavigationStack {
            ZStack {
                LorcanaBackground()

                if let simulator {
                    VStack(spacing: 20) {
                        handGrid(simulator)

                        handSummary(simulator)

                        Spacer(minLength: 0)

                        actionButtons(simulator)
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "Not Enough Cards",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Add at least \(OpeningHandSimulator.handSize) cards to draw an opening hand.")
                    )
                }
            }
            .navigationTitle("Opening Hand")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.lorcanaGold)
                }
            }
        }
        .onAppear {
            if simulator == nil {
                simulator = OpeningHandSimulator(deckCards: deck.cards ?? [])
            }
        }
        .fullScreenCover(item: $viewingCard) { card in
            FullscreenCardViewer(card: card)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: handID)
    }

    private func handGrid(_ simulator: OpeningHandSimulator) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(Array(simulator.hand.enumerated()), id: \.offset) { index, card in
                let isSelected = selectedIndices.contains(index)
                Button {
                    if simulator.hasMulliganed {
                        viewingCard = card
                    } else if isSelected {
                        selectedIndices.remove(index)
                    } else {
                        selectedIndices.insert(index)
                    }
                } label: {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.lorcanaDark.opacity(0.8))
                            .aspectRatio(1468 / 2048, contentMode: .fit)
                    }
                    .clipShape(.rect(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.lorcanaGold : .clear, lineWidth: 3)
                    )
                    .opacity(isSelected ? 0.55 : 1)
                }
                .accessibilityLabel(isSelected ? "\(card.name), set aside for mulligan" : card.name)
            }
        }
        .id(handID)
    }

    private func handSummary(_ simulator: OpeningHandSimulator) -> some View {
        HStack(spacing: 16) {
            Label("\(simulator.inkableCount) inkable", systemImage: "drop.fill")
                .font(.caption)
                .foregroundStyle(.lorcanaGold)

            if !simulator.hasMulliganed {
                Text(selectedIndices.isEmpty
                     ? "Tap cards to set them aside, then alter your hand"
                     : "\(selectedIndices.count) set aside")
                    .font(.caption)
                    .foregroundStyle(.gray)
            } else {
                Text("Hand altered — tap a card to inspect it")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }

    private func actionButtons(_ simulator: OpeningHandSimulator) -> some View {
        VStack(spacing: 12) {
            if !simulator.hasMulliganed {
                Button {
                    self.simulator?.mulligan(indices: selectedIndices)
                    selectedIndices = []
                    handID += 1
                } label: {
                    Label("Alter Hand (\(selectedIndices.count))", systemImage: "arrow.triangle.2.circlepath")
                        .bold()
                        .foregroundStyle(selectedIndices.isEmpty ? .gray : .lorcanaDark)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIndices.isEmpty ? Color.gray.opacity(0.4) : Color.lorcanaGold)
                        )
                }
                .disabled(selectedIndices.isEmpty)
            }

            Button {
                self.simulator?.drawNewHand()
                selectedIndices = []
                handID += 1
            } label: {
                Label("New Hand", systemImage: "shuffle")
                    .foregroundStyle(.lorcanaGold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lorcanaGold, lineWidth: 2)
                    )
            }
        }
    }
}
