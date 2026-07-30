//
//  RulesCardDetectionTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the Rules Assistant's fuzzy card-name detection — the "Did you mean…?"
//  attach chip that grounds questions in real card text.
//

import Testing
@testable import Inkwell_Keeper

@MainActor
struct RulesCardDetectionTests {
    private func makeCard(name: String, variant: CardVariant = .normal) -> LorcanaCard {
        LorcanaCard(
            id: "TST_\(name.replacing(" ", with: "_"))",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .rare,
            setName: "The First Chapter",
            imageUrl: "https://example.com/card.png",
            variant: variant
        )
    }

    private var catalog: [LorcanaCard] {
        [
            makeCard(name: "Elsa - Snow Queen"),
            makeCard(name: "Elsa - Spirit of Winter"),
            makeCard(name: "Mickey Mouse - Brave Little Tailor"),
            makeCard(name: "Mickey Mouse - Brave Little Tailor", variant: .foil),
            makeCard(name: "Be Prepared")
        ]
    }

    @Test func matchesFullNameWithoutDash() {
        let match = RulesAssistantService.fuzzyCardSuggestion(
            in: "how does elsa snow queen work with freeze",
            from: catalog
        )
        #expect(match?.name == "Elsa - Snow Queen")
    }

    @Test func matchesExactNameWithDash() {
        let match = RulesAssistantService.fuzzyCardSuggestion(
            in: "Does Mickey Mouse - Brave Little Tailor have evasive?",
            from: catalog
        )
        #expect(match?.name == "Mickey Mouse - Brave Little Tailor")
        #expect(match?.variant == .normal)
    }

    @Test func ignoresBareFirstNames() {
        // "Elsa" alone matches two cards ambiguously — the matcher requires the full name.
        let match = RulesAssistantService.fuzzyCardSuggestion(
            in: "can elsa quest twice",
            from: catalog
        )
        #expect(match == nil)
    }

    @Test func ignoresUnrelatedProse() {
        let match = RulesAssistantService.fuzzyCardSuggestion(
            in: "when does drying end for my characters",
            from: catalog
        )
        #expect(match == nil)
    }

    @Test func matchesCaseAndPunctuationInsensitively() {
        let match = RulesAssistantService.fuzzyCardSuggestion(
            in: "ELSA — SPIRIT OF WINTER ruling please",
            from: catalog
        )
        #expect(match?.name == "Elsa - Spirit of Winter")
    }

    @Test func emptyTextMatchesNothing() {
        #expect(RulesAssistantService.fuzzyCardSuggestion(in: "   ", from: catalog) == nil)
    }
}
