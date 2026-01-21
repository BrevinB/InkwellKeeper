//
//  CollectionView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @Binding var selectedTab: Int
    @State private var searchText = ""
    @State private var selectedFilter: CardFilter = .all
    @State private var selectedInkColor: InkColorFilter = .all
    @State private var selectedVariant: VariantFilter = .all
    @State private var sortOption: SortOption = .recentlyAdded
    @State private var showingManualAdd = false
    @State private var showingBulkImport = false
    @State private var showingExport = false
    @State private var showingSettings = false
    @State private var showingSupportThanks = false
    @State private var supportThanksMessage = ""
    
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

        // Filter by ink color
        if selectedInkColor != .all {
            cards = cards.filter { card in
                guard let inkColor = card.inkColor else { return false }
                // Handle dual-color cards (e.g., "Amber, Amethyst")
                let colors = inkColor.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return colors.contains(selectedInkColor.rawValue)
            }
        }

        // Filter by variant
        if selectedVariant != .all {
            cards = cards.filter { selectedVariant.matches($0.variant) }
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
                        selectedVariant: $selectedVariant,
                        sortOption: $sortOption
                    )
                }
                .padding(.horizontal)
                .background(Color.lorcanaDark.opacity(0.3))

                if filteredCards.isEmpty {
                    EmptyCollectionView(
                        showingManualAdd: $showingManualAdd,
                        showingBulkImport: $showingBulkImport,
                        onScanTapped: {
                            selectedTab = 1 // Switch to Scanner tab
                        },
                        searchQuery: searchText
                    )
                } else {
                    CardGridView(cards: filteredCards, isWishlist: false)
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingBulkImport = true }) {
                            Label("Bulk Import", systemImage: "square.and.arrow.down")
                        }

                        Button(action: { showingExport = true }) {
                            Label("Export Collection", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        CollectionStatsButton()
                            .environmentObject(collectionManager)

                        Divider()

                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))) { notification in
            if let cardsCount = notification.userInfo?["cardsCount"] as? Int {
                supportThanksMessage = "Successfully imported \(cardsCount) cards!"
                showingSupportThanks = true

                // Auto-dismiss after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showingSupportThanks = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualAdd) {
            ManualAddCardView(isPresented: $showingManualAdd)
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView()
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingExport) {
            ExportView()
                .environmentObject(collectionManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(collectionManager)
        }
    }

    @ViewBuilder
    private func navigationWrapper<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 18.0, *), UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad with iOS 18+, TabView handles navigation with sidebar
            content()
        } else {
            // On iPhone or older iOS, use NavigationView
            NavigationView {
                content()
            }
        }
    }
}
