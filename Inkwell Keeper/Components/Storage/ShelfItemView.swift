//
//  ShelfItemView.swift
//  Inkwell Keeper
//
//  One container standing on the Collection shelf.
//

import SwiftUI

struct ShelfItemView: View {
    let container: StorageContainer
    var isFull = false

    var body: some View {
        ShelfSlot(
            title: container.name,
            subtitle: "^[\(container.cardCount) card](inflect: true)"
        ) {
            ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover)
                .frame(height: objectHeight)
                .overlay(alignment: .top) {
                    if isFull {
                        FullBadge()
                            .offset(y: -8)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(container.name), \(container.kind.displayName)")
        .accessibilityValue(isFull ? "\(container.cardCount) cards, full" : "\(container.cardCount) cards")
        .accessibilityAddTraits(.isButton)
    }

    /// Binders and deck boxes stand tall; wide boxes sit lower so they don't overflow.
    private var objectHeight: CGFloat {
        switch container.kind {
        case .binder, .deckBox: ShelfMetrics.objectHeight
        case .storageBox: 44
        case .bulkBin: 56
        case .trove, .other: 62
        }
    }
}
