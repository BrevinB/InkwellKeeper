//
//  StorageRoute.swift
//  Inkwell Keeper
//
//  Navigation value for opening a container, optionally at a specific binder pocket.
//

import Foundation

struct StorageRoute: Hashable {
    let container: StorageContainer
    var focusSlot: Int?
    /// Whether the screen plays its own opening (cover swinging open, lid lifting).
    /// The bookshelf turns this off because its pull has already opened the container.
    var playsIntro = true
}
