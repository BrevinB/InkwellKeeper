//
//  StarterDecksView.swift
//  Inkwell Keeper
//
//  View for browsing and importing starter decks
//

import SwiftUI

struct StarterDecksView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var deckManager: DeckManager
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var starterDeckManager = StarterDeckManager.shared
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var selectedDeckForImport: StarterDeck?
    @State private var importedDeck: Deck?
    @State private var unmatchedCards: [String] = []
    @State private var showingImportResult = false
    @State private var addedToCollectionCount = 0
    @State private var importMode: ImportMode = .deckOnly

    enum ImportMode {
        case deckOnly
        case collectionOnly
        case both
    }

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                if starterDeckManager.isLoading {
                    ProgressView()
                        .tint(.lorcanaGold)
                } else if let error = starterDeckManager.errorMessage {
                    ErrorView(message: error)
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            VStack(spacing: 8) {
                                Text("Starter Decks")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)

                                Text("Import official starter decks into your collection")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top)

                            // Group by set
                            let decksBySet = starterDeckManager.getStarterDecksBySet()
                            let sortedSets = decksBySet.keys.sorted()

                            ForEach(sortedSets, id: \.self) { setName in
                                if let decks = decksBySet[setName] {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(setName)
                                            .font(.headline)
                                            .foregroundColor(.lorcanaGold)
                                            .padding(.horizontal)

                                        ForEach(decks) { deck in
                                            StarterDeckCard(deck: deck) {
                                                selectedDeckForImport = deck
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Starter Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.lorcanaGold)
                }
            }
        }
        .sheet(item: $selectedDeckForImport) { deck in
            ImportOptionsSheet(
                deck: deck,
                onImport: { mode in
                    importMode = mode
                    performImport(deck, mode: mode)
                    selectedDeckForImport = nil
                },
                onCancel: {
                    selectedDeckForImport = nil
                }
            )
        }
        .sheet(isPresented: $showingImportResult) {
            ImportResultView(
                deck: importedDeck,
                unmatchedCards: unmatchedCards,
                addedToCollectionCount: addedToCollectionCount,
                importMode: importMode,
                onDismiss: { showingImportResult = false }
            )
        }
    }

    private func performImport(_ starterDeck: StarterDeck, mode: ImportMode) {
        switch mode {
        case .deckOnly:
            let result = starterDeckManager.importStarterDeck(
                starterDeck,
                deckManager: deckManager,
                dataManager: dataManager,
                collectionManager: nil,
                addToCollection: false
            )
            importedDeck = result.deck
            unmatchedCards = result.unmatchedCards
            addedToCollectionCount = 0

        case .collectionOnly:
            let result = starterDeckManager.importCardsToCollection(
                starterDeck,
                collectionManager: collectionManager,
                dataManager: dataManager
            )
            importedDeck = nil
            unmatchedCards = result.unmatchedCards
            addedToCollectionCount = result.addedCount

        case .both:
            let result = starterDeckManager.importStarterDeck(
                starterDeck,
                deckManager: deckManager,
                dataManager: dataManager,
                collectionManager: collectionManager,
                addToCollection: true
            )
            importedDeck = result.deck
            unmatchedCards = result.unmatchedCards
            addedToCollectionCount = result.addedToCollection
        }

        showingImportResult = true
    }
}

// MARK: - Starter Deck Card
struct StarterDeckCard: View {
    let deck: StarterDeck
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(deck.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }

                Spacer()
            }

            // Deck info
            HStack(spacing: 16) {
                // Ink colors
                HStack(spacing: 4) {
                    ForEach(deck.deckInkColors, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                Text("\(deck.totalCards) cards")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: onImport) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Import")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.lorcanaDark)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.lorcanaGold)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal)
    }
}

// MARK: - Import Options Sheet
struct ImportOptionsSheet: View {
    let deck: StarterDeck
    let onImport: (StarterDecksView.ImportMode) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.down.right.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.lorcanaGold)

                        Text("Import \"\(deck.name)\"")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("\(deck.totalCards) cards")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)

                    // Options
                    VStack(spacing: 16) {
                        ImportOptionButton(
                            icon: "rectangle.stack.fill",
                            title: "Deck Only",
                            description: "Create a deck list to track completion",
                            action: { onImport(.deckOnly) }
                        )

                        ImportOptionButton(
                            icon: "square.grid.3x3.fill",
                            title: "Collection Only",
                            description: "Add cards to your collection",
                            action: { onImport(.collectionOnly) }
                        )

                        ImportOptionButton(
                            icon: "square.stack.3d.up.fill",
                            title: "Both",
                            description: "Create deck and add cards to collection",
                            action: { onImport(.both) }
                        )
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Import Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.lorcanaGold)
                }
            }
        }
    }
}

// MARK: - Import Option Button
struct ImportOptionButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.lorcanaGold)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Import Result View
struct ImportResultView: View {
    let deck: Deck?
    let unmatchedCards: [String]
    let addedToCollectionCount: Int
    let importMode: StarterDecksView.ImportMode
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                LorcanaBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Success icon
                        Image(systemName: unmatchedCards.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(unmatchedCards.isEmpty ? .green : .orange)
                            .padding(.top, 40)

                        // Message
                        VStack(spacing: 8) {
                            Text(unmatchedCards.isEmpty ? "Import Complete!" : "Import Complete with Warnings")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)

                            // Mode-specific messages
                            switch importMode {
                            case .deckOnly:
                                if let deck = deck {
                                    Text("\"\(deck.name)\" has been added to your decks")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)

                                    Text("\(deck.totalCards) cards in deck")
                                        .font(.caption)
                                        .foregroundColor(.lorcanaGold)
                                        .padding(.top, 4)
                                }

                            case .collectionOnly:
                                Text("\(addedToCollectionCount) cards added to collection")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)

                            case .both:
                                if let deck = deck {
                                    Text("\"\(deck.name)\" created")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)

                                    HStack(spacing: 20) {
                                        VStack {
                                            Text("\(deck.totalCards)")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.lorcanaGold)
                                            Text("Deck Cards")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }

                                        VStack {
                                            Text("\(addedToCollectionCount)")
                                                .font(.title3)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                            Text("In Collection")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }

                        // Unmatched cards warning
                        if !unmatchedCards.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("Some Cards Not Found")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }

                                Text("The following cards could not be matched and were skipped:")
                                    .font(.caption)
                                    .foregroundColor(.gray)

                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(unmatchedCards, id: \.self) { cardName in
                                        Text("• \(cardName)")
                                            .font(.caption)
                                            .foregroundColor(.orange.opacity(0.9))
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal)
                        }

                        // Done button
                        Button(action: onDismiss) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.lorcanaDark)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.lorcanaGold)
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                    }
                    .padding()
                }
            }
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Error Loading Starter Decks")
                .font(.headline)
                .foregroundColor(.white)

            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
