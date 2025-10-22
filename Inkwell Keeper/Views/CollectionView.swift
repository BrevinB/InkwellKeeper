//
//  CollectionView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var searchText = ""
    @State private var selectedFilter: CardFilter = .all
    @State private var sortOption: SortOption = .name
    
    private var filteredCards: [LorcanaCard] {
        var cards = collectionManager.collectedCards
        
        if !searchText.isEmpty {
            cards = cards.filter { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.cardText.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        switch selectedFilter {
        case .all:
            break
        case .character:
            cards = cards.filter { $0.type == "Character" }
        case .action:
            cards = cards.filter { $0.type == "Action" }
        case .item:
            cards = cards.filter { $0.type == "Item" }
        case .song:
            cards = cards.filter { $0.type == "Song" }
        }
        
        switch sortOption {
        case .name:
            cards = cards.sorted { $0.name < $1.name }
        case .cost:
            cards = cards.sorted { $0.cost < $1.cost }
        case .rarity:
            cards = cards.sorted { $0.rarity.sortOrder < $1.rarity.sortOrder }
        case .set:
            cards = cards.sorted { $0.setName < $1.setName }
        }
        
        return cards
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    FilterBar(selectedFilter: $selectedFilter, sortOption: $sortOption)
                }
                .padding(.horizontal)
                .background(Color.lorcanaDark.opacity(0.3))
                
                if filteredCards.isEmpty {
                    EmptyCollectionView()
                } else {
                    CardGridView(cards: filteredCards, isWishlist: false)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button("Refresh") {
                            collectionManager.loadCollection()
                        }
                        .foregroundColor(.lorcanaGold)
                        
                        Button("Clear") {
                            collectionManager.clearAllData()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task {
                                await collectionManager.refreshAllPrices()
                            }
                        }) {
                            Label("Refresh All Prices", systemImage: "arrow.clockwise")
                        }

                        CollectionStatsButton()
                            .environmentObject(collectionManager)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .onAppear {
            collectionManager.loadCollection()
        }
    }
}
