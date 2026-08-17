//
//  ScanCardMatchingTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the scanner's OCR-text → card matching. Guards the regression
//  where the brand word "Lorcana" (printed on every card, and the logo on every
//  card back) matched "Jafar - High Sultan of Lorcana" — the only card whose
//  name contains that word — so every uncertain scan resolved to that promo.
//

import Testing
@testable import Inkwell_Keeper

struct ScanCardMatchingTests {
    private func makeCard(
        name: String,
        setName: String = "The First Chapter",
        variant: CardVariant = .normal,
        cardNumber: Int? = nil
    ) -> LorcanaCard {
        LorcanaCard(
            id: "TST_\(setName.replacing(" ", with: "_"))_\(name.replacing(" ", with: "_"))",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: setName,
            imageUrl: "https://example.com/card.png",
            variant: variant,
            cardNumber: cardNumber
        )
    }

    private var jafarPromo: LorcanaCard {
        makeCard(name: "Jafar - High Sultan of Lorcana", setName: "Promo Set 2")
    }
    
    private var plungerCrossbow: LorcanaCard {
        makeCard(name: "Plunger Crossbow", setName: "Wilds Unknown", cardNumber: 200)
    }

    // MARK: - extractCardNames

    @Test func brandTextIsNotACardNameCandidate() {
        let queries = CameraManager.extractCardNames(from: [
            "LORCANA", "Disney Lorcana", "DISNEY LORCANA", "Lorcana", "TM"
        ])
        #expect(queries.isEmpty)
    }

    @Test func brandTextIsDroppedAmongRealNames() {
        let queries = CameraManager.extractCardNames(from: [
            "ELSA", "Snow Queen", "Disney Lorcana", "LORCANA"
        ])
        #expect(queries.contains("ELSA - Snow Queen"))
        #expect(!queries.contains(where: { $0.localizedStandardContains("lorcana") }))
    }

    @Test func realNamesContainingBrandLikeWordsSurvive() {
        // A genuine subtitle containing "Lorcana" must still be extracted.
        let queries = CameraManager.extractCardNames(from: ["JAFAR", "High Sultan of Lorcana"])
        #expect(queries.contains("JAFAR - High Sultan of Lorcana"))
    }

    // MARK: - findBestMatch

    @Test func logoReadDoesNotResolveToJafarPromo() {
        // OCR caught only the brand logo; "Lorcana" appears in exactly one card
        // name, but nothing corroborates "Jafar" — must return nil, not the promo.
        let match = CameraManager.findBestMatch(
            for: "Lorcana",
            in: [jafarPromo],
            allDetectedTexts: ["LORCANA", "Disney Lorcana"]
        )
        #expect(match == nil)
    }
    
    @Test func scanningCardConfused() {
        let match = CameraManager.findBestMatch(
            for: "PLUNGER CROSSBOW",
            in: [plungerCrossbow],
            allDetectedTexts: ["PLUNGER CROSSBOW"]
        )
        #expect(match?.name == "Plunger Crossbow")
    }

    @Test func scanningTheActualJafarPromoStillMatches() {
        let match = CameraManager.findBestMatch(
            for: "JAFAR - High Sultan of Lorcana",
            in: [jafarPromo],
            allDetectedTexts: ["JAFAR", "High Sultan of Lorcana"]
        )
        #expect(match?.name == "Jafar - High Sultan of Lorcana")
    }

    @Test func containsMatchNeedsMainNameCorroboration() {
        // A subtitle fragment alone must not commit to a card whose main name
        // never appeared in the OCR text.
        let cards = [makeCard(name: "Elsa - Snow Queen"), makeCard(name: "Elsa - Spirit of Winter")]
        let match = CameraManager.findBestMatch(
            for: "Queen",
            in: cards,
            allDetectedTexts: ["Queen"]
        )
        #expect(match == nil)

        let corroborated = CameraManager.findBestMatch(
            for: "Queen",
            in: cards,
            allDetectedTexts: ["ELSA", "Queen"]
        )
        #expect(corroborated?.name == "Elsa - Snow Queen")
    }

    @Test func exactNameTiePrefersNormalPrintingOverPromo() {
        // Promo printings share the regular card's exact name. Regardless of
        // search-result ordering, the normal printing must win the exact-match tier.
        let promo = makeCard(name: "Elsa - Snow Queen", setName: "Promo Set 1", variant: .promo)
        let regular = makeCard(name: "Elsa - Snow Queen")
        let match = CameraManager.findBestMatch(
            for: "Elsa - Snow Queen",
            in: [promo, regular],
            allDetectedTexts: ["ELSA", "Snow Queen"]
        )
        #expect(match?.variant == .normal)
    }

    // MARK: - promoPrinting

    private var promoCodes: [String: String] {
        ["P1": "Promo Set 1", "P2": "Promo Set 2", "D23": "D23 Collection"]
    }

    @Test func collectorLineWithPromoCodeResolvesToPromo() {
        let regular = makeCard(name: "Kristoff - Reindeer Keeper", cardNumber: 97)
        let promo = makeCard(
            name: "Kristoff - Reindeer Keeper", setName: "Promo Set 2",
            variant: .promo, cardNumber: 2
        )
        let resolved = CameraManager.promoPrinting(
            for: regular,
            detectedTexts: ["KRISTOFF", "Reindeer Keeper", "2/P2 · EN"],
            allCards: [regular, promo],
            promoSetNamesByCode: promoCodes
        )
        #expect(resolved?.variant == .promo)
        #expect(resolved?.setName == "Promo Set 2")
    }

    @Test func regularCollectorLineDoesNotResolveToPromo() {
        let regular = makeCard(name: "Kristoff - Reindeer Keeper", cardNumber: 97)
        let promo = makeCard(
            name: "Kristoff - Reindeer Keeper", setName: "Promo Set 2",
            variant: .promo, cardNumber: 2
        )
        let resolved = CameraManager.promoPrinting(
            for: regular,
            detectedTexts: ["KRISTOFF", "Reindeer Keeper", "97/204 · EN · 2"],
            allCards: [regular, promo],
            promoSetNamesByCode: promoCodes
        )
        #expect(resolved == nil)
    }

    @Test func unknownSetCodeDoesNotResolveToPromo() {
        let regular = makeCard(name: "Kristoff - Reindeer Keeper", cardNumber: 97)
        let resolved = CameraManager.promoPrinting(
            for: regular,
            detectedTexts: ["2/Q9 · EN"],
            allCards: [regular],
            promoSetNamesByCode: promoCodes
        )
        #expect(resolved == nil)
    }

    @Test func exactNameMatchStillWins() {
        let cards = [makeCard(name: "Elsa - Snow Queen"), jafarPromo]
        let match = CameraManager.findBestMatch(
            for: "Elsa - Snow Queen",
            in: cards,
            allDetectedTexts: ["ELSA", "Snow Queen"]
        )
        #expect(match?.name == "Elsa - Snow Queen")
    }

    // MARK: - Catalog ordering

    /// The scanner's tie-breaks use `.first(where:)` over the full catalog, so the
    /// catalog must be in deterministic set order (main sets by number, then promos) —
    /// dictionary-order iteration reshuffled it every launch, which is what made
    /// wrong-printing bugs feel "random".
    @Test func catalogFollowsDeterministicSetOrder() async throws {
        let manager = SetsDataManager.shared
        var attempts = 0
        while !manager.isDataLoaded && attempts < 100 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        try #require(manager.isDataLoaded, "card data never finished loading")

        let setOrder = Dictionary(
            uniqueKeysWithValues: manager.sets.enumerated().map { ($0.element.name, $0.offset) }
        )
        let catalogOrders = manager.getAllCards().map { setOrder[$0.setName] ?? Int.max }
        #expect(catalogOrders == catalogOrders.sorted())

        // Promo sets sort after all numbered sets, so a promo printing can never
        // precede its main-set counterpart in the catalog.
        let firstPromoIndex = manager.sets.firstIndex { Int($0.setNumber ?? "") == nil }
        if let firstPromoIndex {
            let numberedSets = manager.sets.prefix(firstPromoIndex)
            #expect(numberedSets.allSatisfy { Int($0.setNumber ?? "") != nil })
        }
    }
}
