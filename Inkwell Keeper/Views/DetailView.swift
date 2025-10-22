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
                    AsyncImage(url: URL(string: card.imageUrl)) { image in
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
                        
                        if let price = card.price {
                            Text("Market Value: $\(price, specifier: "%.2f")")
                                .font(.headline)
                                .foregroundColor(.lorcanaGold)
                        }
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: card.imageUrl)) { image in
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
                        
                        if let price = card.price {
                            HStack {
                                Text("Market Value:")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                                Spacer()
                                Text("$\(price, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                            }
                            
                            if let collected = collectedCard, collected.quantity > 1 {
                                HStack {
                                    Text("Total Value:")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("$\(price * Double(collected.quantity), specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.lorcanaGold)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )
                    
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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: card.imageUrl)) { image in
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
                        
                        if let price = card.price {
                            HStack {
                                Text("Market Value:")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                                Spacer()
                                Text("$\(price, specifier: "%.2f")")
                                    .font(.headline)
                                    .foregroundColor(.lorcanaGold)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )
                    
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCard: LorcanaCard?
    
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
                    List(searchResults, id: \.id) { card in
                        SimpleCardSearchRow(card: card) {
                            selectedCard = card
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
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .sheet(item: $selectedCard) { card in
            AddCardModal(card: card, isPresented: .constant(true), onAdd: { selectedCard, quantity in
                for _ in 0..<quantity {
                    collectionManager.addCard(selectedCard)
                }
                // Don't dismiss - let user add more cards
            }, isWishlist: false)
            .environmentObject(collectionManager)
        }
    }
    
    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        
        // Use local search - instant results!
        let results = dataManager.searchCards(query: query)
        
        // Only update results if this search is still current
        if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query {
            self.searchResults = results
        } else {
        }
    }
}

struct AddToWishlistView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var searchText = ""
    @State private var searchResults: [LorcanaCard] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedCard: LorcanaCard?
    
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
                    List(searchResults, id: \.id) { card in
                        SimpleCardSearchRow(card: card) {
                            selectedCard = card
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
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            searchTask?.cancel()
        }
        .sheet(item: $selectedCard) { card in
            AddCardModal(card: card, isPresented: .constant(true), onAdd: { selectedCard, quantity in
                for _ in 0..<quantity {
                    collectionManager.addToWishlist(selectedCard)
                }
                // Don't dismiss - let user add more cards
            }, isWishlist: true)
            .environmentObject(collectionManager)
        }
    }
    
    private func searchCards(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        
        // Use local search - instant results!
        let results = dataManager.searchCards(query: query)
        
        // Only update results if this search is still current
        if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query {
            self.searchResults = results
        } else {
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
        currentCard.withVariant(selectedVariant)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Card image and basic info (updates with selected variant)
                HStack(spacing: 16) {
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: selectedCard.imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                        }
                        .frame(width: 80, height: 110)

                        // Show variant badge if not normal
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
                    .id(selectedVariant)  // Force reload when variant changes
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentCard.name)
                            .font(.headline)
                            .foregroundColor(.white)

                        HStack {
                            RarityBadge(rarity: currentCard.rarity)
                            Spacer()
                            CostBadge(cost: currentCard.cost)
                        }

                        if let price = currentCard.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.lorcanaDark.opacity(0.8))
                )
                
                // Variant selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Card Variant")
                        .font(.headline)
                        .foregroundColor(.lorcanaGold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(CardVariant.allCases, id: \.self) { variant in
                            Button(action: {
                                selectedVariant = variant
                            }) {
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
                
                // Quantity selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quantity")
                        .font(.headline)
                        .foregroundColor(.lorcanaGold)
                    
                    HStack {
                        Button("-") {
                            if quantity > 1 {
                                quantity -= 1
                            }
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
                
                // Buy options (for cards you don't own yet)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or Buy This Card")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    BuyCardOptionsView(card: currentCard)
                }

                Spacer()

                // Add button
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
            .padding()
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
            .onChange(of: currentCard.id) { newId in
            }
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
                AsyncImage(url: URL(string: card.imageUrl)) { image in
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
                        if let price = card.price {
                            Text("$\(price, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.lorcanaGold)
                        }
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

struct CardSearchResultRow: View {
    let card: LorcanaCard
    let onAdd: () -> Void
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: card.imageUrl)) { image in
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
                    if let price = card.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.lorcanaGold)
                    }
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
