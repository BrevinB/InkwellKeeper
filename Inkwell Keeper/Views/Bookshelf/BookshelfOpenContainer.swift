//
//  BookshelfOpenContainer.swift
//  Inkwell Keeper
//
//  A binder or box opened from the bookshelf, full screen with its own navigation
//  bar and a Done button to put it back. Presented rather than pushed so it never
//  nests inside the More tab's navigation on iPhone.
//

import SwiftUI

struct BookshelfOpenContainer: View {
    let container: StorageContainer
    let playsIntro: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StorageContainerScreen(route: StorageRoute(container: container, playsIntro: playsIntro))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
