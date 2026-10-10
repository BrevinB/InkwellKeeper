//
//  BookcaseShelf.swift
//  Inkwell Keeper
//
//  One shelf of the bookcase: its objects standing bottom-aligned on a plank that
//  runs between the bookcase's side posts.
//

import SwiftUI

struct BookcaseShelf<Content: View>: View {
    @ViewBuilder let content: () -> Content

    /// Space between a side post and the first or last object.
    static var inset: CGFloat { BookcasePost.width + 12 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.inset)
            .padding(.top, 26)
            // Sink objects into the plank's top surface so they stand on it.
            .offset(y: ShelfMetrics.footing)
            .zIndex(1)

            ShelfPlank()
                .padding(.horizontal, BookcasePost.width)
        }
    }
}
