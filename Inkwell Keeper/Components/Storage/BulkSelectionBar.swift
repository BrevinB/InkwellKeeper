//
//  BulkSelectionBar.swift
//  Inkwell Keeper
//
//  The bar along the bottom of a binder or box while selecting cards: how many are
//  chosen, Select All / Deselect All, and Move.
//

import SwiftUI

struct BulkSelectionBar: View {
    /// Copies selected (a box row can hold several).
    let selectedCopies: Int
    let allSelected: Bool
    let onToggleAll: () -> Void
    let onMove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(allSelected ? "Deselect All" : "Select All", action: onToggleAll)
                .buttonStyle(.bordered)

            Group {
                if selectedCopies == 0 {
                    Text("Tap cards to select")
                } else {
                    Text("^[\(selectedCopies) card](inflect: true) selected")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)

            Button("Move…", systemImage: "arrow.right.square", action: onMove)
                .buttonStyle(.borderedProminent)
                .foregroundStyle(Color.lorcanaDark)
                .disabled(selectedCopies == 0)
        }
        .tint(.lorcanaGold)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
