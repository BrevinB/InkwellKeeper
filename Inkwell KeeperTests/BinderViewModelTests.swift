//
//  BinderViewModelTests.swift
//  Inkwell KeeperTests
//
//  Page navigation and arrange-mode decisions for an open binder.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct BinderViewModelTests {
    /// 9-pocket, 10 double-sided sheets: 20 pages, 180 pockets, 11 spreads.
    private let layout = BinderLayout(pocketsPerPage: 9, sheetCount: 10, isDoubleSided: true)

    @Test func oneUpStepsThroughEveryPage() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        #expect(model.positionCount == 20)
        #expect(model.positionLabel == "Page 1 of 20")
        #expect(!model.canGoBack)
        model.position = 19
        #expect(!model.canGoForward)
    }

    @Test func twoUpStepsThroughSpreads() {
        let model = BinderViewModel(layout: layout, isTwoUp: true)
        #expect(model.positionCount == 11)
        #expect(model.positionLabel == "Page 1 of 20")
        model.position = 1
        #expect(model.positionLabel == "Pages 2–3 of 20")
    }

    @Test func focusingASlotOpensToItsPage() {
        // Slot 40 is page 4 (0-based), pocket 4.
        let oneUp = BinderViewModel(layout: layout, isTwoUp: false, focusSlot: 40)
        #expect(oneUp.position == 4)
        #expect(oneUp.focusedSlot == 40)

        let twoUp = BinderViewModel(layout: layout, isTwoUp: true, focusSlot: 40)
        #expect(twoUp.pages(at: twoUp.position).left == 3 || twoUp.pages(at: twoUp.position).right == 4)
        #expect(twoUp.position == 2)
    }

    @Test func switchingToSpreadsKeepsThePageInView() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        model.position = 7
        model.setTwoUp(true)
        let visible = model.pages(at: model.position)
        #expect(visible.left == 7 || visible.right == 7)

        model.setTwoUp(false)
        #expect([7, 8].contains(model.position))
    }

    @Test func shrinkingTheBinderClampsThePosition() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        model.position = 19
        model.updateLayout(BinderLayout(pocketsPerPage: 9, sheetCount: 2, isDoubleSided: true))
        #expect(model.position == 3)
    }

    @Test func turnRequestsRespectTheEnds() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        model.requestTurn(forward: false)
        #expect(model.turnRequest == nil)
        model.requestTurn(forward: true)
        #expect(model.turnRequest?.forward == true)
    }

    // MARK: - Tap decisions

    @Test func browsingTapsOpenCardsAndFillEmptyPockets() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        let card = UUID()
        #expect(model.action(forTapOnSlot: 3, occupant: card) == .open(card))
        #expect(model.action(forTapOnSlot: 3, occupant: nil) == .fill(slot: 3))
    }

    @Test func arrangeModePicksUpThenMoves() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        model.isEditing = true
        let card = UUID()
        let other = UUID()

        #expect(model.action(forTapOnSlot: 0, occupant: card) == .pickUp(card))
        model.pickedUpItemId = card
        #expect(model.action(forTapOnSlot: 0, occupant: card) == .putDown)
        #expect(model.action(forTapOnSlot: 5, occupant: nil) == .move(card, toSlot: 5))
        #expect(model.action(forTapOnSlot: 6, occupant: other) == .move(card, toSlot: 6))
    }

    @Test func leavingArrangeModeDropsThePickedUpCard() {
        let model = BinderViewModel(layout: layout, isTwoUp: false)
        model.isEditing = true
        model.pickedUpItemId = UUID()
        model.isEditing = false
        #expect(model.pickedUpItemId == nil)
    }
}
