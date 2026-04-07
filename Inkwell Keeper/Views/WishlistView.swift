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
    @State private var selectedVariant: VariantFilter = .all
    @State private var sortOption: SortOption = .recentlyAdded
    @State private var filteredCards: [LorcanaCard] = []

    var body: some View {
        navigationWrapper {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    FilterBar(
                        selectedFilter: $selectedFilter,
                        selectedInkColor: $selectedInkColor,
                        selectedVariant: $selectedVariant,
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
        .onAppear { recomputeFilteredCards() }
        .onChange(of: searchText) { recomputeFilteredCards() }
        .onChange(of: selectedFilter) { recomputeFilteredCards() }
        .onChange(of: selectedInkColor) { recomputeFilteredCards() }
        .onChange(of: selectedVariant) { recomputeFilteredCards() }
        .onChange(of: sortOption) { recomputeFilteredCards() }
        .onChange(of: collectionManager.wishlistCards.count) { recomputeFilteredCards() }
        .sheet(isPresented: $showingAddToWishlist) {
            AddToWishlistView(isPresented: $showingAddToWishlist)
                .environmentObject(collectionManager)
        }
    }

    private func recomputeFilteredCards() {
        var cards = collectionManager.wishlistCards

        if !searchText.isEmpty {
            cards = cards.filter { card in
                card.name.localizedStandardContains(searchText) ||
                card.cardText.localizedStandardContains(searchText)
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

        if selectedInkColor != .all {
            cards = cards.filter { card in
                guard let inkColor = card.inkColor else { return false }
                let colors = inkColor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return colors.contains(selectedInkColor.rawValue)
            }
        }

        if selectedVariant != .all {
            cards = cards.filter { selectedVariant.matches($0.variant) }
        }

        switch sortOption {
        case .recentlyAdded:
            cards.sort { card1, card2 in
                guard let date1 = card1.dateAdded, let date2 = card2.dateAdded else {
                    return card1.dateAdded != nil
                }
                return date1 > date2
            }
        case .name:
            cards.sort { $0.name < $1.name }
        case .cost:
            cards.sort { $0.cost < $1.cost }
        case .rarity:
            cards.sort { $0.rarity.sortOrder < $1.rarity.sortOrder }
        case .set:
            cards.sort { $0.setName < $1.setName }
        }

        filteredCards = cards
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
