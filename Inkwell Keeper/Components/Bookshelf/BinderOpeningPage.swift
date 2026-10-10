//
//  BinderOpeningPage.swift
//  Inkwell Keeper
//
//  The binder's real first page — sleeves, cards and checklist ghosts — lying under
//  the cover of a binder pulled from the bookshelf, so opening the cover reveals
//  exactly what the binder screen then shows. Display only.
//

import SwiftUI

struct BinderOpeningPage: View {
    let container: StorageContainer

    @Environment(StorageManager.self) private var storageManager
    @State private var model: BinderViewModel
    @State private var ghostsBySlot: [Int: LorcanaCard] = [:]
    @Namespace private var pocketNamespace

    init(container: StorageContainer) {
        self.container = container
        _model = State(initialValue: BinderViewModel(layout: container.binderLayout, isTwoUp: false))
    }

    var body: some View {
        BinderPageView(
            page: 0,
            layout: container.binderLayout,
            itemsBySlot: BinderView.itemsBySlot(container.items ?? []),
            ghostsBySlot: ghostsBySlot,
            model: model,
            namespace: pocketNamespace,
            onTap: { _, _ in },
            onDrop: { _, _ in },
            onRemove: { _ in }
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: container.id) {
            ghostsBySlot = storageManager.checklistGhosts(for: container)
        }
    }
}
