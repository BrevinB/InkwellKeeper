//
//  AddContainerTile.swift
//  Inkwell Keeper
//
//  The empty spot at the end of the shelf.
//

import SwiftUI

struct AddContainerTile: View {
    var body: some View {
        ShelfSlot(title: String(localized: "Add"), subtitle: " ") {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.lorcanaGold.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .frame(width: 54, height: 70)
                .overlay {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.lorcanaGold)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Add a binder or box")
        .accessibilityAddTraits(.isButton)
    }
}
