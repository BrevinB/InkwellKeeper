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
    
    var body: some View {
        NavigationView {
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
                        LazyVStack(spacing: 12) {
                            ForEach(dataManager.getAllSets()) { set in
                                SetProgressCard(
                                    set: set,
                                    collectionManager: collectionManager,
                                    dataManager: dataManager,
                                    onTap: {
                                        selectedSet = set
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
                        dataManager.refreshPricesInBackground()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .sheet(item: $selectedSet) { set in
            SetDetailView(set: set)
                .environmentObject(collectionManager)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(set.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
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

#Preview {
    SetsView()
        .environmentObject(CollectionManager())
}