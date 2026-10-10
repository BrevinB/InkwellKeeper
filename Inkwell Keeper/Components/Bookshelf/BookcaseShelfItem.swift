//
//  BookcaseShelfItem.swift
//  Inkwell Keeper
//
//  A tappable container on the bookcase. It reports where it stands so the pull
//  animation can start from exactly there, and goes missing from its gap while
//  it's off the shelf. Boxes carry a brass name tag on the shelf edge.
//

import SwiftUI

struct BookcaseShelfItem: View {
    let container: StorageContainer
    let model: BookshelfViewModel
    let isFull: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let isBinder = container.kind == .binder
        Button(action: onOpen) {
            BookcaseItemView(container: container)
                .opacity(model.pull?.container.id == container.id ? 0 : 1)
        }
        .buttonStyle(.plain)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(BookshelfView.coordinateSpace))
        } action: { frame in
            model.itemFrames[container.id] = frame
        }
        .overlay(alignment: .bottom) {
            if !isBinder {
                BrassTag(text: container.name)
                    .frame(maxWidth: BookcaseLayout.slot(for: container).width + 24)
                    .offset(y: 17)
            }
        }
        .contextMenu {
            Button("Open", systemImage: "arrow.up.forward.app", action: onOpen)
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(container.name), \(container.kind.displayName)")
        .accessibilityValue(isFull ? "\(container.cardCount) cards, full" : "\(container.cardCount) cards")
        .accessibilityHint(isBinder ? "Takes the binder off the shelf and opens it" : "Takes the box off the shelf and opens it")
    }
}
