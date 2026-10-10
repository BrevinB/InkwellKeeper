//
//  SetChecklistLayoutTests.swift
//  Inkwell KeeperTests
//
//  Which pocket every card of a set gets, in one-per-card and master-set binders.
//

import Testing
@testable import Inkwell_Keeper

struct SetChecklistLayoutTests {
    /// A Winterspell-shaped set: #1–204 normal, then Epic, Enchanted and Iconic foils.
    private let printings: [Int: CardVariant] = {
        var printings: [Int: CardVariant] = [:]
        for number in 1...204 { printings[number] = .normal }
        for number in 205...222 { printings[number] = .epic }
        for number in 223...240 { printings[number] = .enchanted }
        printings[241] = .iconic
        printings[242] = .iconic
        return printings
    }()

    // MARK: - One per card

    @Test func onePerCardUsesTheCardNumber() {
        let layout = SetChecklistLayout(printings: printings, hasFoilPockets: false)
        #expect(layout.pocketCount == 242)
        #expect(layout.slot(forNumber: 12, variant: .normal) == 11)
        #expect(layout.slot(forNumber: 12, variant: .foil) == 11)
        #expect(layout.slot(forNumber: 230, variant: .enchanted) == 229)
    }

    @Test func aPrintingThatDoesNotMatchGetsNoPocket() {
        let layout = SetChecklistLayout(printings: printings, hasFoilPockets: false)
        #expect(layout.slot(forNumber: 12, variant: .enchanted) == nil)
        #expect(layout.slot(forNumber: 230, variant: .normal) == nil)
    }

    // MARK: - Master set

    @Test func foilPocketsSitBesideTheirNormal() {
        let layout = SetChecklistLayout(printings: printings, hasFoilPockets: true)
        #expect(layout.slot(forNumber: 1, variant: .normal) == 0)
        #expect(layout.slot(forNumber: 1, variant: .foil) == 1)
        #expect(layout.slot(forNumber: 2, variant: .normal) == 2)
        #expect(layout.slot(forNumber: 204, variant: .foil) == 407)
    }

    @Test func foilOnlyPrintingsGetOnePocket() {
        let layout = SetChecklistLayout(printings: printings, hasFoilPockets: true)
        #expect(layout.slot(forNumber: 205, variant: .epic) == 408)
        #expect(layout.slot(forNumber: 206, variant: .epic) == 409)
        // 204 cards × 2 + 38 foil-only printings.
        #expect(layout.pocketCount == 446)
    }

    @Test func ghostsKnowWhichPocketIsTheFoil() {
        let layout = SetChecklistLayout(printings: printings, hasFoilPockets: true)
        #expect(layout.pocket(atSlot: 0) == .init(number: 1, isFoilPocket: false))
        #expect(layout.pocket(atSlot: 1) == .init(number: 1, isFoilPocket: true))
        #expect(layout.pocket(atSlot: 408) == .init(number: 205, isFoilPocket: false))
        #expect(layout.pocket(atSlot: 446) == nil)
    }
}
