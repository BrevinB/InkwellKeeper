//
//  SetDetailView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/14/25.
//

import SwiftUI

struct SetDetailView: View {
    let set: LorcanaSet
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var cards: [LorcanaCard] = []
    @State private var selectedCard: LorcanaCard?
    @State private var selectedCardGroupForAdd: CardGroup?
    @State private var showFilterOptions = false
    @State private var filterOption: FilterOption = .all
    @State private var searchText = ""
    @State private var isBulkSelectMode = false
    @State private var selectedCardIds: Set<String> = []
    @State private var showBulkAddConfirmation = false
    @State private var showQuickAddBanner = false
    @State private var quickAddCardName = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var gridHelper: AdaptiveGridHelper {
        AdaptiveGridHelper(horizontalSizeClass: horizontalSizeClass)
    }

    private var missingCards: [LorcanaCard] {
        cards.filter { !isCardCollectedInSet($0) }
    }

    private var selectedCards: [LorcanaCard] {
        cards.filter { selectedCardIds.contains($0.id) }
    }
    
    enum FilterOption: String, CaseIterable {
        case all = "All Cards"
        case owned = "Owned"
        case missing = "Missing"
        
        var systemImage: String {
            switch self {
            case .all: return "rectangle.grid.3x2"
            case .owned: return "checkmark.circle"
            case .missing: return "xmark.circle"
            }
        }
    }
    
    private var filteredCards: [LorcanaCard] {
        var filtered: [LorcanaCard]

        // Apply ownership filter
        switch filterOption {
        case .all:
            filtered = cards
        case .owned:
            filtered = cards.filter { isCardCollectedInSet($0) }
        case .missing:
            filtered = cards.filter { !isCardCollectedInSet($0) }
        }

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { card in
                card.name.localizedCaseInsensitiveContains(searchText) ||
                card.cardText.localizedCaseInsensitiveContains(searchText)
            }
        }

        return filtered
    }
    
    private var progress: (collected: Int, total: Int, percentage: Double) {
        let totalCards = dataManager.hasLocalCards(for: set.name) ? 
            dataManager.getLocalCardCount(for: set.name) : set.cardCount
        return collectionManager.getSetProgress(set.name, totalCardsInSet: totalCards)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress header
                VStack(spacing: 12) {
                    HStack {
                        Text(set.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        Text("\(Int(progress.percentage))% Complete")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)
                    }

                    HStack {
                        Text("\(progress.collected) of \(progress.total) cards collected")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        // Filter button
                        Button(action: { showFilterOptions = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: filterOption.systemImage)
                                Text(filterOption.rawValue)
                            }
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.lorcanaGold.opacity(0.2))
                            )
                        }
                        .confirmationDialog("Filter Cards", isPresented: $showFilterOptions) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                Button(option.rawValue) {
                                    filterOption = option
                                }
                            }
                            Button("Cancel", role: .cancel) { }
                        }
                    }

                    // Bulk select controls
                    if isBulkSelectMode {
                        HStack {
                            Button(action: {
                                if selectedCardIds.count == missingCards.count {
                                    selectedCardIds.removeAll()
                                } else {
                                    selectedCardIds = Set(missingCards.map { $0.id })
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: selectedCardIds.count == missingCards.count ? "checkmark.circle.fill" : "circle")
                                    Text(selectedCardIds.count == missingCards.count ? "Deselect All" : "Select All Missing")
                                }
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)
                            }

                            Spacer()

                            Text("\(selectedCardIds.count) selected")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Search bar
                    SearchBar(text: $searchText)
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 6)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.lorcanaGold, .lorcanaGold.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * (progress.percentage / 100),
                                    height: 6
                                )
                        }
                    }
                    .frame(height: 6)
                }
                .padding()
                .background(Color.lorcanaDark.opacity(0.3))
                
                // Cards grid
                if cards.isEmpty && dataManager.hasLocalCards(for: set.name) {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading \(set.name) cards...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if cards.isEmpty && !dataManager.hasLocalCards(for: set.name) {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text("Card data not available")
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text("This set's card data hasn't been added to the app yet.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if filteredCards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: filterOption == .missing ? "checkmark.circle" : "rectangle.grid.3x2")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(filterOption == .missing ? "All cards collected!" : "No cards found")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            LazyVGrid(columns: gridHelper.setDetailColumns(), spacing: gridHelper.gridSpacing) {
                                ForEach(filteredCards) { card in
                                    SetCardView(
                                        card: card,
                                        isCollected: isCardCollectedInSet(card),
                                        quantity: getCardQuantityInSet(card),
                                        isBulkSelectMode: isBulkSelectMode,
                                        isSelected: selectedCardIds.contains(card.id),
                                        onTap: {
                                            if isBulkSelectMode {
                                                toggleCardSelection(card)
                                            } else if isCardCollectedInSet(card) {
                                                selectedCard = card
                                            } else {
                                                selectedCardGroupForAdd = createCardGroup(from: card)
                                            }
                                        },
                                        onQuickAdd: {
                                            quickAddCard(card)
                                        }
                                    )
                                }
                            }
                            .padding(gridHelper.viewPadding)
                            // Extra bottom padding when bulk add bar is visible
                            if isBulkSelectMode {
                                Spacer().frame(height: 80)
                            }
                        }

                        // Bulk add floating bar
                        if isBulkSelectMode && !selectedCardIds.isEmpty {
                            VStack(spacing: 0) {
                                Divider()
                                    .background(Color.lorcanaGold.opacity(0.3))
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(selectedCardIds.count) card\(selectedCardIds.count == 1 ? "" : "s") selected")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                        Text("Will be added as Normal variant")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }

                                    Spacer()

                                    Button(action: {
                                        showBulkAddConfirmation = true
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add All")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.lorcanaDark)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Color.lorcanaGold)
                                        )
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(
                                    Color.lorcanaDark.opacity(0.95)
                                        .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
                                )
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3), value: selectedCardIds.isEmpty)
                        }
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle(set.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isBulkSelectMode {
                        Button("Cancel") {
                            isBulkSelectMode = false
                            selectedCardIds.removeAll()
                        }
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if !isBulkSelectMode {
                            Button(action: {
                                isBulkSelectMode = true
                                selectedCardIds.removeAll()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checklist")
                                    Text("Bulk Add")
                                        .font(.caption)
                                }
                                .foregroundColor(.lorcanaGold)
                            }
                        }

                        Button(action: {
                            dataManager.refreshPricesInBackground()
                            loadCards()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.lorcanaGold)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadCards()
        }
        .sheet(item: $selectedCard) { card in
            CardDetailSheetView(card: card)
                .environmentObject(collectionManager)
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
        .confirmationDialog(
            "Add \(selectedCardIds.count) card\(selectedCardIds.count == 1 ? "" : "s") to collection?",
            isPresented: $showBulkAddConfirmation,
            titleVisibility: .visible
        ) {
            Button("Add as Normal") {
                bulkAddSelectedCards()
            }
            Button("Cancel", role: .cancel) {
                showBulkAddConfirmation = false
            }
        } message: {
            Text("All selected cards will be added as Normal variant with quantity 1.")
        }
        .overlay(
            // Quick add success banner
            VStack {
                if showQuickAddBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text("\(quickAddCardName) added!")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green.opacity(0.9))
                    )
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.spring(response: 0.3), value: showQuickAddBanner)
        )
    }
    
    private func loadCards() {
        // Load cards immediately from local data
        let localCards = dataManager.getCardsForSet(set.name)

        // Apply cached prices to cards
        cards = localCards.map { card in
            dataManager.getCardWithCachedPrice(card)
        }

        // Prefetch images for this set in the background
        ImageCache.shared.prefetchImages(for: cards)
    }

    private func createCardGroup(from card: LorcanaCard) -> CardGroup {
        // For promo cards with uniqueId, don't find reprints - treat as standalone
        if let uniqueId = card.uniqueId, !uniqueId.isEmpty {
            return CardGroup(
                id: uniqueId,
                name: card.name,
                cards: [card]
            )
        }

        // Find all reprints of this card across all sets
        let allCards = dataManager.getAllCards()
        let reprints = allCards.filter { $0.name == card.name }

        return CardGroup(
            id: card.name,
            name: card.name,
            cards: reprints.isEmpty ? [card] : reprints
        )
    }

    private func toggleCardSelection(_ card: LorcanaCard) {
        if selectedCardIds.contains(card.id) {
            selectedCardIds.remove(card.id)
        } else {
            // Only allow selecting uncollected cards
            if !isCardCollectedInSet(card) {
                selectedCardIds.insert(card.id)
            }
        }
    }

    private func quickAddCard(_ card: LorcanaCard) {
        let normalCard = card.variant == .normal ? card : card.withVariant(.normal)
        collectionManager.addCard(normalCard, quantity: 1)
        quickAddCardName = card.name
        showQuickAddBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showQuickAddBanner = false
        }
    }

    private func bulkAddSelectedCards() {
        for card in selectedCards {
            let normalCard = card.variant == .normal ? card : card.withVariant(.normal)
            collectionManager.addCard(normalCard, quantity: 1)
        }
        selectedCardIds.removeAll()
        isBulkSelectMode = false
    }

    // Helper function to check if a specific card is collected
    private func isCardCollectedInSet(_ card: LorcanaCard) -> Bool {
        let isCollected = collectionManager.collectedCards.contains { collected in
            // Match by card name across ALL sets (reprints count as collected)
            // For Enchanted/Epic/Iconic/Promo, they are separate cards so match variant too
            // For Normal/Foil, they're the same card so ignore variant (but don't match special variants)
            let cardIsSpecialVariant = card.variant == .enchanted ||
                                       card.variant == .epic ||
                                       card.variant == .iconic ||
                                       card.variant == .promo

            let collectedIsSpecialVariant = collected.variant == .enchanted ||
                                           collected.variant == .epic ||
                                           collected.variant == .iconic ||
                                           collected.variant == .promo

            let match: Bool
            if cardIsSpecialVariant {
                // For special variants, match name + variant (regardless of set)
                match = collected.name == card.name &&
                       collected.variant == card.variant
            } else {
                // For Normal/Foil, match name only but EXCLUDE special variants
                match = collected.name == card.name &&
                       !collectedIsSpecialVariant
            }

            if match {
                print("✅ [isCardCollectedInSet] Match for \(card.name) in \(set.name): found in collection from \(collected.setName ?? "unknown set") (variant: \(collected.variant.rawValue))")
            }
            return match
        }

        if !isCollected {
            print("❌ [isCardCollectedInSet] No match for: \(card.name) (uniqueId: \(card.uniqueId ?? "nil"), set: \(set.name), variant: \(card.variant.rawValue))")
        }

        return isCollected
    }

    // Helper function to get quantity for a specific card
    private func getCardQuantityInSet(_ card: LorcanaCard) -> Int {
        // Sum quantities across ALL sets where this card appears (reprints)
        let cardIsSpecialVariant = card.variant == .enchanted ||
                                   card.variant == .epic ||
                                   card.variant == .iconic ||
                                   card.variant == .promo

        let totalQuantity = collectionManager.collectedCards
            .filter { collected in
                let collectedIsSpecialVariant = collected.variant == .enchanted ||
                                               collected.variant == .epic ||
                                               collected.variant == .iconic ||
                                               collected.variant == .promo

                if cardIsSpecialVariant {
                    // For special variants, match name + variant across all sets
                    return collected.name == card.name && collected.variant == card.variant
                } else {
                    // For Normal/Foil, match name only but EXCLUDE special variants
                    return collected.name == card.name && !collectedIsSpecialVariant
                }
            }
            .count

        if totalQuantity > 0 {
            print("📊 [getCardQuantityInSet] Found \(totalQuantity) total for: \(card.name) (\(card.variant.rawValue)) across all sets")
        }
        return totalQuantity
    }
}

struct SetCardView: View {
    let card: LorcanaCard
    let isCollected: Bool
    let quantity: Int
    var isBulkSelectMode: Bool = false
    var isSelected: Bool = false
    let onTap: () -> Void
    var onQuickAdd: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                AsyncImage(url: card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(0.7, contentMode: .fit)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isBulkSelectMode && isSelected ? Color.lorcanaGold :
                            (isCollected ? card.rarity.color : Color.gray.opacity(0.5)),
                            lineWidth: isBulkSelectMode && isSelected ? 3 : (isCollected ? 2 : 1)
                        )
                )

                // Collection status overlay
                VStack {
                    HStack {
                        Spacer()

                        if isBulkSelectMode && !isCollected {
                            // Bulk select checkbox
                            ZStack {
                                Circle()
                                    .fill(isSelected ? Color.lorcanaGold : Color.black.opacity(0.5))
                                    .frame(width: 26, height: 26)

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.lorcanaDark)
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 2)
                                        .frame(width: 22, height: 22)
                                }
                            }
                        } else if isCollected {
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 24, height: 24)

                                if quantity > 1 {
                                    Text("\(quantity)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                } else {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }
                            }
                        } else {
                            Circle()
                                .fill(Color.red.opacity(0.8))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    Spacer()
                }
                .padding(6)

                // Quick add button (bottom-right, only for uncollected cards not in bulk mode)
                if !isCollected && !isBulkSelectMode {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                onQuickAdd?()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.lorcanaGold)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "plus")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.lorcanaDark)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }

                // Rarity indicator
                VStack {
                    Spacer()
                    HStack {
                        RarityBadge(rarity: card.rarity)
                        Spacer()
                    }
                }
                .padding(6)
            }

            Text(card.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isCollected ? .white : .gray)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Show buy button for cards not in collection (hide in bulk mode)
            if !isCollected && !isBulkSelectMode {
                CompactBuyButton(card: card)
                    .padding(.top, 4)
            }
        }
        .opacity(isCollected ? 1.0 : (isBulkSelectMode && isSelected ? 1.0 : 0.6))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct CardDetailSheetView: View {
    let card: LorcanaCard
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true

    var body: some View {
        CollectionCardDetailView(card: card, isPresented: $isPresented)
            .onChange(of: isPresented) { newValue in
                if !newValue {
                    dismiss()
                }
            }
    }
}

