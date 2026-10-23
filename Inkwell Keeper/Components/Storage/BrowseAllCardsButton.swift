//
//  BrowseAllCardsButton.swift
//  Inkwell Keeper
//
//  Empty-state action in the container picker: switch from unsorted copies to the
//  whole catalog, so a card can go straight into a binder without visiting the
//  Collection tab first.
//

import SwiftUI

struct BrowseAllCardsButton: View {
    let action: () -> Void

    var body: some View {
        Button("Browse All Cards", systemImage: "rectangle.stack", action: action)
            .buttonStyle(.borderedProminent)
            .tint(.lorcanaGold)
            .foregroundStyle(Color.lorcanaDark)
    }
}
