//
//  SpoilerSettingsTests.swift
//  Inkwell KeeperTests
//
//  Spoiler shield rules: upcoming sets are covered until release day, a set opt-in persists,
//  a single-card reveal doesn't, and the global switch turns everything off.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct SpoilerSettingsTests {
    private let releaseDates = [
        "Hyperia City": "2026-10-16",
        "Attack of the Vine!": "2026-07-17"
    ]

    private func makeDefaults() throws -> UserDefaults {
        let suite = "SpoilerSettingsTests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suite))
    }

    private func makeSettings(defaults: UserDefaults, now: String = "2026-10-01T12:00:00Z") throws -> SpoilerSettings {
        let date = try Date(now, strategy: .iso8601)
        let dates = releaseDates
        return SpoilerSettings(defaults: defaults, releaseDateForSet: { dates[$0] }, now: { date })
    }

    private func card(_ id: String, set: String) -> LorcanaCard {
        LorcanaCard(id: id, name: "Card \(id)", cost: 1, type: "Character", rarity: .common,
                    setName: set, imageUrl: "https://example.com/\(id).png")
    }

    @Test("Upcoming sets are hidden; released and unknown sets are not")
    func hidesOnlyUpcoming() throws {
        let settings = try makeSettings(defaults: makeDefaults())
        #expect(settings.isHidden(setName: "Hyperia City"))
        #expect(!settings.isHidden(setName: "Attack of the Vine!"))
        #expect(!settings.isHidden(setName: "Some Unknown Set"))
    }

    @Test("Shield lifts on release day with no other change")
    func liftsOnReleaseDay() throws {
        let settings = try makeSettings(defaults: makeDefaults(), now: "2026-10-16T18:00:00Z")
        #expect(!settings.isHidden(setName: "Hyperia City"))
    }

    @Test("Revealing a set persists across launches")
    func setRevealPersists() throws {
        let defaults = try makeDefaults()
        try makeSettings(defaults: defaults).reveal(setName: "Hyperia City")
        #expect(try !makeSettings(defaults: defaults).isHidden(setName: "Hyperia City"))
    }

    @Test("Revealing one card is session-only and doesn't reveal its set")
    func cardRevealIsSessionOnly() throws {
        let defaults = try makeDefaults()
        let settings = try makeSettings(defaults: defaults)
        let revealed = card("HYC-1", set: "Hyperia City")
        let other = card("HYC-2", set: "Hyperia City")

        settings.reveal(revealed)
        #expect(!settings.isHidden(revealed))
        #expect(settings.isHidden(other))
        #expect(try makeSettings(defaults: defaults).isHidden(revealed))
    }

    @Test("Show-all switch disables the shield and persists")
    func showAllDisablesShield() throws {
        let defaults = try makeDefaults()
        try makeSettings(defaults: defaults).showAllSpoilers = true
        let settings = try makeSettings(defaults: defaults)
        #expect(!settings.isHidden(setName: "Hyperia City"))
    }

    @Test("visibleCards drops only cards from hidden sets")
    func visibleCardsFilters() throws {
        let settings = try makeSettings(defaults: makeDefaults())
        let cards = [card("HYC-1", set: "Hyperia City"), card("AOV-1", set: "Attack of the Vine!")]
        #expect(settings.visibleCards(cards).map(\.id) == ["AOV-1"])
    }
}

struct UnreleasedLegalityTests {
    @Test("Cards from an upcoming set are flagged unless the name was already released")
    func unreleasedSets() {
        let cards: [(name: String, setName: String)] = [
            (name: "Nick Wilde - Inquisitive Harbormaster", setName: "Hyperia City"),
            (name: "Elsa - Snow Queen", setName: "Hyperia City"),
            (name: "Mickey Mouse - Brave Little Tailor", setName: "The First Chapter")
        ]
        let flagged = FormatLegality.unreleasedSets(
            of: cards,
            upcomingSets: ["Hyperia City"],
            releasedCardNames: [DeckFormat.normalizeCardName("Elsa - Snow Queen")]
        )
        #expect(flagged == ["Hyperia City"])

        let reprintOnly = FormatLegality.unreleasedSets(
            of: [cards[1]],
            upcomingSets: ["Hyperia City"],
            releasedCardNames: [DeckFormat.normalizeCardName("Elsa - Snow Queen")]
        )
        #expect(reprintOnly.isEmpty)
    }

    @Test("Only Casual allows unreleased cards")
    func onlyCasualAllowsUnreleased() {
        #expect(DeckFormat.casual.allowsUnreleasedCards)
        #expect(!DeckFormat.coreConstructed.allowsUnreleasedCards)
        #expect(!DeckFormat.infinityConstructed.allowsUnreleasedCards)
        #expect(!DeckFormat.tripleDeck.allowsUnreleasedCards)
        #expect(!DeckFormat.coconut.allowsUnreleasedCards)
    }
}
