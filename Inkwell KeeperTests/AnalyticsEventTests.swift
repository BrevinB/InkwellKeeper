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
        .shareDeckLinkCreated,
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
        #expect(Analytics.Event.deepLinkOpened(type: "deck").parameters["linkType"] == "deck")
    }

    @Test("Collection adds carry a source")
    func collectionAddCarriesSource() {
        let event = Analytics.Event.collectionCardAdded(rarity: "Common", set: "AotV", foil: false, source: "import")
        #expect(event.parameters["source"] == "import")
    }
}
