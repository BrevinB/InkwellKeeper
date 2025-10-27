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
    @State private var showFilterOptions = false
    @State private var filterOption: FilterOption = .all
    @Environment(\.dismiss) private var dismiss
    
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
        switch filterOption {
        case .all:
            return cards
        case .owned:
            return cards.filter { collectionManager.isCardCollectedIncludingReprints($0) }
        case .missing:
            return cards.filter { !collectionManager.isCardCollectedIncludingReprints($0) }
        }
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
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(filteredCards) { card in
                                SetCardView(
                                    card: card,
                                    isCollected: collectionManager.isCardCollectedIncludingReprints(card),
                                    quantity: collectionManager.getCollectedQuantityIncludingReprints(for: card),
                                    onTap: {
                                        selectedCard = card
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle(set.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
        .onAppear {
            loadCards()
        }
        .sheet(item: $selectedCard) { card in
            CardDetailSheetView(card: card)
                .environmentObject(collectionManager)
        }
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
}

struct SetCardView: View {
    let card: LorcanaCard
    let isCollected: Bool
    let quantity: Int
    let onTap: () -> Void
    
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
                            isCollected ? card.rarity.color : Color.gray.opacity(0.5),
                            lineWidth: isCollected ? 2 : 1
                        )
                )
                
                // Collection status overlay
                VStack {
                    HStack {
                        Spacer()
                        
                        if isCollected {
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

            // Show buy button for cards not in collection
            if !isCollected {
                CompactBuyButton(card: card)
                    .padding(.top, 4)
            }
        }
        .opacity(isCollected ? 1.0 : 0.6)
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
