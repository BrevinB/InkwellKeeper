//
//  BookcaseItemView.swift
//  Inkwell Keeper
//
//  One container standing on the bookcase: a binder spine-out, or a box face-out
//  with a brass name tag on the shelf edge below it.
//

import SwiftUI

struct BookcaseItemView: View {
    let container: StorageContainer

    var body: some View {
        let slot = BookcaseLayout.slot(for: container)
        Group {
            if slot.isSpine {
                BinderSpineView(name: container.name, color: container.coverColor, style: container.cover)
            } else {
                ContainerArtwork(kind: container.kind, color: container.coverColor, style: container.cover)
            }
        }
        .frame(width: slot.width, height: slot.isSpine ? BookcaseLayout.spineHeight : BookcaseLayout.objectHeight(for: container.kind))
        .background(alignment: .bottom) {
            // Contact shadow where it meets the shelf.
            Ellipse()
                .fill(.black.opacity(0.6))
                .frame(width: slot.width * 1.05, height: 8)
                .blur(radius: 3)
                .offset(y: 3)
        }
    }
}
