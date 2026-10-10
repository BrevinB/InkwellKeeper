//
//  MiniBookcase.swift
//  Inkwell Keeper
//
//  A small copy of the user's bookcase for the share card: their actual binders
//  (spine-out, named, in their colors and finishes) and boxes on wooden shelves,
//  scaled to fit. Anything that won't fit gets a "+N more" tag.
//

import SwiftUI

struct MiniBookcase: View {
    let containers: [StorageContainer]
    /// Width available for the shelves themselves.
    let shelfWidth: CGFloat
    var maxRows = 3

    var body: some View {
        let slots = containers.map(BookcaseLayout.slot(for:))
        let fitted = BookcaseLayout.fitted(slots, availableWidth: shelfWidth, maxRows: maxRows)
        let scale = fitted.scale

        VStack(spacing: 0) {
            ForEach(fitted.rows, id: \.self) { row in
                VStack(spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(row, id: \.self) { index in
                            MiniBookcaseItem(container: containers[index], slot: slots[index], scale: scale)
                                .padding(.leading, index == row.first ? 0 : BookcaseLayout.gap(between: slots[index - 1], and: slots[index]) * scale)
                        }
                        if row == fitted.rows.last, fitted.overflow > 0 {
                            BrassTag(text: "+\(fitted.overflow) more")
                                .padding(.leading, 10)
                                .padding(.bottom, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .offset(y: ShelfMetrics.footing * scale)
                    .zIndex(1)

                    ShelfPlank()
                }
            }
        }
        .padding(.bottom, 6)
        .background { BookcaseBackdrop() }
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.lorcanaGold.opacity(0.35), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}
