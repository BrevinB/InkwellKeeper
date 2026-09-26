//
//  SetsView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/14/25.
//

import SwiftUI

struct SetsView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @StateObject private var dataManager = SetsDataManager.shared
    @State private var selectedSet: LorcanaSet?
    /// Upcoming set awaiting the "show spoilers?" confirmation.
    @State private var spoilerPromptSet: LorcanaSet?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            VStack {
                if dataManager.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading sets...")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = dataManager.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error loading sets")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            // Data manager handles loading automatically
                        }
                        .buttonStyle(LorcanaButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else if dataManager.getAllSets().isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No sets found")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize ? .flexible() : .adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                            ForEach(dataManager.getAllSets()) { set in
                                SetProgressCard(
                                    set: set,
                                    collectionManager: collectionManager,
                                    dataManager: dataManager,
                                    onTap: {
                                        if SpoilerSettings.shared.isHidden(setName: set.name) {
                                            spoilerPromptSet = set
                                        } else {
                                            selectedSet = set
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Card Sets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Refresh collection data to update counts
                        collectionManager.loadCollection()
                        // Also refresh prices in background
                        dataManager.refreshPricesInBackground()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .confirmationDialog(
            "Show spoilers for \(spoilerPromptSet?.name ?? "this set")?",
            isPresented: Binding(
                get: { spoilerPromptSet != nil },
                set: { if !$0 { spoilerPromptSet = nil } }
            ),
            titleVisibility: .visible,
            presenting: spoilerPromptSet
        ) { set in
            Button("Show Spoilers") {
                SpoilerSettings.shared.reveal(setName: set.name)
                selectedSet = set
            }
            Button("Cancel", role: .cancel) {}
        } message: { set in
            Text("\(set.name) releases \(set.releaseDateFormatted). Its cards are hidden until then unless you choose to see them.")
        }
        .sheet(item: $selectedSet) { set in
            SetDetailView(set: set)
                .environmentObject(collectionManager)
                .presentationSizing(.page)
        }
    }
}

struct SetProgressCard: View {
    let set: LorcanaSet
    let collectionManager: CollectionManager
    let dataManager: SetsDataManager
    let onTap: () -> Void
    
    private var progress: (collected: Int, total: Int, percentage: Double) {
        // Use local card count if available, otherwise use set metadata
        let totalCards = dataManager.hasLocalCards(for: set.name) ? 
            dataManager.getLocalCardCount(for: set.name) : set.cardCount
        return collectionManager.getSetProgress(set.name, totalCardsInSet: totalCards)
    }
    
    var body: some View {
        if SpoilerSettings.shared.isHidden(setName: set.name) {
            HiddenUpcomingSetCard(
                set: set,
                revealedCardCount: dataManager.getLocalCardCount(for: set.name),
                onTap: onTap
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(set.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)

                        if set.isUpcoming() {
                            UpcomingSetBadge(set: set)
                        }

                        Text("\(progress.collected) of \(progress.total) cards")
                            .font(.subheadline)
                            .foregroundColor(.lorcanaGold)
                    }
                
                    Spacer()
                
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(progress.percentage))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.lorcanaGold)
                    
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)
                    
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
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lorcanaDark.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.lorcanaGold.opacity(0.3), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
    }
}

#Preview {
    SetsView()
        .environmentObject(CollectionManager())
}
