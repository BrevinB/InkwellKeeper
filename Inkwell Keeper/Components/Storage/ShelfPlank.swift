//
//  ShelfPlank.swift
//  Inkwell Keeper
//
//  A wooden shelf: a lit top surface objects stand on, a darker front edge with
//  grain and a gold trim line, and a soft shadow on the wall beneath.
//

import SwiftUI

struct ShelfPlank: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top surface, seen slightly from above.
            LinearGradient(
                colors: [Color(red: 0.55, green: 0.38, blue: 0.22), Color(red: 0.42, green: 0.28, blue: 0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 7)

            // Front edge.
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [Color(red: 0.34, green: 0.21, blue: 0.12), Color(red: 0.22, green: 0.13, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                WoodGrain()
                    .opacity(0.35)
                Rectangle()
                    .fill(Color.lorcanaGold.opacity(0.55))
                    .frame(height: 1)
            }
            .frame(height: ShelfMetrics.plankHeight - 7)

            // Shadow cast on the wall below.
            LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 12)
        }
        .clipShape(.rect(cornerRadius: 2))
        .accessibilityHidden(true)
    }
}
