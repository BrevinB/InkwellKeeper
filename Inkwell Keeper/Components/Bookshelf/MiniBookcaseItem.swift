//
//  MiniBookcaseItem.swift
//  Inkwell Keeper
//
//  One binder or box on the share card's miniature bookcase, at the card's scale.
//

import SwiftUI

struct MiniBookcaseItem: View {
    let container: StorageContainer
    let slot: BookcaseLayout.Slot
    let scale: CGFloat

    var body: some View {
        Group {
            if slot.isSpine {
                BinderSpineView(name: container.name, color: container.coverColor, style: container.cover)
                    .frame(width: slot.width * scale, height: BookcaseLayout.spineHeight * scale)
            } else {
                ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover)
                    .frame(width: slot.width * scale, height: BookcaseLayout.objectHeight(for: container.kind) * scale)
            }
        }
        .background(alignment: .bottom) {
            Ellipse()
                .fill(.black.opacity(0.6))
                .frame(width: slot.width * scale, height: 5)
                .blur(radius: 2)
                .offset(y: 2)
        }
    }
}
