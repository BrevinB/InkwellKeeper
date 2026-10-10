//
//  BookshelfEmptyState.swift
//  Inkwell Keeper
//
//  A bare shelf and an invitation to put the first binder or box on it.
//

import SwiftUI

struct BookshelfEmptyState: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BookcaseShelf {
                Color.clear.frame(height: BookcaseLayout.spineHeight * 0.6)
            }

            ContentUnavailableView {
                Label("Your Bookshelf Is Empty", systemImage: "books.vertical")
            } description: {
                Text("Add your binders and boxes, then pull them off the shelf to flip through them.")
            } actions: {
                Button("Add a Binder or Box", systemImage: "plus", action: onCreate)
                    .buttonStyle(.borderedProminent)
                    .tint(.lorcanaGold)
                    .foregroundStyle(.black)
            }
        }
    }
}
