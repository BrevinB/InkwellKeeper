//
//  AnalyticsEventTests.swift
//  Inkwell KeeperTests
//
//  Guards the analytics taxonomy against TelemetryDeck reserved parameter keys.
//  Keys like "type" collide with top-level signal fields and are silently
//  dropped at ingestion, losing the data without any error.
//

import Testing
@testable import Inkwell_Keeper

struct AnalyticsEventTests {
    /// Top-level TelemetryDeck signal fields; payload keys with these names are dropped.
    private static let reservedKeys: Set<String> = ["type", "appID", "clientUser", "sessionID"]

    /// One representative instance of every event case, so new parameters are covered
    /// as long as new cases are added here alongside `Analytics.Event`.
    private static let allEvents: [Analytics.Event] = [
        .screenViewed(name: "Collection"),
        .collectionCardAdded(rarity: "Rare", set: "TFC", foil: true, source: "scan"),
        .collectionCardRemoved,
        .collectionQuantityChanged,
        .wishlistAdded,
        .wishlistRemoved,
        .scanStarted(mode: "multi"),
        .scanCardRecognized,
        .scanMultiConfirmed(count: 12),
        .scanFailed(reason: "noMatch"),
        .scanCorrected(from: "Elsa - Snow Queen [Promo Set 1]", to: "Elsa - Snow Queen [The First Chapter]"),
        .deckCreated(format: "Coconut (Beta)"),
        .deckDeleted,
        .deckCardAdded,
        .deckCardRemoved,
        .deckImported(format: "Casual"),
        .starterDeckImported(name: "Amber & Amethyst"),
        .aiDeckGenerated(ink: "Ruby"),
        .aiRulesQuestionAsked,
        .rulesAssistantOpened(source: "collectionDetail"),
        .rulesAnswerRated(helpful: true),
        .paywallShown(source: "scanLimit"),
        .subscriptionPurchased(product: "pro.monthly"),
        .tipPurchased(product: "tip.small"),
        .importCompleted(source: "dreamborn", count: 60),
        .exportCompleted(format: "csv"),
        .shareCardPresented(type: "cardFlex"),
        .shareCompleted(type: "cardFlex"),
        .deckSharePresented,
        .deckShareCompleted(method: "copyLink"),
        .deepLinkOpened(type: "card"),
        .onboardingStarted,
        .onboardingCompleted,
        .loreCounterGameStarted(players: 4, mode: "Coconut")
    ]

    @Test("No event uses a TelemetryDeck reserved parameter key")
    func noReservedParameterKeys() {
        for event in Self.allEvents {
            let clashes = Set(event.parameters.keys).intersection(Self.reservedKeys)
            #expect(clashes.isEmpty, "\(event.signalName) uses reserved key(s): \(clashes)")
        }
    }

    @Test("Share and deep-link events carry their segmentation parameter")
    func shareAndDeepLinkParametersSurvive() {
        #expect(Analytics.Event.shareCardPresented(type: "haul").parameters["shareType"] == "haul")
        #expect(Analytics.Event.shareCompleted(type: "haul").parameters["shareType"] == "haul")
        #expect(Analytics.Event.deckShareCompleted(method: "link").parameters["method"] == "link")
        #expect(Analytics.Event.deepLinkOpened(type: "deck").parameters["linkType"] == "deck")
    }

    @Test("Collection adds carry a source")
    func collectionAddCarriesSource() {
        let event = Analytics.Event.collectionCardAdded(rarity: "Common", set: "AotV", foil: false, source: "import")
        #expect(event.parameters["source"] == "import")
    }

    @Test("Scan accuracy events carry their segmentation parameters")
    func scanAccuracyParametersSurvive() {
        #expect(Analytics.Event.scanFailed(reason: "noText").parameters["reason"] == "noText")
        let corrected = Analytics.Event.scanCorrected(from: "A [Set1]", to: "B [Set2]")
        #expect(corrected.parameters["guessedCard"] == "A [Set1]")
        #expect(corrected.parameters["correctedCard"] == "B [Set2]")
    }
}
