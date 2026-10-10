//
//  DeckPullSourceHeader.swift
//  Inkwell Keeper
//
//  "From Main Binder · 7 cards" above a group of pulls.
//

import SwiftUI

struct DeckPullSourceHeader: View {
    let name: String
    let kind: StorageKind?
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: kind?.systemImage ?? "square.stack.3d.down.right")
            Text("From \(name)")
            Spacer()
            Text("^[\(count) card](inflect: true)")
                .monospacedDigit()
        }
        .foregroundStyle(.lorcanaGold)
    }
}
