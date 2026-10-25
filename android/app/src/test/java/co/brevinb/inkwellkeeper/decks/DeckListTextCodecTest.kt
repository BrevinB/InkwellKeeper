package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.TestCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeckListTextCodecTest {
    private val cards = TestCatalog.cards

    @Test
    fun parsesQuantitiesAndMergesRepeats() {
        val result = DeckListTextCodec.parse("4 Elsa - Snow Queen\n2x Elsa - Snow Queen\n3 Mickey Mouse - Brave Little Tailor", cards)
        assertEquals(listOf("Elsa - Snow Queen" to 6, "Mickey Mouse - Brave Little Tailor" to 3), result.entries.map { it.card.name to it.quantity })
        assertEquals(9, result.totalMatchedCards)
        assertTrue(result.unmatched.isEmpty())
    }

    @Test
    fun skipsHeadersAndReportsUnmatchedLines() {
        val result = DeckListTextCodec.parse("Deck: Test\n// comment\n\n4 Elsa - Snow Queen\n2 Not A Real Card At All", cards)
        assertEquals(1, result.entries.size)
        assertEquals(listOf(DeckListTextCodec.UnmatchedLine(5, "2 Not A Real Card At All")), result.unmatched)
    }

    @Test
    fun toleratesTyposDashesAndCase() {
        val result = DeckListTextCodec.parse("4 elsa – snow quen", cards)
        assertEquals("Elsa - Snow Queen", result.entries.single().card.name)
    }

    @Test
    fun detectsDeckListText() {
        assertTrue(DeckListTextCodec.looksLikeDeckList("hello\n4 Elsa - Snow Queen"))
        assertFalse(DeckListTextCodec.looksLikeDeckList("just a sentence"))
    }
}
