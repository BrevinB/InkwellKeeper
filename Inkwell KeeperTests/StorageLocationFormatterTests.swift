//
//  StorageLocationFormatterTests.swift
//  Inkwell KeeperTests
//
//  The export's Location column: one readable line per card.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct StorageLocationFormatterTests {
    private func box(_ name: String, _ quantity: Int) -> StorageAllocation {
        StorageAllocation(containerId: UUID(), containerName: name, kind: .trove, quantity: quantity, pockets: [])
    }

    private func binder(_ name: String, pockets: [(page: Int, pocket: Int)]) -> StorageAllocation {
        StorageAllocation(
            containerId: UUID(),
            containerName: name,
            kind: .binder,
            quantity: pockets.count,
            pockets: pockets.map { StorageAllocation.BinderPocket(page: $0.page, pocket: $0.pocket) }
        )
    }

    @Test func nothingStoredIsUnsorted() {
        #expect(StorageLocationFormatter.describe([], owned: 1) == "Unsorted")
        #expect(StorageLocationFormatter.describe([], owned: 3) == "Unsorted ×3")
    }

    @Test func binderCopiesShowTheirPocket() {
        let text = StorageLocationFormatter.describe([binder("Main Binder", pockets: [(3, 5)])], owned: 1)
        #expect(text == "Main Binder (p.3, pocket 5)")
    }

    @Test func boxesShowCountsOnlyWhenMoreThanOne() {
        #expect(StorageLocationFormatter.describe([box("Trove", 1)], owned: 1) == "Trove")
        #expect(StorageLocationFormatter.describe([box("Trove", 2)], owned: 2) == "Trove ×2")
    }

    @Test func splitCopiesListEveryPlaceAndTheRemainder() {
        let text = StorageLocationFormatter.describe(
            [binder("Main Binder", pockets: [(1, 1)]), box("Trove", 2)],
            owned: 4
        )
        #expect(text == "Main Binder (p.1, pocket 1); Trove ×2; Unsorted")
    }
}
