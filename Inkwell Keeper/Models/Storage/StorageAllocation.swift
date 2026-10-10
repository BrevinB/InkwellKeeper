//
//  StorageAllocation.swift
//  Inkwell Keeper
//
//  "Where is this card?" — how many copies of a card sit in one container.
//

import Foundation

struct StorageAllocation: Identifiable, Equatable, Sendable {
    let containerId: UUID
    let containerName: String
    let kind: StorageKind
    let quantity: Int
    /// For binders, the page (1-based) and pocket (1-based) of each copy, in slot order.
    let pockets: [BinderPocket]

    var id: UUID { containerId }

    struct BinderPocket: Equatable, Sendable {
        let page: Int
        let pocket: Int
    }

    /// Short location text, e.g. "p.3, pocket 5" or "p.3–7 (4 pockets)".
    var pocketSummary: String? {
        guard let first = pockets.first else { return nil }
        if pockets.count == 1 {
            return "p.\(first.page), pocket \(first.pocket)"
        }
        let pages = Set(pockets.map(\.page)).sorted()
        if pages.count == 1 {
            return "p.\(first.page) (\(pockets.count) pockets)"
        }
        return "p.\(pages[0])–\(pages[pages.count - 1]) (\(pockets.count) pockets)"
    }
}
