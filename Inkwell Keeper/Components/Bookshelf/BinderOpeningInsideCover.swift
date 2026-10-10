//
//  BinderOpeningInsideCover.swift
//  Inkwell Keeper
//
//  The inside of a pulled binder's front cover — name plate, value and set
//  progress — shown as the cover swings over to the left on a two-page spread,
//  matching what the binder screen then shows there. Display only.
//

import SwiftUI

struct BinderOpeningInsideCover: View {
    let container: StorageContainer

    @Environment(StorageManager.self) private var storageManager
    @State private var value: Double = 0
    @State private var setProgress: (filled: Int, total: Int)?

    var body: some View {
        BinderInsideCover(container: container, value: value, setProgress: setProgress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: container.id) {
                value = storageManager.value(of: container)
                let ghosts = storageManager.checklistGhosts(for: container)
                if container.linkedSetName != nil, !ghosts.isEmpty {
                    let itemsBySlot = BinderView.itemsBySlot(container.items ?? [])
                    setProgress = (ghosts.keys.filter { itemsBySlot[$0] != nil }.count, ghosts.count)
                }
            }
    }
}
