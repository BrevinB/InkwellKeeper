//
//  CardTextParsingTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the card-text symbol parser that turns {E}/{I}/{S}/{W}/{L}/{IW}
//  tokens and numbered ink costs into renderable segments.
//

import Testing
import UIKit
@testable import Inkwell_Keeper

struct CardTextParsingTests {
    @Test func parsesSymbolTokensInline() {
        let segments = CardTextParser.parse("Gets +2 {S} and +1 {L}.")
        #expect(segments == [
            .text("Gets +2 "),
            .symbol(.strength),
            .text(" and +1 "),
            .symbol(.lore),
            .text(".")
        ])
    }

    @Test func parsesNumberedInkCostAndExert() {
        let segments = CardTextParser.parse("SWEET TECH {2} {E} - Search your deck.")
        #expect(segments == [
            .text("SWEET TECH "),
            .inkCost(2),
            .text(" "),
            .symbol(.exert),
            .text(" - Search your deck.")
        ])
    }

    @Test func parsesInkwellToken() {
        let segments = CardTextParser.parse("Cards count as having {IW}.")
        #expect(segments.contains(.symbol(.inkwell)))
    }

    /// Unknown tokens must stay visible as literal text, never silently vanish
    @Test func unknownTokensStayLiteral() {
        let segments = CardTextParser.parse("Weird {XYZ} token")
        #expect(segments == [.text("Weird {XYZ} token")])
    }

    @Test func plainTextPassesThrough() {
        #expect(CardTextParser.parse("No symbols here.") == [.text("No symbols here.")])
        #expect(CardTextParser.parse("") == [])
    }

    @Test func unclosedBraceStaysLiteral() {
        #expect(CardTextParser.parse("Broken {E") == [.text("Broken {E")])
    }

    @Test func spokenTextReplacesTokensWithNames() {
        let spoken = CardTextParser.spokenText("{E}, {2} {I} - draw a card with {IW}.")
        #expect(spoken == "exert, 2 ink ink - draw a card with inkwell.")
    }

    /// The bundled custom symbols must compile as real symbol images — a template
    /// SVG that actool rejects or downgrades would render at fixed size instead
    /// of scaling with the text.
    @Test func allSymbolAssetsCompileAsSymbolImages() {
        for symbol in CardTextSymbol.allCases {
            let image = UIImage(named: symbol.assetName)
            #expect(image != nil, "missing asset \(symbol.assetName)")
            #expect(image?.isSymbolImage == true, "\(symbol.assetName) is not a symbol image")
        }
    }
}
