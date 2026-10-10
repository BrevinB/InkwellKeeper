//
//  BookshelfShareSummary.swift
//  Inkwell Keeper
//
//  Everything the "My Bookshelf" share card says about a collection's storage: the
//  binders and boxes in bookcase order, how many cards they hold, what they're
//  worth, and the standout container.
//

import Foundation

struct BookshelfShareSummary {
    /// Binders first, then boxes, as they stand on the bookcase.
    let containers: [StorageContainer]
    let cardCount: Int
    let value: Double
    /// The container worth the most, when anything has a price.
    let showpiece: (name: String, value: Double)?

    init(containers: [StorageContainer], value: (StorageContainer) -> Double) {
        let ordered = BookcaseLayout.ordered(containers)
        let values = ordered.map(value)
        self.containers = ordered
        self.cardCount = ordered.reduce(0) { $0 + $1.cardCount }
        self.value = values.reduce(0, +)
        if let best = zip(ordered, values).max(by: { $0.1 < $1.1 }), best.1 > 0 {
            self.showpiece = (best.0.name, best.1)
        } else {
            self.showpiece = nil
        }
    }

    var binderCount: Int { containers.filter { $0.kind == .binder }.count }
    var boxCount: Int { containers.count - binderCount }
}
