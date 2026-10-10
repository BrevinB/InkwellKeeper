//
//  BookcasePost.swift
//  Inkwell Keeper
//
//  One upright side of the bookcase.
//

import SwiftUI

struct BookcasePost: View {
    static let width: CGFloat = 12

    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.4, green: 0.26, blue: 0.15), Color(red: 0.24, green: 0.15, blue: 0.09)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .overlay { WoodGrain().opacity(0.3) }
        .frame(width: Self.width)
        .shadow(color: .black.opacity(0.5), radius: 4)
    }
}
