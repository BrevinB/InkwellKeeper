//
//  BookshelfStat.swift
//  Inkwell Keeper
//
//  One figure on the bookshelf placard: a gold number over a small caption.
//

import SwiftUI

struct BookshelfStat: View {
    let value: Text
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            value
                .font(.title3)
                .bold()
                .foregroundStyle(.lorcanaGold)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}
