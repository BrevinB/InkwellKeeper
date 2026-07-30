//
//  DeckListTextCodecTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the community deck-list text format ("4 Elsa - Snow Queen" per line)
//  used to interoperate with Dreamborn and other Lorcana deck sites.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct DeckListTextCodecTests {
    private func makeCard(
        name: String,
        uniqueId: String? = nil,
        cost: Int = 3,
        variant: CardVariant = .normal
    ) -> LorcanaCard {
        LorcanaCard(
            id: "TST_\(name.replacing(" ", with: "_"))_\(variant.rawValue)",
            name: name,
            cost: cost,
            type: "Character",
            rarity: .rare,
            setName: "The First Chapter",
            imageUrl: "https://example.com/card.png",
            variant: variant,
            uniqueId: uniqueId,
            inkColor: "Amber"
        )
    }

    private var catalog: [LorcanaCard] {
        [
            makeCard(name: "Elsa - Snow Queen", uniqueId: "TFC-042", cost: 8),
            makeCard(name: "Mickey Mouse - Brave Little Tailor", uniqueId: "TFC-115", cost: 8),
            makeCard(name: "Ariel - On Human Legs", uniqueId: "TFC-001", cost: 4),
            makeCard(name: "Be Prepared", uniqueId: "TFC-128", cost: 7),
            makeCard(name: "Hades - King of Olympus", uniqueId: "TFC-005", cost: 8),
            // A foil printing that must never be chosen by the parser.
            makeCard(name: "Elsa - Snow Queen", uniqueId: "TFC-042", cost: 8, variant: .foil)
        ]
    }

    // MARK: - Export

    @Test func exportProducesCommunityFormatLines() {
        let deck = Deck(name: "Test", format: .infinityConstructed)
        deck.cards?.append(DeckCard(from: makeCard(name: "Elsa - Snow Queen", cost: 8), quantity: 4))
        deck.cards?.append(DeckCard(from: makeCard(name: "Be Prepared", cost: 7), quantity: 2))

        let text = DeckListTextCodec.export(deck)

        // Sorted by cost, no headers, no "x" suffix.
        #expect(text == "2 Be Prepared\n4 Elsa - Snow Queen")
    }

    // MARK: - Parsing

    @Test func parsesPlainLines() {
        let result = DeckListTextCodec.parse("4 Elsa - Snow Queen\n2 Be Prepared", cards: catalog)

        #expect(result.unmatched.isEmpty)
        #expect(result.entries.count == 2)
        #expect(result.entries[0].card.name == "Elsa - Snow Queen")
        #expect(result.entries[0].quantity == 4)
        #expect(result.totalMatchedCards == 6)
    }

    @Test func exportRoundTripsThroughParse() {
        let deck = Deck(name: "Round Trip", format: .infinityConstructed)
        deck.cards?.append(DeckCard(from: makeCard(name: "Elsa - Snow Queen", cost: 8), quantity: 4))
        deck.cards?.append(DeckCard(from: makeCard(name: "Ariel - On Human Legs", cost: 4), quantity: 3))

        let result = DeckListTextCodec.parse(DeckListTextCodec.export(deck), cards: catalog)

        #expect(result.unmatched.isEmpty)
        #expect(result.totalMatchedCards == 7)
    }

    @Test func acceptsQuantityWithXSuffix() {
        let result = DeckListTextCodec.parse("4x Elsa - Snow Queen", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].quantity == 4)
    }

    @Test func resolvesSetNumberSuffixViaUniqueId() {
        // Wrong-ish name but a valid (SET) number pin — the suffix wins.
        let result = DeckListTextCodec.parse("4 Elsa (TFC) 42", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].card.uniqueId == "TFC-042")
    }

    @Test func ignoresSetSuffixWithoutNumberAndMatchesByName() {
        let result = DeckListTextCodec.parse("4 Elsa - Snow Queen (TFC)", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].card.name == "Elsa - Snow Queen")
    }

    @Test func matchesCaseAndPunctuationInsensitively() {
        let result = DeckListTextCodec.parse("4 elsa – snow queen", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].card.name == "Elsa - Snow Queen")
    }

    @Test func fuzzyMatchesSmallTypos() {
        let result = DeckListTextCodec.parse("4 Elsa - Snow Quen", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].card.name == "Elsa - Snow Queen")
    }

    @Test func sumsDuplicateLines() {
        let result = DeckListTextCodec.parse("2 Be Prepared\n1 Be Prepared", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.entries[0].quantity == 3)
    }

    @Test func reportsUnmatchedLinesInsteadOfDroppingThem() {
        let result = DeckListTextCodec.parse("4 Elsa - Snow Queen\n3 Totally Fake Card", cards: catalog)

        #expect(result.entries.count == 1)
        #expect(result.unmatched.count == 1)
        #expect(result.unmatched[0].text == "3 Totally Fake Card")
        #expect(result.unmatched[0].lineNumber == 2)
    }

    @Test func skipsBlankCommentAndHeaderLines() {
        let text = """
        Deck: My Deck
        Format: Core Constructed
        # a comment

        4 Elsa - Snow Queen
        Exported from Ink Well Keeper
        """
        let result = DeckListTextCodec.parse(text, cards: catalog)

        #expect(result.unmatched.isEmpty)
        #expect(result.entries.count == 1)
    }

    @Test func neverResolvesToFoilVariants() {
        let result = DeckListTextCodec.parse("4 Elsa - Snow Queen", cards: catalog)

        #expect(result.entries[0].card.variant == .normal)
    }

    // MARK: - Detection

    @Test func detectsDeckListText() {
        #expect(DeckListTextCodec.looksLikeDeckList("4 Elsa - Snow Queen"))
        #expect(DeckListTextCodec.looksLikeDeckList("some intro\n2x Be Prepared"))
        #expect(!DeckListTextCodec.looksLikeDeckList("IWK2:abc123"))
        #expect(!DeckListTextCodec.looksLikeDeckList("just some prose with no cards"))
    }
}
