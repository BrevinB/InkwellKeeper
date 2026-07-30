//
//  DeckShareCodeTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for deck share-code generation and decoding — the payload behind
//  QR deck sharing and inkwellkeeper://deck deep links.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct DeckShareCodeTests {
    /// Builds a realistic 60-card deck (15 unique × 4) without touching SwiftData persistence.
    private func makeDeck(uniqueCards: Int = 15, copiesEach: Int = 4) -> Deck {
        let deck = Deck(
            name: "Test Deck",
            description: "Round-trip test",
            format: .infinityConstructed,
            inkColors: [.amber, .steel]
        )
        for index in 0..<uniqueCards {
            let card = LorcanaCard(
                id: "TST_\(index)_N_Card_Number_\(index)_With_A_Long_Name",
                name: "Card \(index)",
                cost: (index % 8) + 1,
                type: "Character",
                rarity: .rare,
                setName: "The First Chapter",
                imageUrl: "https://example.com/images/card_\(index)_large.png",
                inkwell: index.isMultiple(of: 2),
                inkColor: "Amber"
            )
            let deckCard = DeckCard(from: card, quantity: copiesEach)
            deck.cards?.append(deckCard)
        }
        return deck
    }

    @Test func generatedCodeUsesCompactFormat() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())

        #expect(code != nil)
        #expect(code?.hasPrefix("IWK2:") == true)
    }

    @Test func generatedCodePreviewsCorrectly() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!
        let preview = manager.previewShareCode(code)

        #expect(preview?.name == "Test Deck")
        #expect(preview?.totalCards == 60)
    }

    @Test func realisticDeckFitsInQRDeepLink() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!

        #expect(code.count <= AppLinks.maxDeckCodeLengthForQR)
        #expect(AppLinks.deckUniversalLink(code: code) != nil)
        #expect(AppLinks.deckDeepLink(code: code) != nil)
    }

    @Test func codeSurvivesURLQueryRoundTrip() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!
        let url = AppLinks.deckDeepLink(code: code)!

        #expect(DeepLinkRouter.parse(url) == .deck(code: code))
    }

    @Test func legacyV1CodeStillDecodes() throws {
        // Encode a v1 payload exactly as pre-3.0.x versions did.
        let legacy = DeckManager.ShareableDeck(
            name: "Legacy Deck",
            description: "",
            format: "Infinity Constructed",
            inkColors: ["Amber"],
            archetype: nil,
            cards: [
                DeckManager.ShareableCard(
                    cardId: "TFC_001_N_Ariel",
                    name: "Ariel",
                    cost: 3,
                    type: "Character",
                    rarity: "Rare",
                    setName: "The First Chapter",
                    imageUrl: "https://example.com/ariel.png",
                    inkColor: "Amber",
                    inkwell: true,
                    quantity: 4,
                    variant: "normal"
                )
            ]
        )
        let json = try JSONEncoder().encode(legacy)
        let compressed = try (json as NSData).compressed(using: .lzfse)
        let code = "IWK:" + (compressed as Data).base64EncodedString()

        let preview = DeckManager().previewShareCode(code)
        #expect(preview?.name == "Legacy Deck")
        #expect(preview?.totalCards == 4)
    }

    @Test func rejectsGarbageCodes() {
        let manager = DeckManager()
        #expect(manager.previewShareCode("") == nil)
        #expect(manager.previewShareCode("IWK:not-base64!!!") == nil)
        #expect(manager.previewShareCode("IWK2:not-base64!!!") == nil)
        #expect(manager.previewShareCode("hello world") == nil)
    }

    // MARK: - Share links (URLs carrying a code)

    @Test func extractsCodeFromUniversalLink() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!
        let link = AppLinks.deckShareLink(code: code)!.absoluteString

        #expect(DeckManager.extractShareCode(from: link) == code)
    }

    @Test func extractsCodeFromCustomSchemeLink() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!
        let link = AppLinks.deckDeepLink(code: code)!.absoluteString

        #expect(DeckManager.extractShareCode(from: code) == code)
        #expect(DeckManager.extractShareCode(from: link) == code)
    }

    @Test func extractRejectsNonCodeInput() {
        #expect(DeckManager.extractShareCode(from: "4 Elsa - Snow Queen") == nil)
        #expect(DeckManager.extractShareCode(from: "https://inkwellkeeper.app/deck") == nil)
        #expect(DeckManager.extractShareCode(from: "https://example.com/?code=evil") == nil)
        #expect(DeckManager.extractShareCode(from: "") == nil)
    }

    @Test func pastedShareLinkPreviewsLikeItsCode() {
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck())!
        let link = "  " + AppLinks.deckShareLink(code: code)!.absoluteString + "\n"

        let preview = manager.previewShareCode(link)
        #expect(preview?.name == "Test Deck")
        #expect(preview?.totalCards == 60)
    }

    @Test func shareLinkHasNoQRLengthCap() {
        // A deck big enough to overflow the QR cap must still get a share link.
        let manager = DeckManager()
        let code = manager.generateShareCode(for: makeDeck(uniqueCards: 200, copiesEach: 4))!

        if code.count > AppLinks.maxDeckCodeLengthForQR {
            #expect(AppLinks.deckUniversalLink(code: code) == nil)
        }
        #expect(AppLinks.deckShareLink(code: code) != nil)
    }
}
