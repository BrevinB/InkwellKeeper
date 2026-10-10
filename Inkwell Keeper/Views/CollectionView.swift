//
//  CollectionView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CollectionView: View {
    @Environment(CollectionManager.self) var collectionManager
    @Environment(StorageManager.self) private var storageManager
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
    @State private var showingCardSearch = false
    @State private var showingSupportThanks = false
    @State private var supportThanksMessage = ""
    @State private var filteredCards: [LorcanaCard] = []
    @State private var showUnsortedOnly = false
    @State private var unsortedCount = 0
    @Namespace private var storageTransition

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    FilterBar(
                        selectedFilter: $selectedFilter,
                        selectedInkColor: $selectedInkColor,
                        selectedVariant: $selectedVariant,
                        sortOption: $sortOption
                    )
                    if !collectionManager.collectedCards.isEmpty {
                        StorageShelfView(
                            unsortedCount: unsortedCount,
                            showUnsortedOnly: $showUnsortedOnly,
                            transitionNamespace: storageTransition
                        )
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal)
                .background(Color.lorcanaDark.opacity(0.3))
                
                if filteredCards.isEmpty {
                    CollectionEmptyStateContent(
                        collectionIsEmpty: collectionManager.collectedCards.isEmpty,
                        searchIsEmpty: searchText.isEmpty,
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
            .navigationDestination(for: StorageRoute.self) { route in
                StorageContainerScreen(route: route)
                    .navigationTransition(.zoom(sourceID: route.container.id, in: storageTransition))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCardSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.lorcanaGold)
                    }
                    .accessibilityLabel("Search card catalog")
                    .keyboardShortcut("f", modifiers: .command)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingBulkImport = true }) {
                            Label("Bulk Import", systemImage: "square.and.arrow.down")
                        }
                        .keyboardShortcut("i", modifiers: [.command, .shift])
                        
                        Button(action: { showingExport = true }) {
                            Label("Export Collection", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        CollectionStatsButton()
                            .environment(collectionManager)
                        
                        Divider()
                        
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.lorcanaGold)
                    }
                }
            }
        }
        .onAppear {
            collectionManager.loadCollection()
            recomputeFilteredCards()
        }
        .onChange(of: searchText) { recomputeFilteredCards() }
        .onChange(of: selectedFilter) { recomputeFilteredCards() }
        .onChange(of: selectedInkColor) { recomputeFilteredCards() }
        .onChange(of: selectedVariant) { recomputeFilteredCards() }
        .onChange(of: sortOption) { recomputeFilteredCards() }
        .onChange(of: showUnsortedOnly) { recomputeFilteredCards() }
        .onChange(of: storageManager.storedQuantityByIdentity) { recomputeFilteredCards() }
        .onChange(of: collectionManager.collectedCards.count) { recomputeFilteredCards() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ImportCompleted"))) { notification in
            if let cardsCount = notification.userInfo?["cardsCount"] as? Int {
                supportThanksMessage = "Successfully imported \(cardsCount) cards!"
                showingSupportThanks = true
                
                // Auto-dismiss after 5 seconds
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation {
                        showingSupportThanks = false
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualAdd) {
            ManualAddCardView(isPresented: $showingManualAdd)
                .environment(collectionManager)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView()
                .environment(collectionManager)
        }
        .sheet(isPresented: $showingExport) {
            ExportView()
                .environment(collectionManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(collectionManager)
        }
        .sheet(isPresented: $showingCardSearch) {
            CardSearchView(isPresented: $showingCardSearch)
                .environment(collectionManager)
                .presentationSizing(.page)
        }
    }
    
    private func recomputeFilteredCards() {
        var cards = collectionManager.collectedCards

        let unsortedByIdentity = storageManager.unsortedQuantitiesByIdentity()
        unsortedCount = unsortedByIdentity.values.reduce(0, +)
        if showUnsortedOnly {
            cards = cards.filter { unsortedByIdentity[CollectionManager.identityKey(for: $0)] != nil }
        }
        
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
            cards.sort { $0.cost > $1.cost }
        case .rarity:
            cards.sort { $0.rarity.sortOrder > $1.rarity.sortOrder }
        case .set:
            let setOrder: [String: (Int, String)] = SetsDataManager.shared.sets.reduce(into: [:]) { dict, set in
                let numeric = Int(set.setNumber ?? "") ?? Int.max
                dict[set.name] = (numeric, set.releaseDate ?? "")
            }
            cards.sort { lhs, rhs in
                let lhsOrder = setOrder[lhs.setName] ?? (Int.max, "")
                let rhsOrder = setOrder[rhs.setName] ?? (Int.max, "")
                if lhsOrder.0 != rhsOrder.0 { return lhsOrder.0 < rhsOrder.0 }
                if lhsOrder.1 != rhsOrder.1 { return lhsOrder.1 < rhsOrder.1 }
                return lhs.setName < rhs.setName
            }
        case .price:
            cards.sort { $0.price ?? 0 > $1.price ?? 0}
        }
        
        filteredCards = cards
    }
}
