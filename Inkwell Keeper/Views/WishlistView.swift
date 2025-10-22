//
//  WishlistView.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct WishlistView: View {
    @EnvironmentObject var collectionManager: CollectionManager
    @State private var showingAddToWishlist = false
    
    var body: some View {
        NavigationView {
            VStack {
                if collectionManager.wishlistCards.isEmpty {
                    EmptyWishlistView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(collectionManager.wishlistCards) { card in
                                WishlistCardRow(card: card)
                                    .environmentObject(collectionManager)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(LorcanaBackground())
            .navigationTitle("Wishlist")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddToWishlist = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.lorcanaGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddToWishlist) {
            AddToWishlistView()
                .environmentObject(collectionManager)
        }
    }
}
