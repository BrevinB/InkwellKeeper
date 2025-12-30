//
//  WishlistView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct WishlistView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var showingAddToWishlist = false
    @State private var searchText = ""
    @State private var selectedFilter: CardFilter = .all
    @State private var selectedInkColor: InkColorFilter = .all
    @State private var sortOption: SortOption = .recentlyAdded

    private var filteredCards: [LorcanaCard] {
        var cards = collectionManager.wishlistCards

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

        // Filter by ink color
        if selectedInkColor != .all {
            cards = cards.filter { card in
                guard let inkColor = card.inkColor else { return false }
                let colors = inkColor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return colors.contains(selectedInkColor.rawValue)
            }
        }

        switch sortOption {
        case .recentlyAdded:
            cards = cards.sorted { card1, card2 in
                // Sort by dateAdded descending (most recent first)
                guard let date1 = card1.dateAdded, let date2 = card2.dateAdded else {
                    // Cards without dates go to the end
                    return card1.dateAdded != nil
                }
                return date1 > date2
            }
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
        navigationWrapper {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    FilterBar(
                        selectedFilter: $selectedFilter,
                        selectedInkColor: $selectedInkColor,
                        sortOption: $sortOption
                    )
                }
                .padding(.horizontal)
                .background(Color.lorcanaDark.opacity(0.3))

                if filteredCards.isEmpty {
                    EmptyWishlistView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredCards) { card in
                                WishlistCardRow(card: card)
                                    .environmentObject(collectionManager)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddToWishlist = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddToWishlist) {
            AddToWishlistView(isPresented: $showingAddToWishlist)
                .environmentObject(collectionManager)
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            content()
        } else {
            NavigationView {
                content()
            }
        }
    }
}
