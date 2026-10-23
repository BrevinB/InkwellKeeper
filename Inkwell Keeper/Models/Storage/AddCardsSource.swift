//
//  AddCardsSource.swift
//  Inkwell Keeper
//
//  Where the container picker draws cards from: copies already owned and unsorted,
//  or the whole card catalog. Catalog picks the collector doesn't have unsorted
//  copies of are added to the collection as they're put away.
//

import Foundation

enum AddCardsSource: String, CaseIterable, Identifiable {
    case unsorted
    case allCards

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unsorted: String(localized: "Unsorted")
        case .allCards: String(localized: "All Cards")
        }
    }

    /// Copies the collection must gain so every selected copy can be put away, given
    /// how many of each card are still unsorted. Both keyed by identity.
    static func copiesToAdd(selection: [String: Int], unsorted: [String: Int]) -> Int {
        selection.reduce(0) { total, entry in
            total + max(0, entry.value - (unsorted[entry.key] ?? 0))
        }
    }
}
