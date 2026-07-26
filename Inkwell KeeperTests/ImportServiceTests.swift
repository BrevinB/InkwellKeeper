//
//  ImportServiceTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for bulk import parsing and card matching — covers the Dreamborn
//  CSV format, including unquoted commas in card names, set-number mapping,
//  and matching special printings (Epic/Enchanted/Iconic) by card number.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

@MainActor
struct ImportServiceTests {

    // MARK: - Dreamborn line parsing

    @Test func parsesBasicDreambornRow() throws {
        let parsed = try #require(
            ImportService.shared.parseDreambornLine("001,1,normal,2,Ariel - On Human Legs,Amber,Uncommon")
        )
        #expect(parsed.name == "Ariel - On Human Legs")
        #expect(parsed.set == "The First Chapter")
        #expect(parsed.variant == .normal)
        #expect(parsed.quantity == 2)
        #expect(parsed.cardNumber == 1)
    }

    @Test func parsesFoilRow() throws {
        let parsed = try #require(
            ImportService.shared.parseDreambornLine("009,207,foil,1,Stitch - Alien Dancer,Amber,Epic")
        )
        #expect(parsed.variant == .foil)
        #expect(parsed.set == "Fabled")
        #expect(parsed.cardNumber == 207)
    }

    /// Dreamborn doesn't quote names, so commas inside a name spill into extra fields
    @Test func joinsUnquotedCommasInCardName() throws {
        let parsed = try #require(
            ImportService.shared.parseDreambornLine("005,10,normal,4,Fix-It Felix, Jr. - Trusty Builder,Amber,Common")
        )
        #expect(parsed.name == "Fix-It Felix, Jr. - Trusty Builder")
        #expect(parsed.set == "Shimmering Skies")
        #expect(parsed.quantity == 4)
        #expect(parsed.cardNumber == 10)
    }

    @Test func joinsMultipleCommasInCardName() throws {
        let parsed = try #require(
            ImportService.shared.parseDreambornLine("011,57,normal,3,Witches of Morva - Orddu, Orwen, and Orgoch,Amethyst,Rare")
        )
        #expect(parsed.name == "Witches of Morva - Orddu, Orwen, and Orgoch")
        #expect(parsed.set == "Winterspell")
    }

    /// Letter-suffixed reprint numbers ("4a") can't match by number and must
    /// fall back to name matching
    @Test func letterSuffixedCardNumberParsesAsNil() throws {
        let parsed = try #require(
            ImportService.shared.parseDreambornLine("003,4a,normal,1,Dalmatian Puppy - Tail Wagger,Amber,Common")
        )
        #expect(parsed.cardNumber == nil)
        #expect(parsed.name == "Dalmatian Puppy - Tail Wagger")
    }

    // MARK: - Collectr (header-mapped CSV) parsing

    @Test func mapsCollectrHeaderRegardlessOfColumnOrder() throws {
        let map = try #require(
            ImportService.HeaderColumnMap(headerLine: "Quantity,Card Number,Product Name,Variance,Set,Category")
        )
        #expect(map.quantity == 0)
        #expect(map.cardNumber == 1)
        #expect(map.name == 2)
        #expect(map.variant == 3)
        #expect(map.set == 4)
        #expect(map.game == 5)
    }

    @Test func headerWithoutNameColumnIsRejected() {
        #expect(ImportService.HeaderColumnMap(headerLine: "Quantity,Set,Price") == nil)
    }

    @Test func parsesCollectrRowWithQuotedNameAndSlashNumber() throws {
        let map = try #require(
            ImportService.HeaderColumnMap(headerLine: "Product Name,Set,Card Number,Variance,Quantity")
        )
        let parsed = try #require(ImportService.shared.parseHeaderMappedRows(
            "\"Fix-It Felix, Jr. - Trusty Builder\",Shimmering Skies,10/204,Normal,4",
            columnMap: map
        ).first)
        #expect(parsed.name == "Fix-It Felix, Jr. - Trusty Builder")
        #expect(parsed.set == "Shimmering Skies")
        #expect(parsed.cardNumber == 10)
        #expect(parsed.variant == .normal)
        #expect(parsed.quantity == 4)
    }

    @Test func skipsNonLorcanaRowsInMultiGameExport() throws {
        let map = try #require(
            ImportService.HeaderColumnMap(headerLine: "Category,Product Name,Set,Quantity")
        )
        #expect(ImportService.shared.parseHeaderMappedRows(
            "Pokemon,Charizard ex,Obsidian Flames,1", columnMap: map
        ).isEmpty)
        #expect(!ImportService.shared.parseHeaderMappedRows(
            "Disney Lorcana,Elsa - Snow Queen,The First Chapter,1", columnMap: map
        ).isEmpty)
    }

    @Test func stripsGamePrefixFromSetAndVariantSuffixFromName() throws {
        let map = try #require(
            ImportService.HeaderColumnMap(headerLine: "Product Name,Set,Quantity")
        )
        let parsed = try #require(ImportService.shared.parseHeaderMappedRows(
            "Elsa - Snow Queen (Enchanted),Disney Lorcana: The First Chapter,1",
            columnMap: map
        ).first)
        #expect(parsed.name == "Elsa - Snow Queen")
        #expect(parsed.variant == .enchanted)
        #expect(parsed.set == "The First Chapter")
    }

    // MARK: - Set number mapping

    @Test func mapsAllMainSetNumbers() {
        #expect(ImportService.shared.mapDreambornSetNumber("001") == "The First Chapter")
        #expect(ImportService.shared.mapDreambornSetNumber("012") == "Wilds Unknown")
        #expect(ImportService.shared.mapDreambornSetNumber("013") == "Attack of the Vine!")
        #expect(ImportService.shared.mapDreambornSetNumber("13") == "Attack of the Vine!")
    }

    // MARK: - End-to-end matching against the bundled card database

    private func waitForCardData() async throws {
        let manager = SetsDataManager.shared
        for _ in 0..<100 where !manager.isDataLoaded {
            try await Task.sleep(for: .milliseconds(100))
        }
        try #require(manager.isDataLoaded, "Card database never finished loading")
    }

    /// Epic/Enchanted printings share a name with their base card; the importer
    /// must match them by set + card number, not name
    @Test func importsEpicPrintingAsEpicNotBaseCard() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            "009,207,foil,1,Stitch - Alien Dancer,Amber,Epic",
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        let card = try #require(result.successful.first?.card)
        #expect(card.variant == .epic)
        #expect(card.setName == "Fabled")
        #expect(card.cardNumber == 207)
    }

    @Test func importsEnchantedPrintingByCardNumber() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            "006,213,foil,1,You Came Back,Emerald,Enchanted",
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        let card = try #require(result.successful.first?.card)
        #expect(card.variant == .enchanted)
        #expect(card.setName == "Azurite Sea")
    }

    @Test func importsSetThirteenCards() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            "013,4,normal,1,Tyler Nguyen-Baker - 4*Town Fan,Amber,Common",
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        let card = try #require(result.successful.first?.card)
        #expect(card.setName == "Attack of the Vine!")
        #expect(card.cardNumber == 4)
    }

    /// A created foil must not reuse the base card's id, or SwiftUI grids showing
    /// both copies lose list identity and skip rendering tiles
    @Test func createdFoilGetsDistinctId() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            001,1,normal,2,Ariel - On Human Legs,Amber,Uncommon
            001,1,foil,1,Ariel - On Human Legs,Amber,Uncommon
            """,
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        #expect(result.successful.count == 2)
        let normal = try #require(result.successful.first(where: { $0.card.variant == .normal })?.card)
        let foil = try #require(result.successful.first(where: { $0.card.variant == .foil })?.card)
        #expect(normal.id != foil.id)
        #expect(normal.variantAwareId != foil.variantAwareId)
    }

    /// The community LorcanaExporter tool converts official-app backups into
    /// Dreamborn-format CSV: 3-digit set codes, letter-suffixed reprint numbers,
    /// separate normal/foil rows, unquoted names. Lock in that its output imports.
    @Test func importsLorcanaExporterConvertedBackup() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Set Number,Card Number,Variant,Count,Name,Color,Rarity
            001,1,normal,3,Ariel - On Human Legs,Amber,Uncommon
            001,1,foil,1,Ariel - On Human Legs,Amber,Uncommon
            009,213,foil,1,Stand Out,Emerald,Epic
            013,4,normal,2,Tyler Nguyen-Baker - 4*Town Fan,Amber,Common
            """,
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        #expect(result.successful.count == 4)
        #expect(result.successful.contains { $0.card.variant == .epic && $0.card.name == "Stand Out" })
        #expect(result.successful.contains { $0.card.setName == "Attack of the Vine!" })
    }

    /// LorcanaExporter's Inklore.gg export: nameless 4-column rows, unpadded set codes.
    /// A wrong-button export from that site must still import (this shipped as a
    /// silent no-op bug: every row was skipped and the UI showed "Import Complete!").
    @Test func importsNamelessFourColumnExport() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Set Number,Card Number,Variant,Count
            1,1,normal,2
            9,213,foil,1
            """,
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        #expect(result.successful.count == 2)
        #expect(result.successful.contains { $0.card.name == "Ariel - On Human Legs" && $0.quantity == 2 })
        #expect(result.successful.contains { $0.card.variant == .epic && $0.card.name == "Stand Out" })
    }

    @Test func namelessRowWithUnknownNumberFailsLoudlyNotSilently() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Set Number,Card Number,Variant,Count
            1,999,normal,1
            """,
            format: .dreamborn
        )

        #expect(result.successful.isEmpty)
        #expect(result.failed.count == 1)
    }

    /// LorcanaExporter's Lorcana.gg export: dual count columns, quoted values,
    /// zero-padded set codes and card numbers.
    @Test func importsDualCountLorcanaGgExport() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Normal,Foil,Name,Set,Number
            3,1,"Ariel - On Human Legs","001","001"
            0,1,"Stand Out","009","213"
            """,
            format: .collectr
        )

        #expect(result.failed.isEmpty)
        #expect(result.successful.count == 3)

        let arielRows = result.successful.filter { $0.card.name == "Ariel - On Human Legs" }
        #expect(arielRows.contains { $0.card.variant == .normal && $0.quantity == 3 })
        #expect(arielRows.contains { $0.card.variant == .foil && $0.quantity == 1 })
        #expect(result.successful.contains { $0.card.variant == .epic && $0.card.name == "Stand Out" })
    }

    // MARK: - Official app backup (JSON)

    @Test func detectsOfficialBackupJSON() {
        #expect(ImportService.isOfficialBackup(#"{"FileFormatVersion":1,"OwnedCardQuantitiesV2":[]}"#))
        #expect(!ImportService.isOfficialBackup("Set Number,Card Number,Variant,Count"))
        #expect(!ImportService.isOfficialBackup("2x Elsa - Snow Queen"))
    }

    /// The official app's backup share link deep-links into the app, but its id
    /// addresses raw JSON on Ravensburger's sharing endpoint.
    @Test func resolvesBackupDownloadURLFromShareLink() throws {
        let id = "1ae82762-26dc-418d-af68-f97eaf7bcf8c"
        let expected = "https://sharing.lorcana.ravensburger.com/backup/\(id).json"

        let fromShareLink = ImportService.officialBackupDownloadURL(
            from: "https://lorcana.ravensburger.com/collection?id=\(id)&source=app"
        )
        #expect(fromShareLink?.absoluteString == expected)

        let fromDirectURL = ImportService.officialBackupDownloadURL(from: expected)
        #expect(fromDirectURL?.absoluteString == expected)

        let fromBareId = ImportService.officialBackupDownloadURL(from: " \(id) ")
        #expect(fromBareId?.absoluteString == expected)

        #expect(ImportService.officialBackupDownloadURL(from: "https://example.com/?id=not-a-uuid") == nil)
        #expect(ImportService.officialBackupDownloadURL(from: "hello world") == nil)
    }

    /// Official app backups reference cards by opaque Ravensburger ids; the bundled
    /// official_card_ids.json mapping resolves them to set + number. Ids from a real
    /// backup: 4 = TFC #4 Goofy - Musketeer, 72 = TFC #72 Cruella De Vil.
    @Test func importsOfficialAppBackupJSON() async throws {
        try await waitForCardData()

        let backup = """
        {"FileFormatVersion":1,"Wishlist":[58],"OwnedCardQuantitiesV2":[
          {"Id":4,"Type":"Regular","Quantity":1},
          {"Id":72,"Type":"Foiled","Quantity":2},
          {"Id":999999,"Type":"Regular","Quantity":1}
        ],"Decks":[]}
        """

        let result = await ImportService.shared.importFromText(backup, format: .officialBackup)

        #expect(result.successful.count == 2)
        #expect(result.failed.count == 1)
        #expect(result.successful.contains {
            $0.card.name == "Goofy - Musketeer" && $0.card.setName == "The First Chapter"
        })
        #expect(result.successful.contains {
            $0.card.name == "Cruella De Vil - Miserable as Usual" && $0.card.variant == .foil && $0.quantity == 2
        })
    }

    @Test func corruptBackupFailsLoudly() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            #"{"OwnedCardQuantitiesV2": "not an array"}"#,
            format: .officialBackup
        )

        #expect(result.successful.isEmpty)
        #expect(result.failed.count == 1)
    }

    /// A file where nothing parses must come back with zero processed rows so the
    /// UI can show an error instead of a hollow "Import Complete!".
    @Test func unrecognizableFileReportsZeroProcessed() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Some Header,Another Header
            garbage,data
            """,
            format: .collectr
        )

        #expect(result.totalProcessed == 0)
    }

    @Test func importsCollectrExportEndToEnd() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            """
            Category,Product Name,Set,Card Number,Variance,Quantity
            Disney Lorcana,Stitch - Alien Dancer,Fabled,207/204,Foil,1
            Disney Lorcana,Ariel - On Human Legs,The First Chapter,1/204,Foil,2
            Pokemon,Charizard ex,Obsidian Flames,125/197,Holofoil,1
            """,
            format: .collectr
        )

        #expect(result.failed.isEmpty)
        #expect(result.successful.count == 2)

        let epic = try #require(result.successful.first(where: { $0.card.name == "Stitch - Alien Dancer" })?.card)
        #expect(epic.variant == .epic)
        #expect(epic.setName == "Fabled")

        let foil = try #require(result.successful.first(where: { $0.card.name == "Ariel - On Human Legs" })?.card)
        #expect(foil.variant == .foil)
        #expect(result.successful.first(where: { $0.card.name == "Ariel - On Human Legs" })?.quantity == 2)
    }

    @Test func importsFullDreambornRowWithCommaNameEndToEnd() async throws {
        try await waitForCardData()

        let result = await ImportService.shared.importFromText(
            "005,10,normal,4,Fix-It Felix, Jr. - Trusty Builder,Amber,Common",
            format: .dreamborn
        )

        #expect(result.failed.isEmpty)
        let card = try #require(result.successful.first?.card)
        #expect(card.setName == "Shimmering Skies")
        #expect(card.cardNumber == 10)
        #expect(result.successful.first?.quantity == 4)
    }
}
