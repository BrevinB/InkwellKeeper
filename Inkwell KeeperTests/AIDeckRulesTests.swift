//
//  AIDeckRulesTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for the deterministic rule checks applied to AI deck output.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct AIDeckRulesTests {
    private func card(
        _ name: String,
        ink: String = "Ruby",
        set: String = "The First Chapter",
        inkable: Bool = true
    ) -> LorcanaCard {
        LorcanaCard(
            id: "\(name)-\(set)",
            name: name,
            cost: 3,
            type: "Character",
            rarity: .common,
            setName: set,
            imageUrl: "https://example.com/card.png",
            inkwell: inkable,
            inkColor: ink
        )
    }

    /// Fifteen playsets of distinct cards — a legal 60-card list.
    private func legalEntries(ink: String = "Ruby", set: String = "The First Chapter", inkable: Bool = true) -> [AIDeckRules.Entry] {
        (0..<15).map { index in
            AIDeckRules.Entry(card: card("Card \(index)", ink: ink, set: set, inkable: inkable), quantity: 4)
        }
    }

    // MARK: - Ink colors

    @Test("Dual-ink cards belong to both inks")
    func dualInkParsing() {
        #expect(AIDeckRules.inks(of: "Ruby-Steel") == ["Ruby", "Steel"])
        #expect(AIDeckRules.inks(of: "Amber") == ["Amber"])
        #expect(AIDeckRules.inks(of: nil).isEmpty)
    }

    @Test("Dual-ink cards only fit decks that play both inks")
    func dualInkFits() {
        #expect(AIDeckRules.fits(inkColor: "Ruby-Steel", allowedColors: ["Ruby", "Steel"]))
        #expect(!AIDeckRules.fits(inkColor: "Ruby-Steel", allowedColors: ["Ruby", "Amber"]))
        #expect(AIDeckRules.fits(inkColor: "Ruby", allowedColors: ["Ruby", "Amber"]))
        #expect(!AIDeckRules.fits(inkColor: nil, allowedColors: ["Ruby"]))
    }

    @Test("The AI's declared inks are read from its [INKS] line")
    func declaredInksParsing() {
        let response = "Strategy text mentioning Amethyst.\n[INKS] Ruby / Steel\n\n[DECKLIST]\n4x Card\n[/DECKLIST]"
        #expect(AIDeckRules.declaredInks(in: response, limit: 2) == ["Ruby", "Steel"])
        #expect(AIDeckRules.declaredInks(in: "[INKS] **amber & emerald**", limit: 2) == ["Amber", "Emerald"])
    }

    @Test("Missing, empty, or over-limit ink declarations are ignored")
    func declaredInksRejectsInvalid() {
        #expect(AIDeckRules.declaredInks(in: "No tag here, just Ruby and Steel", limit: 2) == nil)
        #expect(AIDeckRules.declaredInks(in: "[INKS] none\nRuby", limit: 2) == nil)
        #expect(AIDeckRules.declaredInks(in: "[INKS] Ruby / Steel / Amber", limit: 2) == nil)
        #expect(AIDeckRules.declaredInks(in: "[INKS] Ruby / Steel / Amber", limit: 6) == ["Ruby", "Steel", "Amber"])
    }

    // MARK: - Duplicate merging

    @Test("Suggestions resolving to the same card merge so the copy limit sees the total")
    func mergesDuplicates() {
        let elsa = card("Elsa - Snow Queen")
        let reprint = card("Elsa – Snow Queen", set: "Fabled")
        let merged = AIDeckRules.mergeDuplicates([
            AIDeckSuggestion(cardName: "Elsa - Snow Queen", quantity: 3, matchedCard: elsa),
            AIDeckSuggestion(cardName: "Unknown", quantity: 2),
            AIDeckSuggestion(cardName: "Elsa Snow Queen", quantity: 2, matchedCard: reprint)
        ])
        #expect(merged.count == 2)
        #expect(merged[0].quantity == 5)
        #expect(merged[1].matchedCard == nil)
    }

    // MARK: - Audit

    @Test("A 60-card playset list in one ink is legal")
    func legalDeckPasses() {
        let report = AIDeckRules.audit(legalEntries(), format: .casual, allowedColors: ["Ruby"], targetTotal: 60)
        #expect(report.isLegal)
        #expect(report.warnings.isEmpty)
        #expect(report.totalCards == 60)
    }

    @Test("Short decks are flagged")
    func shortDeck() {
        let report = AIDeckRules.audit(Array(legalEntries().dropLast()), format: .casual, allowedColors: nil, targetTotal: 60)
        #expect(!report.isLegal)
    }

    @Test("Copies of reprints count together toward the 4-copy limit")
    func copyLimitAcrossPrintings() {
        var entries = legalEntries()
        entries.append(AIDeckRules.Entry(card: card("Card 0", set: "Fabled"), quantity: 1))
        let report = AIDeckRules.audit(entries, format: .casual, allowedColors: nil, targetTotal: 60)
        #expect(report.violations.contains { $0.contains("Card 0: 5 copies") })
    }

    @Test("More inks than the format allows is a violation")
    func tooManyInks() {
        var entries = Array(legalEntries().prefix(13))
        entries.append(AIDeckRules.Entry(card: card("Steel Card", ink: "Steel"), quantity: 4))
        entries.append(AIDeckRules.Entry(card: card("Amber Card", ink: "Amber"), quantity: 4))
        let report = AIDeckRules.audit(entries, format: .coreConstructed, allowedColors: nil, targetTotal: 60)
        #expect(report.violations.contains { $0.contains("Uses 3 inks") })
    }

    @Test("A dual-ink card outside the chosen inks is flagged")
    func offColorDualInk() {
        var entries = Array(legalEntries().prefix(14))
        entries.append(AIDeckRules.Entry(card: card("Hybrid", ink: "Ruby-Steel"), quantity: 4))
        let report = AIDeckRules.audit(entries, format: .infinityConstructed, allowedColors: ["Ruby", "Amber"], targetTotal: 60)
        #expect(report.violations.contains { $0.contains("Outside your inks: Hybrid") })
    }

    @Test("Rotated sets are illegal in Core Constructed")
    func rotatedSetsFlagged() {
        let rotated = "Definitely Not A Real Set"
        let report = AIDeckRules.audit(legalEntries(set: rotated), format: .coreConstructed, allowedColors: nil, targetTotal: 60)
        #expect(report.violations.contains { $0.contains(rotated) })
    }

    @Test("Low inkable count warns without making the deck illegal")
    func lowInkableWarns() {
        let report = AIDeckRules.audit(legalEntries(inkable: false), format: .casual, allowedColors: nil, targetTotal: 60)
        #expect(report.isLegal)
        #expect(report.inkableCards == 0)
        #expect(report.warnings.contains { $0.contains("inkable") })
    }

    // MARK: - Retry feedback

    @Test("A retry prompt carries the reason and the rejected list")
    func retryNoteIncludesFeedback() {
        let note = AIDeckService.retryNote(for: .badCurve, previousAttempt: ["4x Elsa - Snow Queen"])
        #expect(note.contains(AIDeckFeedbackReason.badCurve.retryGuidance))
        #expect(note.contains("4x Elsa - Snow Queen"))
        #expect(AIDeckService.retryNote(for: nil, previousAttempt: ["4x Elsa - Snow Queen"]).isEmpty)
    }
}
