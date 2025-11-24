//
//  EmptyStates.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct EmptyCollectionView: View {
    @Binding var showingManualAdd: Bool
    @Binding var showingBulkImport: Bool
    let onScanTapped: () -> Void
    let searchQuery: String

    var isSearching: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: isSearching ? "magnifyingglass" : "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold.opacity(0.6))

            VStack(spacing: 8) {
                Text(isSearching ? "No Results Found" : "Your Collection is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text(isSearching ? "Try adjusting your search or filters" : "Start building your collection!")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }

            // Only show action buttons when collection is truly empty (not searching)
            if !isSearching {
                VStack(spacing: 12) {
                    // Import CSV button (primary action)
                    Button(action: { showingBulkImport = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.headline)
                            Text("Import from Dreamborn")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(LorcanaButtonStyle())

                    // Other options
                    HStack(spacing: 12) {
                        Button(action: { onScanTapped() }) {
                            VStack(spacing: 6) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Scan Cards")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(LorcanaButtonStyle(style: .secondary))

                        Button(action: { showingManualAdd = true }) {
                            VStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Manual Add")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(LorcanaButtonStyle(style: .secondary))
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyWishlistView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "star")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Your Wishlist is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Add cards you're hoping to find!")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
