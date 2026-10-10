//
//  StorageContainerScreen.swift
//  Inkwell Keeper
//
//  Navigation destination for a container: binders open as books, everything
//  else as a box.
//

import SwiftUI

struct StorageContainerScreen: View {
    let route: StorageRoute

    var body: some View {
        if route.container.kind.usesSlots {
            BinderView(container: route.container, focusSlot: route.focusSlot, playsIntro: route.playsIntro)
        } else {
            BoxView(container: route.container, playsIntro: route.playsIntro)
        }
    }
}
