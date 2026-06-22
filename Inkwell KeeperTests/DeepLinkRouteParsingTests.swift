//
//  DeepLinkRouteParsingTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for DeepLinkRouter.parse — pure URL → route logic.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct DeepLinkRouteParsingTests {
    @Test func parsesDeckCustomScheme() {
        let url = URL(string: "inkwellkeeper://deck?code=IWK:abc123")!
        #expect(DeepLinkRouter.parse(url) == .deck(code: "IWK:abc123"))
    }

    @Test func parsesCardUniversalLink() {
        let url = URL(string: "https://inkwellkeeper.app/card?id=TFC_001_N")!
        #expect(DeepLinkRouter.parse(url) == .card(id: "TFC_001_N"))
    }

    @Test func parsesSetCustomScheme() {
        let url = URL(string: "inkwellkeeper://set?name=Fabled")!
        #expect(DeepLinkRouter.parse(url) == .set(name: "Fabled"))
    }

    @Test func rejectsUnknownScheme() {
        let url = URL(string: "https://example.com/deck?code=x")!
        #expect(DeepLinkRouter.parse(url) == nil)
    }

    @Test func rejectsMissingQuery() {
        let url = URL(string: "inkwellkeeper://deck")!
        #expect(DeepLinkRouter.parse(url) == nil)
    }

    @Test func rejectsUnknownVerb() {
        let url = URL(string: "inkwellkeeper://wishlist?id=1")!
        #expect(DeepLinkRouter.parse(url) == nil)
    }

    @Test func routeTabsMatchContentView() {
        #expect(DeepLinkRoute.deck(code: "x").tab == 3)
        #expect(DeepLinkRoute.card(id: "x").tab == 0)
        #expect(DeepLinkRoute.set(name: "x").tab == 2)
    }
}
