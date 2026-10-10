//
//  BookcaseLayoutTests.swift
//  Inkwell KeeperTests
//
//  How the Bookshelf tab fills its shelves, and how a pulled container is staged.
//

import Foundation
import Testing
@testable import Inkwell_Keeper

@MainActor
struct BookcaseLayoutTests {
    private let spine = BookcaseLayout.Slot(width: 34, isSpine: true)
    private let box = BookcaseLayout.Slot(width: 120, isSpine: false)

    @Test func bindersStandBeforeBoxesInShelfOrder() {
        let trove = StorageContainer(name: "Trove", kind: .trove)
        let first = StorageContainer(name: "First", kind: .binder)
        let deck = StorageContainer(name: "Deck", kind: .deckBox)
        let second = StorageContainer(name: "Second", kind: .binder)
        let names = BookcaseLayout.ordered([trove, first, deck, second]).map(\.name)
        #expect(names == ["First", "Second", "Trove", "Deck"])
    }

    @Test func booksStandCloseAndBoxesGetRoom() {
        #expect(BookcaseLayout.gap(between: spine, and: spine) == BookcaseLayout.spineGap)
        #expect(BookcaseLayout.gap(between: spine, and: box) == BookcaseLayout.objectGap)
        #expect(BookcaseLayout.gap(between: box, and: box) == BookcaseLayout.objectGap)
    }

    @Test func aFullShelfWrapsOntoTheNext() {
        // Three spines and a gap-separated box fit 34·3 + 2·2 + 18 + 120 = 244.
        let slots = [spine, spine, spine, box, box]
        let rows = BookcaseLayout.rows(for: slots, availableWidth: 244)
        #expect(rows == [[0, 1, 2, 3], [4]])
    }

    @Test func everythingFitsOnOneWideShelf() {
        #expect(BookcaseLayout.rows(for: [spine, box, box], availableWidth: 1_000) == [[0, 1, 2]])
    }

    @Test func anOversizedObjectStillGetsAShelf() {
        let rows = BookcaseLayout.rows(for: [box, spine], availableWidth: 60)
        #expect(rows == [[0], [1]])
    }

    @Test func noContainersMeansNoShelves() {
        #expect(BookcaseLayout.rows(for: [], availableWidth: 300).isEmpty)
    }

    @Test func thickerBindersHaveWiderSpinesWithinLimits() {
        let thin = BookcaseLayout.spineWidth(sheetCount: 1)
        let normal = BookcaseLayout.spineWidth(sheetCount: 20)
        let huge = BookcaseLayout.spineWidth(sheetCount: 500)
        #expect(thin < normal)
        #expect(normal < huge)
        #expect(huge == BookcaseLayout.spineHeight * BookcaseLayout.spineAspect * 1.5)
        #expect(thin == BookcaseLayout.spineHeight * BookcaseLayout.spineAspect * 0.75)
    }

    @Test(arguments: StorageKind.allCases)
    func theStageFitsOnScreenInTheObjectsShape(kind: StorageKind) {
        let screen = CGSize(width: 390, height: 700)
        let stage = BookshelfViewModel.stage(for: kind, in: screen)
        #expect(CGRect(origin: .zero, size: screen).contains(stage))
        let aspect = kind == .binder ? BookshelfViewModel.coverAspect : ContainerArtwork.aspectRatio(for: kind)
        #expect(abs(stage.width / stage.height - aspect) < 0.001)
        #expect(abs(stage.midX - screen.width / 2) < 0.001)
    }

    @Test func withoutMotionTappingOpensStraightAway() {
        let model = BookshelfViewModel()
        let binder = StorageContainer(name: "Binder", kind: .binder)
        model.viewSize = CGSize(width: 390, height: 700)
        model.itemFrames[binder.id] = CGRect(x: 20, y: 200, width: 34, height: 168)
        model.open(binder, animated: false)
        #expect(model.presented?.id == binder.id)
        #expect(model.pull == nil)
    }

    @Test func anUnplacedItemOpensWithoutThePull() {
        let model = BookshelfViewModel()
        let box = StorageContainer(name: "Box", kind: .trove)
        model.viewSize = CGSize(width: 390, height: 700)
        model.open(box, animated: true)
        #expect(model.presented?.id == box.id)
        #expect(model.pull == nil)
    }

    @Test func aPullStartsFromWhereTheItemStands() {
        let model = BookshelfViewModel()
        let binder = StorageContainer(name: "Binder", kind: .binder)
        let frame = CGRect(x: 20, y: 200, width: 34, height: 168)
        model.viewSize = CGSize(width: 390, height: 700)
        model.itemFrames[binder.id] = frame
        model.open(binder, animated: true)
        #expect(model.pull?.container.id == binder.id)
        #expect(model.pull?.source == frame)
        #expect(model.pullCount == 1)
        // Nothing moves or opens until the pulled object is actually on screen;
        // starting in the same update as its insertion would skip the pull.
        #expect(model.travel == 0)
        #expect(model.presented == nil)
        model.pulledObjectAppeared()
        #expect(model.travel == 1)
        // A second tap mid-pull is ignored.
        model.open(StorageContainer(name: "Other", kind: .trove), animated: true)
        #expect(model.pull?.container.id == binder.id)
    }

    // MARK: - Share card

    @Test func aSmallBookcaseIsDrawnAtTheLargestScale() {
        let fitted = BookcaseLayout.fitted([spine, spine, box], availableWidth: 300, maxRows: 3)
        #expect(fitted.scale == 0.62)
        #expect(fitted.overflow == 0)
        #expect(fitted.rows.joined().count == 3)
    }

    @Test func aBigBookcaseShrinksToFitItsShelves() {
        let slots = Array(repeating: box, count: 12)
        let fitted = BookcaseLayout.fitted(slots, availableWidth: 300, maxRows: 3)
        #expect(fitted.scale < 0.62)
        #expect(fitted.rows.count <= 3)
        #expect(fitted.overflow == 0)
    }

    @Test func whatCannotFitIsCountedAsMore() {
        let slots = Array(repeating: box, count: 60)
        let fitted = BookcaseLayout.fitted(slots, availableWidth: 300, maxRows: 3)
        #expect(fitted.rows.count == 3)
        #expect(fitted.overflow == 60 - fitted.rows.joined().count)
        #expect(fitted.overflow > 0)
    }

    @Test func theShareSummaryAddsUpAndPicksTheShowpiece() {
        let binder = StorageContainer(name: "Binder", kind: .binder)
        let trove = StorageContainer(name: "Trove", kind: .trove)
        let deck = StorageContainer(name: "Deck", kind: .deckBox)
        let values: [UUID: Double] = [binder.id: 40, trove.id: 95, deck.id: 0]
        let summary = BookshelfShareSummary(containers: [trove, binder, deck]) { values[$0.id] ?? 0 }
        #expect(summary.containers.map(\.name) == ["Binder", "Trove", "Deck"])
        #expect(summary.binderCount == 1)
        #expect(summary.boxCount == 2)
        #expect(summary.value == 135)
        #expect(summary.showpiece?.name == "Trove")
    }

    @Test func nothingPricedMeansNoShowpiece() {
        let summary = BookshelfShareSummary(containers: [StorageContainer(name: "Binder", kind: .binder)]) { _ in 0 }
        #expect(summary.showpiece == nil)
    }
}
