//
//  StorageLocationFormatter.swift
//  Inkwell Keeper
//
//  Turns a card's storage locations into one line of text, for exports:
//  "Main Binder (p.3, pocket 5); Amber Trove ×2; Unsorted".
//

import Foundation

enum StorageLocationFormatter {
    /// - Parameters:
    ///   - locations: where copies are stored, in shelf order.
    ///   - owned: copies owned in total; any not accounted for are listed as Unsorted.
    static func describe(_ locations: [StorageAllocation], owned: Int) -> String {
        var parts: [String] = locations.map { location in
            if let pockets = location.pocketSummary {
                return "\(location.containerName) (\(pockets))"
            }
            return location.quantity == 1 ? location.containerName : "\(location.containerName) ×\(location.quantity)"
        }

        let unsorted = owned - locations.reduce(0) { $0 + $1.quantity }
        if unsorted > 0 || parts.isEmpty {
            parts.append(unsorted > 1 ? "Unsorted ×\(unsorted)" : "Unsorted")
        }
        return parts.joined(separator: "; ")
    }
}
