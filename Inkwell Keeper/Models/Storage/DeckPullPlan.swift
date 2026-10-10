//
//  DeckPullPlan.swift
//  Inkwell Keeper
//
//  What it takes to assemble a built deck in its deck box: which copies to pull from
//  where, and what's missing entirely.
//

import Foundation

struct DeckPullPlan {
    /// One trip to one place: "2× Elsa from Main Binder, p.3 pockets 5–6".
    struct Pull: Identifiable {
        let card: LorcanaCard
        /// Nil means Unsorted.
        let sourceId: UUID?
        let sourceName: String
        let sourceKind: StorageKind?
        let quantity: Int
        /// Binder pockets to pull from, as global slots (empty for boxes and Unsorted).
        let slots: [Int]
        let pockets: [StorageAllocation.BinderPocket]

        var id: String { "\(sourceId?.uuidString ?? "unsorted")|\(CollectionManager.identityKey(for: card))" }
    }

    /// Copies the deck needs that aren't anywhere they can be pulled from.
    struct Shortfall: Identifiable {
        let card: LorcanaCard
        let quantity: Int
        var id: String { CollectionManager.identityKey(for: card) }
    }

    var pulls: [Pull] = []
    var missing: [Shortfall] = []
    /// Deck copies already in the box.
    var inBox = 0
    /// Copies the deck calls for.
    var total = 0

    var toPull: Int { pulls.reduce(0) { $0 + $1.quantity } }
    var missingCount: Int { missing.reduce(0) { $0 + $1.quantity } }
    var isComplete: Bool { inBox >= total }

    /// Pulls grouped by where they come from, Unsorted first, so the collector can
    /// empty one binder or box at a time.
    var pullsBySource: [(sourceName: String, sourceKind: StorageKind?, pulls: [Pull])] {
        var order: [String] = []
        var groups: [String: [Pull]] = [:]
        for pull in pulls {
            let key = pull.sourceId?.uuidString ?? "unsorted"
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(pull)
        }
        return order.compactMap { key in
            guard let group = groups[key], let first = group.first else { return nil }
            let sorted = group.sorted { ($0.slots.first ?? .max, $0.card.name) < ($1.slots.first ?? .max, $1.card.name) }
            return (first.sourceName, first.sourceKind, sorted)
        }
    }
}
