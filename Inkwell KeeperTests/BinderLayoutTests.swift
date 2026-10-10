//
//  BinderLayoutTests.swift
//  Inkwell KeeperTests
//
//  Page, pocket and spread math for binders. Off-by-one errors here would put cards in
//  the wrong pocket on screen compared to the collector's real binder.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct BinderLayoutTests {
    private let nineDouble = BinderLayout(pocketsPerPage: 9, sheetCount: 20, isDoubleSided: true)
    private let fourSingle = BinderLayout(pocketsPerPage: 4, sheetCount: 10, isDoubleSided: false)

    // MARK: - Shape

    @Test func gridShapeMatchesRealPages() {
        #expect(BinderLayout(pocketsPerPage: 4, sheetCount: 1, isDoubleSided: true).columns == 2)
        #expect(BinderLayout(pocketsPerPage: 4, sheetCount: 1, isDoubleSided: true).rows == 2)
        #expect(nineDouble.columns == 3)
        #expect(nineDouble.rows == 3)
        let twelve = BinderLayout(pocketsPerPage: 12, sheetCount: 1, isDoubleSided: true)
        #expect(twelve.columns == 4)
        #expect(twelve.rows == 3)
    }

    @Test func doubleSidedSheetsHoldTwoPages() {
        #expect(nineDouble.pageCount == 40)
        #expect(nineDouble.totalSlots == 360)
        #expect(fourSingle.pageCount == 10)
        #expect(fourSingle.totalSlots == 40)
    }

    @Test func invalidConfigurationIsClampedToOne() {
        let layout = BinderLayout(pocketsPerPage: 0, sheetCount: -3, isDoubleSided: false)
        #expect(layout.pocketsPerPage == 1)
        #expect(layout.sheetCount == 1)
    }

    // MARK: - Slots

    @Test func slotAndPositionRoundTrip() {
        for slot in [0, 8, 9, 17, 359] {
            let position = nineDouble.position(of: slot)
            #expect(nineDouble.slot(page: position.page, pocket: position.pocket) == slot)
        }
        #expect(nineDouble.position(of: 9) == (page: 1, pocket: 0))
        #expect(nineDouble.slots(onPage: 2) == 18..<27)
    }

    @Test func containsRejectsOutOfRangeSlots() {
        #expect(nineDouble.contains(slot: 0))
        #expect(nineDouble.contains(slot: 359))
        #expect(!nineDouble.contains(slot: 360))
        #expect(!nineDouble.contains(slot: -1))
    }

    @Test func sheetsNeededRoundsUp() {
        #expect(nineDouble.sheetsNeeded(for: 18) == 1)
        #expect(nineDouble.sheetsNeeded(for: 19) == 2)
        #expect(nineDouble.sheetsNeeded(for: 100) == 6)
        #expect(nineDouble.sheetsNeeded(for: 0) == 1)
        #expect(fourSingle.sheetsNeeded(for: 9) == 3)
    }

    // MARK: - Spreads

    /// Opening a real binder shows the inside cover beside page 1, then the back of each
    /// sheet beside the front of the next.
    @Test func doubleSidedSpreadsPairBackAndFront() {
        #expect(nineDouble.pages(inSpread: 0) == (left: nil, right: 0))
        #expect(nineDouble.pages(inSpread: 1) == (left: 1, right: 2))
        #expect(nineDouble.pages(inSpread: 2) == (left: 3, right: 4))
        // 40 pages: the last spread is page 39 alone on the left.
        #expect(nineDouble.spreadCount == 21)
        #expect(nineDouble.pages(inSpread: 20) == (left: 39, right: nil))
    }

    @Test func spreadContainingPageIsInverseOfPagesInSpread() {
        for page in 0..<nineDouble.pageCount {
            let spread = nineDouble.spread(containing: page)
            let pages = nineDouble.pages(inSpread: spread)
            #expect(pages.left == page || pages.right == page)
        }
    }

    @Test func singleSidedShowsOnePagePerSpread() {
        #expect(fourSingle.spreadCount == 10)
        #expect(fourSingle.pages(inSpread: 3) == (left: nil, right: 3))
        #expect(fourSingle.spread(containing: 7) == 7)
    }

    // MARK: - Placement

    @Test func firstEmptySlotSkipsOccupiedPockets() {
        #expect(nineDouble.firstEmptySlot(occupied: []) == 0)
        #expect(nineDouble.firstEmptySlot(occupied: [0, 1, 3]) == 2)
        #expect(nineDouble.firstEmptySlot(occupied: [0, 1, 3], startingAt: 3) == 4)
    }

    @Test func firstEmptySlotIsNilWhenFull() {
        let tiny = BinderLayout(pocketsPerPage: 4, sheetCount: 1, isDoubleSided: false)
        #expect(tiny.firstEmptySlot(occupied: [0, 1, 2, 3]) == nil)
    }

    @Test func compactionClosesGapsAndKeepsOrder() {
        let map = BinderLayout.compactionMap(occupied: [12, 3, 7])
        #expect(map == [3: 0, 7: 1, 12: 2])
    }
}
