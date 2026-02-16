//
//  DetailView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CardDetailView: View {
    let card: LorcanaCard
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: card.bestImageUrl()) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .aspectRatio(0.7, contentMode: .fit)
                    }
                    .frame(maxWidth: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(card.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            RarityBadge(rarity: card.rarity)
                            Spacer()
                            CostBadge(cost: card.cost)
                        }
                        
                        if !card.cardText.isEmpty {
                            Text(card.cardText)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        // Price display removed - users can check prices via buy options
                    }
                    .padding()

                    Button(action: {
                        collectionManager.addCard(card)
                        isPresented = false
                    }) {
                        Text("Add to Collection")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LorcanaButtonStyle())
                    .padding()
                }
            }
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct CollectionCardDetailView: View {
    let card: LorcanaCard
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var collectedCard: CollectedCard?
    @State private var tempQuantity: Int = 1
    @State private var showingDeleteConfirmation = false
    @State private var showingFullscreenViewer = false
    @State private var showingRulesAssistant = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    InteractiveCardView(card: card) {
                        showingFullscreenViewer = true
                    }
                    .frame(width: 250, height: 350)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            RarityBadge(rarity: card.rarity)
                            
                            Text(card.variant.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.purple.opacity(0.8))
                                )
                            
                            Spacer()
                            CostBadge(cost: card.cost)
                        }
                        
                        // Collection specific information - only show if card is owned
                        if collectedCard != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                Group {
                                    HStack {
                                        Text("Quantity:")
                                            .font(.headline)
                                            .foregroundColor(.lorcanaGold)
                                        Spacer()
                                        HStack(spacing: 12) {
                                            Button("-") {
                                                if tempQuantity > 1 {
                                                    tempQuantity -= 1
                                                }
                                            }
                                            .frame(width: 30, height: 30)
                                            .background(Color.red.opacity(0.8))
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                            .disabled(tempQuantity <= 1)
                                            
                                            Text("\(tempQuantity)")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                                .frame(minWidth: 40)
                                            
                                            Button("+") {
                                                tempQuantity += 1
                                            }
                                            .frame(width: 30, height: 30)
                                            .background(Color.green.opacity(0.8))
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                        }
                                    }
                                    
                                    if let collected = collectedCard {
                                        HStack {
                                            Text("Date Added:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(collected.dateAdded, style: .date)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                        
                                        HStack {
                                            Text("Condition:")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Spacer()
                                            Text(collected.condition)
                                                .font(.subheadline)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        if !card.cardText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Text:")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                                Text(card.cardText)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Price display removed - users can check prices via buy options
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )

                    // Check Prices section
                    BuyCardOptionsView(card: card)
                        .padding(.horizontal)

                    // Ask About Rules button
                    Button(action: {
                        showingRulesAssistant = true
                    }) {
                        HStack {
                            Image(systemName: "book.circle")
                            Text("Ask About Rules")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LorcanaButtonStyle(style: .secondary))
                    .padding(.horizontal)

                    // Action buttons - show different buttons based on ownership
                    VStack(spacing: 12) {
                        if collectedCard != nil {
                            // Card is owned - show collection management buttons
                            Button(action: updateQuantity) {
                                Text("Update Quantity")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LorcanaButtonStyle())
                            .disabled(tempQuantity == (collectedCard?.quantity ?? 1))
                            
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Text("Remove from Collection")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        } else {
                            // Card is not owned - show add buttons
                            Button(action: {
                                collectionManager.addCard(card, quantity: 1)
                                isPresented = false
                            }) {
                                Text("Add to Collection")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(LorcanaButtonStyle())
                            
                            Button(action: {
                                collectionManager.addToWishlist(card)
                                isPresented = false
                            }) {
                                Text("Add to Wishlist")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.lorcanaGold)
                        }
                    }
                    .padding()
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            loadCollectedCardData()
        }
        .alert("Remove Card", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                collectionManager.removeCard(card)
                isPresented = false
            }
        } message: {
            Text("Are you sure you want to remove \(card.name) from your collection?")
        }
        .fullScreenCover(isPresented: $showingFullscreenViewer) {
            FullscreenCardViewer(card: card)
        }
        .sheet(isPresented: $showingRulesAssistant) {
            RulesAssistantView(initialCard: card)
        }
    }

    private func loadCollectedCardData() {
        collectedCard = collectionManager.getCollectedCardData(for: card)
        tempQuantity = collectedCard?.quantity ?? 1
    }
    
    private func updateQuantity() {
        collectionManager.updateCardQuantity(card, newQuantity: tempQuantity)
        collectedCard = collectionManager.getCollectedCardData(for: card)
    }
}

struct WishlistCardDetailView: View {
    let card: LorcanaCard
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var showingMoveConfirmation = false
    @State private var showingFullscreenViewer = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    InteractiveCardView(card: card) {
                        showingFullscreenViewer = true
                    }
                    .frame(width: 250, height: 350)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            RarityBadge(rarity: card.rarity)
                            
                            Text(card.variant.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.purple.opacity(0.8))
                                )
                            
                            Spacer()
                            CostBadge(cost: card.cost)
                        }
                        
                        if !card.cardText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Card Text:")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                                Text(card.cardText)
                                    .font(.body)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        // Price display removed - users can check prices via buy options
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )

                    // Check Prices section
                    BuyCardOptionsView(card: card)
                        .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            showingMoveConfirmation = true
                        }) {
                            Text("Move to Collection")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(LorcanaButtonStyle())
                        
                        Button(action: {
                            collectionManager.removeFromWishlist(card)
                            isPresented = false
                        }) {
                            Text("Remove from Wishlist")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    .padding()
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Wishlist Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
        .alert("Move to Collection", isPresented: $showingMoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move") {
                Task {
                    await moveCardToCollection()
                }
            }
        } message: {
            Text("Move \(card.name) from your wishlist to your collection?")
        }
        .fullScreenCover(isPresented: $showingFullscreenViewer) {
            FullscreenCardViewer(card: card)
        }
    }

    @MainActor
    private func moveCardToCollection() async {
        
        // First add to collection
        collectionManager.addCard(card, quantity: 1)
        
        // Wait a moment to ensure the add operation completes
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then remove from wishlist
        collectionManager.removeFromWishlist(card)
        
        // Wait for removal to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        isPresented = false
    }
}

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
                    .onChange(of: searchText) { newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay (faster since local)
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

        // Use local search with grouping - instant results!
        let results = dataManager.searchCardGroups(query: query)

        // Only update results if this search is still current
        if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query {
            self.searchResults = results
        }
    }
}

struct AddToWishlistView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [CardGroup] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCardGroupForWishlist: CardGroup?
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                    .padding()
                    .onChange(of: searchText) { newValue in
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay (faster since local)
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
                        Image(systemName: "heart.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Search for cards to add to wishlist")
                            .foregroundColor(.gray)
                        Text("Find cards you want to collect")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.id) { cardGroup in
                        CardGroupSearchRow(cardGroup: cardGroup) {
                            selectedCardGroupForWishlist = cardGroup
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Add to Wishlist")
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

    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        // Use local search with grouping - instant results!
        let results = dataManager.searchCardGroups(query: query)

        // Only update results if this search is still current
        if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query {
            self.searchResults = results
        }
    }
}

struct AddCardModal: View {
    let card: LorcanaCard
    @Binding var isPresented: Bool
    let onAdd: (LorcanaCard, Int) -> Void
    let isWishlist: Bool

    @State private var selectedVariant: CardVariant = .normal
    @State private var quantity: Int = 1
    @State private var showingCardSearch = false
    @State private var currentCard: LorcanaCard

    init(card: LorcanaCard, isPresented: Binding<Bool>, onAdd: @escaping (LorcanaCard, Int) -> Void, isWishlist: Bool) {
        self.card = card
        self._isPresented = isPresented
        self.onAdd = onAdd
        self.isWishlist = isWishlist
        self._currentCard = State(initialValue: card)
    }

    var selectedCard: LorcanaCard {
        // Use the extension method to get variant-specific image URL
        return currentCard.withVariant(selectedVariant)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    variantSection
                    quantitySection
                    buySection
                    addButton
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle(isWishlist ? "Add to Wishlist" : "Add to Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingCardSearch = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "magnifyingglass")
                            Text("Wrong Card?")
                        }
                        .font(.caption)
                        .foregroundColor(.lorcanaGold)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showingCardSearch) {
                CardSearchForCorrectionView(selectedCard: $currentCard)
            }
            .onChange(of: currentCard.id) { _ in }
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: selectedCard.bestImageUrl()) { image in
                    Group {
                        if selectedVariant == .foil {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .staticFoilEffect()
                        } else {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                    }
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 80, height: 110)

                if selectedVariant != .normal {
                    Text(selectedVariant.shortName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.lorcanaGold)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .id(selectedVariant)

            VStack(alignment: .leading, spacing: 8) {
                Text(currentCard.name)
                    .font(.headline)
                    .foregroundColor(.white)

                HStack {
                    RarityBadge(rarity: currentCard.rarity)
                    Spacer()
                    CostBadge(cost: currentCard.cost)
                }

                // Price display removed
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
    }

    private var variantSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Card Variant")
                .font(.headline)
                .foregroundColor(.lorcanaGold)

            let availableVariants = currentCard.availableVariants()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(availableVariants, id: \.self) { variant in
                    Button(action: { selectedVariant = variant }) {
                        VStack(spacing: 4) {
                            Text(variant.shortName)
                                .font(.caption)
                                .fontWeight(.bold)
                            Text(variant.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedVariant == variant ? .white : .gray)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedVariant == variant ? Color.lorcanaGold : Color.gray.opacity(0.3))
                        )
                    }
                }
            }
        }
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantity")
                .font(.headline)
                .foregroundColor(.lorcanaGold)

            HStack {
                Button("-") {
                    if quantity > 1 { quantity -= 1 }
                }
                .frame(width: 40, height: 40)
                .background(Color.red.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(Circle())
                .disabled(quantity <= 1)

                Spacer()

                Text("\(quantity)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()

                Button("+") {
                    quantity += 1
                }
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(Circle())
            }
            .padding(.horizontal)
        }
    }

    private var buySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or Buy This Card")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal)

            BuyCardOptionsView(card: currentCard)
        }
    }

    private var addButton: some View {
        Button(action: {
            onAdd(selectedCard, quantity)
            isPresented = false
        }) {
            Text("Add \(quantity) \(selectedVariant.displayName) card\(quantity > 1 ? "s" : "") to \(isWishlist ? "Wishlist" : "Collection")")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(LorcanaButtonStyle())
        .padding()
    }
}

// MARK: - Add Card Group Modal (Shows Reprint Info)
struct AddCardGroupModal: View {
    let cardGroup: CardGroup
    @Binding var isPresented: Bool
    let onAdd: (LorcanaCard, Int) -> Void
    let isWishlist: Bool

    // For regular cards (Normal/Foil), use multi-quantity mode
    @State private var normalQuantity: Int = 1
    @State private var foilQuantity: Int = 0

    // For special variants, use single selection mode
    @State private var selectedSpecialVariant: CardVariant = .enchanted
    @State private var specialQuantity: Int = 1

    @State private var showingSuccessBanner = false
    @State private var isImageExpanded = false
    @State private var successMessage = ""

    /// Whether this card supports multi-variant adding (Normal + Foil)
    private var supportsMultiVariant: Bool {
        let variants = cardGroup.primaryCard.availableVariants()
        return variants.contains(.normal) && variants.contains(.foil)
    }

    /// For display purposes, show the normal card by default
    var displayCard: LorcanaCard {
        cardGroup.primaryCard.withVariant(.normal)
    }

    /// Total cards being added
    private var totalQuantity: Int {
        if supportsMultiVariant {
            return normalQuantity + foilQuantity
        } else {
            return specialQuantity
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Card image and basic info
                HStack(spacing: 16) {
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: displayCard.bestImageUrl()) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 110)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isImageExpanded = true
                        }
                    }
                    .id(displayCard.id)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(displayCard.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            RarityBadge(rarity: displayCard.rarity)
                            Spacer()
                            CostBadge(cost: displayCard.cost)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )

                // Reprint info (if card appears in multiple sets)
                if cardGroup.isReprint {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "square.on.square")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text("This card appears in multiple sets")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }

                        // Show all sets as badges
                        HStack(spacing: 8) {
                            ForEach(cardGroup.cards, id: \.id) { card in
                                HStack(spacing: 4) {
                                    Text(card.setName)
                                        .font(.caption)
                                    if let uniqueId = card.uniqueId {
                                        Text("(\(uniqueId))")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.3))
                                )
                            }
                        }

                        Text("Adding this card will count toward all sets")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }

                // Variant and Quantity selection
                if supportsMultiVariant {
                    // Multi-variant mode: Normal + Foil side by side
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Add Cards")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)

                        Text("Set quantities for each variant you want to add")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack(spacing: 16) {
                            // Normal quantity
                            variantQuantityView(
                                variant: .normal,
                                quantity: $normalQuantity,
                                icon: "rectangle.portrait",
                                color: .white
                            )

                            // Foil quantity
                            variantQuantityView(
                                variant: .foil,
                                quantity: $foilQuantity,
                                icon: "sparkles",
                                color: .lorcanaGold
                            )
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                } else {
                    // Special variant mode: single selection
                    let availableVariants = cardGroup.primaryCard.availableVariants()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Card Variant")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(availableVariants, id: \.self) { variant in
                                Button(action: {
                                    selectedSpecialVariant = variant
                                }) {
                                    VStack(spacing: 4) {
                                        Text(variant.shortName)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                        Text(variant.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(selectedSpecialVariant == variant ? .white : .gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedSpecialVariant == variant ? Color.lorcanaGold.opacity(0.3) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedSpecialVariant == variant ? Color.lorcanaGold : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )

                    // Quantity selection for special variants
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quantity")
                            .font(.headline)
                            .foregroundColor(.lorcanaGold)

                        HStack {
                            Button(action: {
                                if specialQuantity > 1 {
                                    specialQuantity -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(specialQuantity > 1 ? .lorcanaGold : .gray)
                            }
                            .disabled(specialQuantity <= 1)

                            Text("\(specialQuantity)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(minWidth: 50)

                            Button(action: {
                                specialQuantity += 1
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.lorcanaGold)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.lorcanaDark.opacity(0.6))
                    )
                }

                // Buy options (for cards you don't own yet)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or Buy This Card")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    BuyCardOptionsView(card: displayCard)
                }

                // Add button
                Button(action: {
                    addCards()
                }) {
                    Text(addButtonText)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LorcanaButtonStyle())
                .disabled(totalQuantity == 0)
                .padding()
                }
                .padding()
            }
            .background(LorcanaBackground())
            .navigationTitle(isWishlist ? "Add to Wishlist" : "Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .overlay(
                // Success banner
                VStack {
                    if showingSuccessBanner {
                        HStack(spacing: 12) {
                            Image(systemName: isWishlist ? "heart.fill" : "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Success!")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(successMessage)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }

                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.95))
                        )
                        .padding()
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
                .animation(.spring(), value: showingSuccessBanner)
            )
            .overlay(
                // Expanded image overlay
                Group {
                    if isImageExpanded {
                        Color.black.opacity(0.85)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    isImageExpanded = false
                                }
                            }

                        VStack {
                            AsyncImage(url: displayCard.bestImageUrl()) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .aspectRatio(0.7, contentMode: .fit)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                            .padding(40)

                            Text("Tap anywhere to close")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.bottom, 20)
                        }
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isImageExpanded = false
                            }
                        }
                    }
                }
            )
            .onAppear {
                // Initialize selected variant for special cards
                // For promo cards, this ensures it starts as .promo
                selectedSpecialVariant = cardGroup.primaryCard.variant
            }
        }
    }

    // MARK: - Helper Views

    private func variantQuantityView(variant: CardVariant, quantity: Binding<Int>, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(variant.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }

            HStack(spacing: 12) {
                Button(action: {
                    if quantity.wrappedValue > 0 {
                        quantity.wrappedValue -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(quantity.wrappedValue > 0 ? color : .gray.opacity(0.5))
                }
                .disabled(quantity.wrappedValue <= 0)

                Text("\(quantity.wrappedValue)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(minWidth: 30)

                Button(action: {
                    quantity.wrappedValue += 1
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(quantity.wrappedValue > 0 ? color.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(quantity.wrappedValue > 0 ? color.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Helper Properties

    private var addButtonText: String {
        if supportsMultiVariant {
            var parts: [String] = []
            if normalQuantity > 0 {
                parts.append("\(normalQuantity) Normal")
            }
            if foilQuantity > 0 {
                parts.append("\(foilQuantity) Foil")
            }
            if parts.isEmpty {
                return "Select quantity to add"
            }
            return "Add \(parts.joined(separator: " + ")) to \(isWishlist ? "Wishlist" : "Collection")"
        } else {
            return "Add \(specialQuantity) \(selectedSpecialVariant.displayName) to \(isWishlist ? "Wishlist" : "Collection")"
        }
    }

    // MARK: - Actions

    private func addCards() {
        if supportsMultiVariant {
            var addedParts: [String] = []

            // Add normal cards if quantity > 0
            if normalQuantity > 0 {
                let normalCard = cardGroup.primaryCard.withVariant(.normal)
                onAdd(normalCard, normalQuantity)
                addedParts.append("\(normalQuantity) Normal")
            }

            // Add foil cards if quantity > 0
            if foilQuantity > 0 {
                let foilCard = cardGroup.primaryCard.withVariant(.foil)
                onAdd(foilCard, foilQuantity)
                addedParts.append("\(foilQuantity) Foil")
            }

            successMessage = "Added \(addedParts.joined(separator: " + ")) card\(totalQuantity > 1 ? "s" : "")"
        } else {
            // Special variant - single add
            let specialCard = cardGroup.primaryCard.withVariant(selectedSpecialVariant)
            onAdd(specialCard, specialQuantity)
            successMessage = "Added \(specialQuantity) \(selectedSpecialVariant.displayName) card\(specialQuantity > 1 ? "s" : "")"
        }

        showingSuccessBanner = true

        // Dismiss after showing success banner briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
}

struct CardSearchForCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCard: LorcanaCard
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
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

                if searchResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No cards found")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchText.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Search for the correct card")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(searchResults, id: \.id) { card in
                        SimpleCardSearchRow(card: card) {
                            selectedCard = card
                            dismiss()
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Find Correct Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        searchResults = dataManager.searchCards(query: query)
    }
}

struct SimpleCardSearchRow: View {
    let card: LorcanaCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: card.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack {
                        RarityBadge(rarity: card.rarity)
                        Spacer()
                        // Price display removed
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Card Group Search Row
struct CardGroupSearchRow: View {
    let cardGroup: CardGroup
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                AsyncImage(url: cardGroup.primaryCard.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 50, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(cardGroup.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)

                    HStack {
                        RarityBadge(rarity: cardGroup.primaryCard.rarity)

                        // Show reprint badge if multiple sets
                        if cardGroup.isReprint {
                            HStack(spacing: 3) {
                                Image(systemName: "square.on.square")
                                    .font(.caption2)
                                Text("\(cardGroup.setCount) sets")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.8)))
                        }

                        Spacer()

                        // Price display removed
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CardSearchResultRow: View {
    let card: LorcanaCard
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            AsyncImage(url: card.bestImageUrl()) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    RarityBadge(rarity: card.rarity)
                    Spacer()
                    // Price display removed
                }
            }
            
            Spacer()
            
            Button("Add", action: onAdd)
                .buttonStyle(LorcanaButtonStyle())
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
