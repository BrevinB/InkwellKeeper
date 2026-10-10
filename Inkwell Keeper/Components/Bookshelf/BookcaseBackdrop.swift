//
//  BookcaseBackdrop.swift
//  Inkwell Keeper
//
//  The bookcase itself: a dark wooden back panel with faint grain and an upright
//  post down each side, behind the shelves.
//

import SwiftUI

struct BookcaseBackdrop: View {
    var body: some View {
        ZStack {
            // Back panel, lit from above.
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.13, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            WoodGrain()
                .opacity(0.12)

            HStack {
                BookcasePost()
                Spacer()
                BookcasePost()
            }
        }
        .accessibilityHidden(true)
    }
}
