//
//  CardSearchView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 3/10/26.
//

import SwiftUI

struct CardSearchView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var allCardGroups: [CardGroup] = []
    @State private var searchResults: [CardGroup] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCardGroupForAdd: CardGroup?
    @State private var selectedCardGroupForWishlist: CardGroup?

    private var displayedCards: [CardGroup] {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? allCardGroups : searchResults
    }

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText, placeholder: "Search all cards...")
                    .padding()
                    .onChange(of: searchText) { newValue in
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

                if displayedCards.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No cards found for '\(searchText)'")
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if displayedCards.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading cards...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(displayedCards, id: \.id) { cardGroup in
                        CardGroupSearchRow(cardGroup: cardGroup, onTap: {
                            selectedCardGroupForAdd = cardGroup
                        }, onWishlist: {
                            selectedCardGroupForWishlist = cardGroup
                        })
                        .swipeActions(edge: .trailing) {
                            Button {
                                selectedCardGroupForWishlist = cardGroup
                            } label: {
                                Label("Wishlist", systemImage: "star.fill")
                            }
                            .tint(.yellow)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Search All Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadAllCards()
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
                isWishlist: false,
                onAddToWishlist: { selectedCard, quantity in
                    for _ in 0..<quantity {
                        collectionManager.addToWishlist(selectedCard)
                    }
                    selectedCardGroupForAdd = nil
                }
            )
            .environmentObject(collectionManager)
        }
        .sheet(item: $selectedCardGroupForWishlist) { cardGroup in
            AddCardGroupModal(
                cardGroup: cardGroup,
                isPresented: Binding(
                    get: { selectedCardGroupForWishlist != nil },
                    set: { if !$0 { selectedCardGroupForWishlist = nil } }
                ),
                onAdd: { selectedCard, quantity in
                    for _ in 0..<quantity {
                        collectionManager.addToWishlist(selectedCard)
                    }
                    selectedCardGroupForWishlist = nil
                },
                isWishlist: true
            )
            .environmentObject(collectionManager)
        }
    }

    private func loadAllCards() {
        if allCardGroups.isEmpty {
            allCardGroups = dataManager.getAllCardGroups()
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
