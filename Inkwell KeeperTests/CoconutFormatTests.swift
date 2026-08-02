//
//  CoconutFormatTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for Format [Coconut] (beta) support: leader-aware copy limits,
//  deck validation, and the share-code leader field.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct CoconutFormatTests {
    private func makeCoconutDeck(leader: String? = "Ariel – Spectacular Singer") -> Deck {
        Deck(
            name: "Coconut Test",
            format: .coconut,
            inkColors: [.amber, .amethyst],
            coconutLeader: leader
        )
    }

    private func makeCard(name: String, inkColor: String = "Amber") -> LorcanaCard {
        LorcanaCard(
            id: "TST_\(name.replacing(" ", with: "_"))",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: "The First Chapter",
            imageUrl: "https://example.com/card.png",
            inkwell: true,
            inkColor: inkColor
        )
    }

    // MARK: - Copy limits

    @Test func coconutIsSingletonByDefault() {
        let deck = makeCoconutDeck()
        #expect(deck.maxCopies(ofCardNamed: "Be Prepared") == 1)
    }

    @Test func leaderAssociatedCardAllowsFourCopies() {
        let deck = makeCoconutDeck()
        #expect(deck.maxCopies(ofCardNamed: "Ariel - Spectacular Singer") == 4)
    }

    @Test func copyLimitMatchingIgnoresDashStyle() {
        let deck = makeCoconutDeck()
        // Leader data uses en dashes; card database uses hyphens.
        #expect(deck.maxCopies(ofCardNamed: "Ariel – Spectacular Singer") == 4)
    }

    @Test func nickWildeAlsoUnlocksPawpsicle() {
        let deck = makeCoconutDeck(leader: "Nick Wilde – Wily Fox")
        #expect(deck.maxCopies(ofCardNamed: "Pawpsicle") == 4)
        #expect(deck.maxCopies(ofCardNamed: "Nick Wilde - Wily Fox") == 4)
        #expect(deck.maxCopies(ofCardNamed: "Judy Hopps - Optimistic Officer") == 1)
    }

    @Test func noLeaderMeansStrictSingleton() {
        let deck = makeCoconutDeck(leader: nil)
        #expect(deck.maxCopies(ofCardNamed: "Ariel - Spectacular Singer") == 1)
    }

    @Test func otherFormatsKeepFourCopyLimit() {
        let deck = Deck(name: "Core", format: .coreConstructed, inkColors: [.amber])
        #expect(deck.maxCopies(ofCardNamed: "Be Prepared") == 4)
    }

    // MARK: - Validation

    @Test func missingLeaderIsAnError() {
        let deck = makeCoconutDeck(leader: nil)
        let validation = DeckValidation.validate(deck)
        #expect(validation.errors.contains { $0.localizedStandardContains("leader") })
    }

    @Test func leaderInkMustBeInDeckInks() {
        // Ariel is Amber; deck runs Ruby/Sapphire only.
        let deck = Deck(
            name: "Wrong Inks",
            format: .coconut,
            inkColors: [.ruby, .sapphire],
            coconutLeader: "Ariel – Spectacular Singer"
        )
        let validation = DeckValidation.validate(deck)
        #expect(validation.errors.contains { $0.localizedStandardContains("Amber") })
    }

    @Test func singletonViolationIsAnError() {
        let deck = makeCoconutDeck()
        deck.cards?.append(DeckCard(from: makeCard(name: "Be Prepared"), quantity: 2))
        let validation = DeckValidation.validate(deck)
        #expect(validation.errors.contains { $0.localizedStandardContains("Be Prepared") })
    }

    @Test func fourCopiesOfAssociatedCardIsLegal() {
        let deck = makeCoconutDeck()
        deck.cards?.append(DeckCard(from: makeCard(name: "Ariel - Spectacular Singer"), quantity: 4))
        let validation = DeckValidation.validate(deck)
        #expect(!validation.errors.contains { $0.localizedStandardContains("Ariel") })
    }

    @Test func allEighteenLeadersExistThreePerInk() {
        #expect(CoconutLeaders.all.count == 18)
        for ink in InkColor.allCases {
            #expect(CoconutLeaders.leaders(for: ink).count == 3)
        }
    }

    // MARK: - Leader image matching

    @Test func lorcastImagesMatchLeadersDashInsensitively() {
        // The API uses hyphens; leader data uses en dashes.
        let matched = CoconutLeaderImageService.matchImages(apiCards: [
            (fullName: "Ariel - Spectacular Singer", imageUrl: "https://example.com/ariel.avif"),
            (fullName: "Some Unrelated Card", imageUrl: "https://example.com/nope.avif")
        ])

        #expect(matched.count == 1)
        #expect(matched["Ariel – Spectacular Singer"] == "https://example.com/ariel.avif")
    }

    // MARK: - Share code wire format

    @Test func shareCodePayloadCarriesLeader() throws {
        let payload = DeckManager.CompactShareableDeck(
            name: "Coconut Deck",
            description: "",
            format: DeckFormat.coconut.rawValue,
            inkColors: ["Amber"],
            archetype: nil,
            coconutLeader: "Ariel – Spectacular Singer",
            cards: []
        )
        let data = try JSONEncoder().encode(payload)
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains("\"l\""))

        let decoded = try JSONDecoder().decode(DeckManager.CompactShareableDeck.self, from: data)
        #expect(decoded.coconutLeader == "Ariel – Spectacular Singer")
    }

    @Test func oldPayloadsWithoutLeaderStillDecode() throws {
        let legacyJSON = #"{"n":"Old Deck","d":"","f":"Casual","i":["Amber"],"c":[]}"#
        let decoded = try JSONDecoder().decode(
            DeckManager.CompactShareableDeck.self,
            from: Data(legacyJSON.utf8)
        )
        #expect(decoded.coconutLeader == nil)
        #expect(decoded.name == "Old Deck")
    }
}
