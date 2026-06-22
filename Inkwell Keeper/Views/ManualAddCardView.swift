//
//  ManualAddCardView.swift
//  Inkwell Keeper
//

import SwiftUI

struct ManualAddCardView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [CardGroup] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCardGroupForAdd: CardGroup?

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 200_000_000)
                            if !Task.isCancelled {
                                await MainActor.run {
                                    searchCards(query: newValue)
                                }
                            }
                        }
                    }

                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No cards found for '\(searchText)'")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Search for Lorcana cards")
                            .foregroundColor(.gray)
                        Text("Try searching for character names, types, or sets")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.id) { cardGroup in
                        CardGroupSearchRow(cardGroup: cardGroup) {
                            selectedCardGroupForAdd = cardGroup
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .sheet(item: $selectedCardGroupForAdd) { cardGroup in
            AddCardGroupModal(
                cardGroup: cardGroup,
                isPresented: Binding(
                    get: { selectedCardGroupForAdd != nil },
                    set: { if !$0 { selectedCardGroupForAdd = nil } }
                ),
                onAdd: { selectedCard, quantity in
                    for _ in 0..<quantity {
                        collectionManager.addCard(selectedCard)
                    }
                    selectedCardGroupForAdd = nil
                },
                isWishlist: false
            )
            .environmentObject(collectionManager)
        }
    }

    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        let results = dataManager.searchCardGroups(query: query)

        if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query {
            self.searchResults = results
        }
    }
}
