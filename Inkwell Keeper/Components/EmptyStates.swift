//
//  EmptyStates.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct EmptyCollectionView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundColor(.lorcanaGold.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Your Collection is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Start by scanning some cards or adding them manually!")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button("Scan Cards") {
                    // TODO: Switch to scanner tab
                }
                .buttonStyle(LorcanaButtonStyle())
                
                Button("Manual Add") {
                    // TODO: Show manual add sheet
                }
                .buttonStyle(LorcanaButtonStyle(style: .secondary))
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
