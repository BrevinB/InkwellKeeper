package co.brevinb.inkwellkeeper

import co.brevinb.inkwellkeeper.data.ImportExport
import co.brevinb.inkwellkeeper.model.Card
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.withVariant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ImportExportTest {
    private val cards = listOf(
        Card("ariel", "Ariel - On Human Legs", 4, "Character", "Uncommon", "The First Chapter", "TFC", "", "https://example.com/a", 1, "TFC-001", "Amber", true, setNumber = "001"),
        Card("elsa", "Elsa - Snow Queen", 5, "Character", "Rare", "Into the Inklands", "ITI", "", "https://example.com/e", 42, "ITI-042", "Sapphire", false, setNumber = "003")
    )

    @Test
    fun dreambornExportRoundTripsByUniqueId() {
        val exported = ImportExport.exportDreamborn(cards, mapOf("ariel" to 4, "elsa" to 2))
        val (quantities, report) = ImportExport.import(exported, cards)

        assertEquals(mapOf("ariel" to 4, "elsa" to 2), quantities)
        assertEquals(6, report.imported)
        assertTrue(report.unmatched.isEmpty())
    }

    @Test
    fun textListImportAggregatesAndReportsUnknownCards() {
        val text = "2 Ariel - On Human Legs\n1 Missing Card\n3x Elsa - Snow Queen"
        val (quantities, report) = ImportExport.import(text, cards)

        assertEquals(2, quantities["ariel"])
        assertEquals(3, quantities["elsa"])
        assertEquals(5, report.imported)
        assertEquals(listOf("1 Missing Card"), report.unmatched)
    }

    @Test
    fun normalCatalogCardsOnlyAreUsedForTextImport() {
        val foil = cards.first().copy(id = "ariel-foil", variant = CardVariant.Foil)
        val (quantities, _) = ImportExport.import("1 Ariel - On Human Legs", cards + foil)
        assertEquals(mapOf("ariel" to 1), quantities)
    }

    @Test
    fun foilCsvCreatesSeparateSyntheticFoilCard() {
        val foil = cards.first().withVariant(CardVariant.Foil)
        val text = "Set Number,Card Number,Variant,Count,Name,Color,Rarity\n001,1,foil,2,Ariel - On Human Legs,Amber,Uncommon"
        val (quantities, report) = ImportExport.import(text, cards)

        assertEquals(mapOf(foil.id to 2), quantities)
        assertEquals(2, report.imported)
        assertTrue(report.unmatched.isEmpty())
    }

    @Test
    fun deckTextExportAndImportRoundTrips() {
        val deck = co.brevinb.inkwellkeeper.model.Deck("deck-1", "Amber Test", "Casual", mapOf("ariel" to 4, "elsa" to 2))
        val text = ImportExport.exportDeckText(deck, cards)
        val imported = ImportExport.importDeck(text, cards)

        assertEquals("Amber Test", imported.deck?.name)
        assertEquals("Casual", imported.deck?.format)
        assertEquals(mapOf("ariel" to 4, "elsa" to 2), imported.deck?.cardQuantities)
        assertTrue(imported.unmatched.isEmpty())
    }
}
