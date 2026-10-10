//
//  BinderLayout.swift
//  Inkwell Keeper
//
//  Pure page/pocket math for binders, kept free of SwiftData and SwiftUI so it is
//  easy to unit test.
//
//  Terminology:
//  - sheet:  a physical plastic page you turn.
//  - page:   one face of a sheet. Double-sided sheets have two pages.
//  - pocket: one card position on a page.
//  - slot:   a pocket's global index across the whole binder, counting page by page.
//  - spread: what you see with the binder open — a left and a right page.
//

import Foundation

struct BinderLayout: Equatable, Hashable, Sendable {
    /// Pocket counts offered when creating a binder.
    static let supportedPocketCounts = [4, 9, 12]

    var pocketsPerPage: Int
    var sheetCount: Int
    var isDoubleSided: Bool

    init(pocketsPerPage: Int, sheetCount: Int, isDoubleSided: Bool) {
        self.pocketsPerPage = max(1, pocketsPerPage)
        self.sheetCount = max(1, sheetCount)
        self.isDoubleSided = isDoubleSided
    }

    // MARK: - Grid shape

    /// Columns for a page: 4 → 2×2, 9 → 3×3, 12 → 4×3 (landscape pockets rows of four).
    var columns: Int {
        switch pocketsPerPage {
        case 4: 2
        case 9: 3
        case 12: 4
        default: max(1, Int(Double(pocketsPerPage).squareRoot().rounded(.up)))
        }
    }

    var rows: Int {
        (pocketsPerPage + columns - 1) / columns
    }

    // MARK: - Counts

    var pagesPerSheet: Int { isDoubleSided ? 2 : 1 }
    var pageCount: Int { sheetCount * pagesPerSheet }
    var totalSlots: Int { pageCount * pocketsPerPage }

    /// Sheets needed so `cardCount` cards fit.
    func sheetsNeeded(for cardCount: Int) -> Int {
        let perSheet = pocketsPerPage * pagesPerSheet
        return max(1, (cardCount + perSheet - 1) / perSheet)
    }

    // MARK: - Slot ↔ position

    func slot(page: Int, pocket: Int) -> Int {
        page * pocketsPerPage + pocket
    }

    func position(of slot: Int) -> (page: Int, pocket: Int) {
        (slot / pocketsPerPage, slot % pocketsPerPage)
    }

    func slots(onPage page: Int) -> Range<Int> {
        let start = page * pocketsPerPage
        return start..<(start + pocketsPerPage)
    }

    func contains(slot: Int) -> Bool {
        slot >= 0 && slot < totalSlots
    }

    // MARK: - Spreads

    /// With double-sided sheets the first spread shows the inside cover on the left and
    /// page 0 on the right; after that each spread pairs the back of one sheet with the
    /// front of the next. Single-sided binders show one page per spread, on the right.
    var spreadCount: Int {
        isDoubleSided ? spread(containing: pageCount - 1) + 1 : pageCount
    }

    func pages(inSpread spread: Int) -> (left: Int?, right: Int?) {
        guard isDoubleSided else {
            return (nil, spread < pageCount ? spread : nil)
        }
        if spread == 0 { return (nil, 0) }
        let left = spread * 2 - 1
        let right = spread * 2
        return (left < pageCount ? left : nil, right < pageCount ? right : nil)
    }

    func spread(containing page: Int) -> Int {
        guard isDoubleSided else { return page }
        return page == 0 ? 0 : (page + 1) / 2
    }

    // MARK: - Placement

    /// First empty slot at or after `start`, or nil if the binder is full.
    func firstEmptySlot(occupied: Set<Int>, startingAt start: Int = 0) -> Int? {
        var slot = max(0, start)
        while slot < totalSlots {
            if !occupied.contains(slot) { return slot }
            slot += 1
        }
        return nil
    }

    /// Maps each occupied slot to its new slot when every gap is closed, keeping order.
    static func compactionMap(occupied: [Int]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        for (newSlot, oldSlot) in occupied.sorted().enumerated() {
            map[oldSlot] = newSlot
        }
        return map
    }
}
