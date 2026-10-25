//
//  LorcanaSetRegistryTests.swift
//  Inkwell KeeperTests
//
//  Guards the baked-in Core Constructed rotation against set-name typos: a name that doesn't
//  match the bundled card data silently makes that whole set illegal.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct LorcanaSetRegistryTests {
    @Test("Every default Core-legal set matches a bundled set name")
    func defaultCoreSetsExist() async throws {
        let manager = SetsDataManager.shared
        var attempts = 0
        while !manager.isDataLoaded && attempts < 100 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        let bundledSets = Set(manager.getAllCards().map(\.setName))
        try #require(!bundledSets.isEmpty)
        let unknown = LorcanaSetRegistry.defaultCoreLegalSets.subtracting(bundledSets)
        #expect(unknown.isEmpty, "Unknown Core set names: \(unknown.sorted())")
    }

    @Test("Every non-constructed (Illumineer's Quest) set matches a bundled set name")
    func nonConstructedSetsExist() async throws {
        let manager = SetsDataManager.shared
        var attempts = 0
        while !manager.isDataLoaded && attempts < 100 {
            try await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        let bundledSets = Set(manager.getAllCards().map(\.setName))
        try #require(!bundledSets.isEmpty)
        let unknown = LorcanaSetRegistry.nonConstructedSets.subtracting(bundledSets)
        #expect(unknown.isEmpty, "Unknown Illumineer's Quest set names: \(unknown.sorted())")
    }
}

@MainActor
struct FormatLegalityTests {
    private let legalSets: Set<String> = ["Fabled"]

    @Test("An old printing of a card reprinted in a legal set is legal")
    func reprintIsLegal() {
        let illegal = FormatLegality.illegalSets(
            of: [(name: "Elsa – Snow Queen", setName: "The First Chapter")],
            legalSets: legalSets,
            legalCardNames: ["elsa - snow queen"]
        )
        #expect(illegal.isEmpty)
    }

    @Test("A card only printed in rotated sets is illegal")
    func rotatedOnlyCardIsIllegal() {
        let illegal = FormatLegality.illegalSets(
            of: [
                (name: "Hiram Flaversham - Toymaker", setName: "Ursula's Return"),
                (name: "Elsa - Snow Queen", setName: "Fabled")
            ],
            legalSets: legalSets,
            legalCardNames: ["elsa - snow queen"]
        )
        #expect(illegal == ["Ursula's Return"])
    }

    @Test("Illumineer's Quest cards are flagged; ordinary sets are not")
    func questCardsAreNonConstructed() {
        let sets = FormatLegality.nonConstructedSets(of: [
            (name: "Anna - Ensnared Sister", setName: "Illumineer's Quest: Deep Trouble"),
            (name: "Elsa - Snow Queen", setName: "Fabled")
        ])
        #expect(sets == ["Illumineer's Quest: Deep Trouble"])
        #expect(DeckFormat.casual.allowsNonConstructedCards)
        #expect(!DeckFormat.infinityConstructed.allowsNonConstructedCards)
    }
}
