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

                        Text(card.setName)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        HStack {
                            RarityBadge(rarity: card.rarity)
                            Spacer()
                        }

                        if !card.cardText.isEmpty {
                            Text(card.cardText)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        AsyncPriceWithConfidenceView(card: card, style: .detailed)
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
    var showAllVariants: Bool = false
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var collectedCard: CollectedCard?
    @State private var tempQuantity: Int = 1
    @State private var foilCollectedCard: CollectedCard?
    @State private var foilQuantity: Int = 0
    @State private var showingDeleteConfirmation = false
    @State private var showingFullscreenViewer = false
    @State private var showingRulesAssistant = false
    @State private var deckAllocations: [CollectionManager.DeckAllocation] = []
    @State private var showFoilArt = false
    @State private var imageAttachments: [Data] = []
    @State private var showingShareImage = false

    /// Builds the snapshot the card-flex share template consumes, decoding the user's first
    /// attached photo (if any) so they can flex their actual card.
    private func makeCardFlexShareData() -> CardFlexShareData {
        let photo = imageAttachments.first.flatMap { UIImage(data: $0) }
        // Quantity of the variant actually being shown (foil art toggle picks the foil count).
        let ownedQuantity = max(1, showFoilArt ? foilQuantity : tempQuantity)
        return CardFlexShareData(
            id: displayCard.id,
            name: displayCard.name,
            setName: displayCard.setName,
            rarity: displayCard.rarity,
            variant: displayCard.variant,
            ownedQuantity: ownedQuantity,
            catalogImageURL: displayCard.bestImageUrl(),
            userPhoto: photo
        )
    }

    /// Whether to show the foil section — only when opened from Sets view and card supports foil
    private var showFoilSection: Bool {
        guard showAllVariants else { return false }
        let v = card.variant
        return v == .normal || v == .foil
    }

    /// The card to display — switches to foil variant when foil art toggle is on
    private var displayCard: LorcanaCard {
        showFoilArt ? card.withVariant(.foil) : card
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    InteractiveCardView(card: displayCard) {
                        showingFullscreenViewer = true
                    }
                    .frame(width: 250, height: 350)

                    // Foil art toggle — visible when user owns foil copies
                    if showFoilSection && foilQuantity > 0 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showFoilArt.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showFoilArt ? "sparkles" : "rectangle.portrait")
                                    .font(.caption)
                                Text(showFoilArt ? "Viewing Foil" : "View Foil")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(showFoilArt ? .lorcanaDark : .lorcanaGold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(showFoilArt ? Color.lorcanaGold : Color.lorcanaGold.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.lorcanaGold.opacity(0.5), lineWidth: 1)
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(card.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text(card.setName)
                            .font(.subheadline)
                            .foregroundColor(.gray)

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
                        }

                        // Collection specific information - only show if card is owned
                        if collectedCard != nil || foilCollectedCard != nil {
                            VStack(alignment: .leading, spacing: 12) {
                                collectionQuantitySection

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

                                // Deck Usage section
                                if !deckAllocations.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        let totalAllocated = deckAllocations.reduce(0) { $0 + $1.quantity }
                                        let totalOwned = tempQuantity + foilQuantity
                                        let available = max(0, totalOwned - totalAllocated)

                                        HStack {
                                            Text("Deck Usage")
                                                .font(.headline)
                                                .foregroundColor(.lorcanaGold)
                                            Spacer()
                                            Text("\(available) available")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(available > 0 ? .green : .red)
                                        }

                                        ForEach(deckAllocations, id: \.deckName) { allocation in
                                            HStack {
                                                Image(systemName: "rectangle.stack.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.lorcanaGold.opacity(0.7))
                                                Text(allocation.deckName)
                                                    .font(.subheadline)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text("\(allocation.quantity) used")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                        }
                                    }
                                    .padding(.top, 4)
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
                        
                        AsyncPriceWithConfidenceView(card: card, style: .detailed)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.lorcanaDark.opacity(0.8))
                    )

                    // My Card Photos section - only show for owned cards
                    if collectedCard != nil || foilCollectedCard != nil {
                        CardImageAttachmentView(
                            imageAttachments: $imageAttachments,
                            onSave: saveImageAttachments
                        )
                        .padding(.horizontal)
                    }

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
                        if collectedCard != nil || foilCollectedCard != nil {
                            // Card is owned - show collection management buttons
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                Text("Remove All from Collection")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        } else {
                            // Card is not owned - show add buttons
                            Button(action: {
                                collectionManager.addCard(card.withVariant(.normal), quantity: 1)
                                loadCollectedCardData()
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        showingShareImage = true
                    }
                }
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
        .sheet(isPresented: $showingShareImage) {
            CardFlexShareView(data: makeCardFlexShareData())
        }
        .alert("Remove Card", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                if showFoilSection {
                    collectionManager.removeCard(card.withVariant(.normal))
                    collectionManager.removeCard(card.withVariant(.foil))
                } else {
                    collectionManager.removeCard(card)
                }
                isPresented = false
            }
        } message: {
            if showFoilSection {
                Text("Are you sure you want to remove all copies of \(card.name) (Normal and Foil) from your collection?")
            } else {
                Text("Are you sure you want to remove \(card.name) from your collection?")
            }
        }
        .fullScreenCover(isPresented: $showingFullscreenViewer) {
            FullscreenCardViewer(card: displayCard)
        }
        .sheet(isPresented: $showingRulesAssistant) {
            RulesAssistantView(initialCard: card)
        }
    }

    @ViewBuilder
    private var collectionQuantitySection: some View {
        if showFoilSection {
            Text("Quantity")
                .font(.headline)
                .foregroundColor(.lorcanaGold)

            HStack(spacing: 16) {
                // Normal quantity
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait")
                            .font(.caption)
                        Text("Normal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)

                    HStack(spacing: 12) {
                        Button("-") {
                            if tempQuantity > 0 {
                                tempQuantity -= 1
                                updateQuantity()
                                if tempQuantity == 0 && foilQuantity == 0 {
                                    isPresented = false
                                }
                            }
                        }
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .disabled(tempQuantity <= 0)

                        Text("\(tempQuantity)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 30)

                        Button("+") {
                            tempQuantity += 1
                            updateQuantity()
                        }
                        .frame(width: 28, height: 28)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(tempQuantity > 0 ? Color.white.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(tempQuantity > 0 ? Color.white.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )

                // Foil quantity
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("Foil")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.lorcanaGold)

                    HStack(spacing: 12) {
                        Button("-") {
                            if foilQuantity > 0 {
                                foilQuantity -= 1
                                updateFoilQuantity()
                                if tempQuantity == 0 && foilQuantity == 0 {
                                    isPresented = false
                                }
                            }
                        }
                        .frame(width: 28, height: 28)
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .disabled(foilQuantity <= 0)

                        Text("\(foilQuantity)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: 30)

                        Button("+") {
                            foilQuantity += 1
                            updateFoilQuantity()
                        }
                        .frame(width: 28, height: 28)
                        .background(Color.lorcanaGold)
                        .foregroundColor(.lorcanaDark)
                        .clipShape(Circle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(foilQuantity > 0 ? Color.lorcanaGold.opacity(0.15) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(foilQuantity > 0 ? Color.lorcanaGold.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        } else {
            // Non-foilable cards (Enchanted, etc.) — single quantity
            HStack {
                Text("Quantity:")
                    .font(.headline)
                    .foregroundColor(.lorcanaGold)
                Spacer()
                HStack(spacing: 12) {
                    Button("-") {
                        if tempQuantity > 0 {
                            tempQuantity -= 1
                            updateQuantity()
                            if tempQuantity == 0 {
                                isPresented = false
                            }
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .disabled(tempQuantity <= 0)

                    Text("\(tempQuantity)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 40)

                    Button("+") {
                        tempQuantity += 1
                        updateQuantity()
                    }
                    .frame(width: 30, height: 30)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(Circle())
                }
            }
        }
    }

    private func loadCollectedCardData() {
        if showFoilSection {
            // From Sets view: load both normal and foil separately
            let normalCard = card.withVariant(.normal)
            collectedCard = collectionManager.getCollectedCardDataForVariant(normalCard)
            tempQuantity = collectedCard?.quantity ?? 0

            let foilCard = card.withVariant(.foil)
            foilCollectedCard = collectionManager.getCollectedCardDataForVariant(foilCard)
            foilQuantity = foilCollectedCard?.quantity ?? 0
        } else {
            // From Collection view: load the card's specific variant
            // Use variant-aware lookup for Normal/Foil since they're stored separately
            if card.variant == .normal || card.variant == .foil {
                collectedCard = collectionManager.getCollectedCardDataForVariant(card)
            } else {
                collectedCard = collectionManager.getCollectedCardData(for: card)
            }
            tempQuantity = collectedCard?.quantity ?? 1
        }

        // Load image attachments from the primary collected card
        let primaryCard = collectedCard ?? foilCollectedCard
        imageAttachments = primaryCard?.imageAttachments ?? []

        // Load deck allocations
        deckAllocations = collectionManager.getDeckAllocations(for: card)
    }

    private func saveImageAttachments() {
        // Save to the primary collected card (prefer normal over foil)
        if let collected = collectedCard {
            collected.imageAttachments = imageAttachments
            collectionManager.saveContext()
        } else if let foilCollected = foilCollectedCard {
            foilCollected.imageAttachments = imageAttachments
            collectionManager.saveContext()
        }
    }

    private func updateQuantity() {
        let targetCard = showFoilSection ? card.withVariant(.normal) : card
        if tempQuantity > 0 {
            if collectedCard != nil {
                collectionManager.updateCardQuantity(targetCard, newQuantity: tempQuantity)
            } else {
                collectionManager.addCard(targetCard, quantity: tempQuantity)
            }
        } else if collectedCard != nil {
            collectionManager.removeCard(targetCard)
        }
        // Reload to get fresh state
        if targetCard.variant == .normal || targetCard.variant == .foil {
            collectedCard = collectionManager.getCollectedCardDataForVariant(targetCard)
        } else {
            collectedCard = collectionManager.getCollectedCardData(for: targetCard)
        }
    }

    private func updateFoilQuantity() {
        let foilCard = card.withVariant(.foil)
        if foilQuantity > 0 {
            if foilCollectedCard != nil {
                collectionManager.updateCardQuantity(foilCard, newQuantity: foilQuantity)
            } else {
                collectionManager.addCard(foilCard, quantity: foilQuantity)
            }
        } else if foilCollectedCard != nil {
            collectionManager.removeCard(foilCard)
        }
        foilCollectedCard = collectionManager.getCollectedCardDataForVariant(foilCard)
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
                        
                        Text(card.setName)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            
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
                            }

                            AsyncPriceWithConfidenceView(card: card, style: .detailed)
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
    }

    @MainActor
    private func moveCardToCollection() async {
        collectionManager.addCard(card, quantity: 1)
        try? await Task.sleep(for: .seconds(0.1))
        collectionManager.removeFromWishlist(card)
        try? await Task.sleep(for: .seconds(0.1))
        isPresented = false
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
                    .scrollContentBackground(.hidden)
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
    
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var selectedVariant: CardVariant = .normal
    @State private var quantity: Int = 1
    @State private var showingCardSearch = false
    @State private var showingFullscreenViewer = false
    @State private var currentCard: LorcanaCard
    @State private var photoAttachments: [Data] = []
    
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
                    if !isWishlist {
                        CompactPhotoAttachmentView(imageAttachments: $photoAttachments)
                    }
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
            .onTapGesture {
                showingFullscreenViewer = true
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(currentCard.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(currentCard.setName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    RarityBadge(rarity: currentCard.rarity)
                    Spacer()
                }
                
                AsyncPriceWithConfidenceView(card: selectedCard, style: .inline)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
        .fullScreenCover(isPresented: $showingFullscreenViewer) {
            FullscreenCardViewer(card: selectedCard)
        }
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
            if !photoAttachments.isEmpty {
                collectionManager.attachImages(photoAttachments, to: selectedCard)
            }
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

private struct CardGroupInfoHeader: View {
    let displayCard: LorcanaCard
    @Binding var isImageExpanded: Bool
    
    var body: some View {
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
                
                Text(displayCard.setName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    RarityBadge(rarity: displayCard.rarity)
                    Spacer()
                    if let price = displayCard.price {
                        Text(price, format: .currency(code: "USD"))
                            .font(.caption)
                            .bold()
                            .foregroundStyle(.lorcanaGold)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.lorcanaDark.opacity(0.8))
        )
    }
}

struct AddCardGroupModal: View {
    let cardGroup: CardGroup
    @Binding var isPresented: Bool
    let onAdd: (LorcanaCard, Int) -> Void
    let isWishlist: Bool
    var onAddToWishlist: ((LorcanaCard, Int) -> Void)? = nil
    
    @EnvironmentObject var collectionManager: CollectionManager
    
    // For regular cards (Normal/Foil), use multi-quantity mode
    @State private var normalQuantity: Int = 1
    @State private var foilQuantity: Int = 0
    
    // For special variants, use single selection mode
    @State private var selectedSpecialVariant: CardVariant = .enchanted
    @State private var specialQuantity: Int = 1
    
    @State private var showingSuccessBanner = false
    @State private var isImageExpanded = false
    @State private var successMessage = ""
    @State private var photoAttachments: [Data] = []
    
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
                    CardGroupInfoHeader(displayCard: displayCard, isImageExpanded: $isImageExpanded)
                    
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
                                    SpecialVariantButton(
                                        variant: variant,
                                        isSelected: selectedSpecialVariant == variant
                                    ) {
                                        selectedSpecialVariant = variant
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
                    
                    // Photo attachment (only for collection, not wishlist)
                    if !isWishlist {
                        CompactPhotoAttachmentView(imageAttachments: $photoAttachments)
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
                    
                    // Add to Wishlist button (shown when adding to collection)
                    if let onAddToWishlist = onAddToWishlist, !isWishlist {
                        Button(action: {
                            addCardsToWishlist(onAddToWishlist)
                        }) {
                            HStack {
                                Image(systemName: "star.fill")
                                Text("Add to Wishlist Instead")
                            }
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.yellow)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .disabled(totalQuantity == 0)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
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
                if !photoAttachments.isEmpty {
                    collectionManager.attachImages(photoAttachments, to: normalCard)
                }
                addedParts.append("\(normalQuantity) Normal")
            }
            
            // Add foil cards if quantity > 0
            if foilQuantity > 0 {
                let foilCard = cardGroup.primaryCard.withVariant(.foil)
                onAdd(foilCard, foilQuantity)
                // Attach photos to foil variant too if no normal cards were added
                if !photoAttachments.isEmpty && normalQuantity == 0 {
                    collectionManager.attachImages(photoAttachments, to: foilCard)
                }
                addedParts.append("\(foilQuantity) Foil")
            }
            
            successMessage = "Added \(addedParts.joined(separator: " + ")) card\(totalQuantity > 1 ? "s" : "")"
        } else {
            // Special variant - single add
            let specialCard = cardGroup.primaryCard.withVariant(selectedSpecialVariant)
            onAdd(specialCard, specialQuantity)
            if !photoAttachments.isEmpty {
                collectionManager.attachImages(photoAttachments, to: specialCard)
            }
            successMessage = "Added \(specialQuantity) \(selectedSpecialVariant.displayName) card\(specialQuantity > 1 ? "s" : "")"
        }
        
        showingSuccessBanner = true
        
        // Dismiss after showing success banner briefly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isPresented = false
        }
    }
    
    private func addCardsToWishlist(_ wishlistAction: (LorcanaCard, Int) -> Void) {
        if supportsMultiVariant {
            var addedParts: [String] = []
            
            if normalQuantity > 0 {
                let normalCard = cardGroup.primaryCard.withVariant(.normal)
                wishlistAction(normalCard, normalQuantity)
                addedParts.append("\(normalQuantity) Normal")
            }
            
            if foilQuantity > 0 {
                let foilCard = cardGroup.primaryCard.withVariant(.foil)
                wishlistAction(foilCard, foilQuantity)
                addedParts.append("\(foilQuantity) Foil")
            }
            
            successMessage = "Added \(addedParts.joined(separator: " + ")) to Wishlist"
        } else {
            let specialCard = cardGroup.primaryCard.withVariant(selectedSpecialVariant)
            wishlistAction(specialCard, specialQuantity)
            successMessage = "Added \(specialQuantity) \(selectedSpecialVariant.displayName) to Wishlist"
        }
        
        showingSuccessBanner = true
        
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

// MARK: - Card Group Search Row
struct CardGroupSearchRow: View {
    let cardGroup: CardGroup
    let onTap: () -> Void
    var onWishlist: (() -> Void)? = nil
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                AsyncImage(url: cardGroup.primaryCard.bestImageUrl()) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cardGroup.primaryCard.rarity.color, lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(cardGroup.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        RarityBadge(rarity: cardGroup.primaryCard.rarity)
                        if let price = cardGroup.primaryCard.price {
                            Text(price, format: .currency(code: "USD"))
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.lorcanaGold)
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Text(cardGroup.primaryCard.setName)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        if cardGroup.isReprint {
                            HStack(spacing: 3) {
                                Image(systemName: "square.on.square")
                                    .font(.caption2)
                                Text("\(cardGroup.setCount) sets")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.8)))
                        }
                    }
                }
                
                Spacer()
                
                if let onWishlist = onWishlist {
                    Button {
                        onWishlist()
                    } label: {
                        Image(systemName: "star.fill")
                            .font(.body)
                            .foregroundColor(.yellow)
                            .padding(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.lorcanaGold.opacity(0.6))
                    .font(.caption)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(Color.lorcanaDark.opacity(0.6))
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
                
                Text(card.setName)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                HStack {
                    RarityBadge(rarity: card.rarity)
                    Spacer()
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

// MARK: - Special Variant Button

/// One selectable tile in the special-variant picker. Extracted into its own view so the
/// grid expression stays light for the type-checker.
struct SpecialVariantButton: View {
    let variant: CardVariant
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(variant.shortName)
                    .font(.caption)
                    .bold()
                Text(variant.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? .white : .gray)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.lorcanaGold.opacity(0.3) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.lorcanaGold : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Preview Fixtures

private let _previewCard = LorcanaCard(
    id: "preview-001",
    name: "Mickey Mouse - True Friend",
    cost: 3,
    type: "Character",
    rarity: .legendary,
    setName: "The First Chapter",
    cardText: "Whenever this character quests, you may draw a card.",
    imageUrl: "",
    price: 12.50,
    variant: .normal,
    cardNumber: 89
)

private let _previewCardGroup = CardGroup(
    id: "Mickey Mouse - True Friend",
    name: "Mickey Mouse - True Friend",
    cards: [_previewCard]
)

// MARK: - Previews

#Preview("Card Detail") {
    CardDetailView(
        card: _previewCard,
        isPresented: .constant(true)
    )
    .environmentObject(CollectionManager())
}

#Preview("Collection Card Detail") {
    CollectionCardDetailView(
        card: LorcanaCard(
            id: "preview-002",
            name: "Elsa - Snow Queen",
            cost: 5,
            type: "Character",
            rarity: .legendary,
            setName: "The First Chapter",
            cardText: "**Shift** 3 — **Freeze**: Whenever this character challenges, the challenged character can't quest this turn.",
            imageUrl: "",
            price: 45.00,
            variant: .normal,
            cardNumber: 43
        ),
        isPresented: .constant(true)
    )
    .environmentObject(CollectionManager())
}

#Preview("Collection Card Detail – All Variants") {
    CollectionCardDetailView(
        card: LorcanaCard(
            id: "preview-002",
            name: "Elsa - Snow Queen",
            cost: 5,
            type: "Character",
            rarity: .legendary,
            setName: "The First Chapter",
            cardText: "**Shift** 3 — **Freeze**: Whenever this character challenges, the challenged character can't quest this turn.",
            imageUrl: "",
            price: 45.00,
            variant: .normal,
            cardNumber: 43
        ),
        isPresented: .constant(true),
        showAllVariants: true
    )
    .environmentObject(CollectionManager())
}

#Preview("Wishlist Card Detail") {
    WishlistCardDetailView(
        card: LorcanaCard(
            id: "preview-003",
            name: "Stitch - Rock Star",
            cost: 4,
            type: "Character",
            rarity: .superRare,
            setName: "Rise of the Floodborn",
            cardText: "**Rush** — This character can challenge the turn they're played.",
            imageUrl: "",
            price: 8.99,
            variant: .normal,
            cardNumber: 124
        ),
        isPresented: .constant(true)
    )
    .environmentObject(CollectionManager())
}

#Preview("Add to Wishlist") {
    AddToWishlistView(isPresented: .constant(true))
        .environmentObject(CollectionManager())
}

#Preview("Add Card Modal – Collection") {
    AddCardModal(
        card: _previewCard,
        isPresented: .constant(true),
        onAdd: { _, _ in },
        isWishlist: false
    )
    .environmentObject(CollectionManager())
}

#Preview("Add Card Modal – Wishlist") {
    AddCardModal(
        card: _previewCard,
        isPresented: .constant(true),
        onAdd: { _, _ in },
        isWishlist: true
    )
    .environmentObject(CollectionManager())
}

#Preview("Add Card Group Modal") {
    AddCardGroupModal(
        cardGroup: _previewCardGroup,
        isPresented: .constant(true),
        onAdd: { _, _ in },
        isWishlist: false
    )
    .environmentObject(CollectionManager())
}

#Preview("Card Search For Correction") {
    CardSearchForCorrectionView(selectedCard: .constant(_previewCard))
}

#Preview("Card Group Search Row") {
    List {
        CardGroupSearchRow(cardGroup: _previewCardGroup, onTap: {})
        CardGroupSearchRow(cardGroup: _previewCardGroup, onTap: {}, onWishlist: {})
    }
    .listStyle(.plain)
    .background(Color.black)
}

#Preview("Card Search Result Row") {
    List {
        CardSearchResultRow(card: _previewCard, onAdd: {})
    }
    .listStyle(.plain)
}

#Preview("Special Variant Button") {
    HStack {
        SpecialVariantButton(variant: .normal, isSelected: false, action: {})
        SpecialVariantButton(variant: .foil, isSelected: true, action: {})
        SpecialVariantButton(variant: .enchanted, isSelected: false, action: {})
    }
    .padding()
    .background(Color.black)
}
