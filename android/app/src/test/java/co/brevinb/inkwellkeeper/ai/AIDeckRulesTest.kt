package co.brevinb.inkwellkeeper.ai

import co.brevinb.inkwellkeeper.TestCatalog
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.DeckFormat
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AIDeckRulesTest {
    private val normals = TestCatalog.cards.filter { it.variant == CardVariant.NORMAL }

    @Test
    fun parsesDecklistBlockOnly() {
        val response = "Strategy talk 2x Not A Card\n[DECKLIST]\n4x Elsa - Snow Queen (The First Chapter)\n3x Mickey Mouse - Brave Little Tailor\nnoise\n[/DECKLIST]"
        val parsed = AIDeckRules.parseSuggestions(response)
        assertEquals(listOf("Elsa - Snow Queen" to 4, "Mickey Mouse - Brave Little Tailor" to 3), parsed.map { it.cardName to it.quantity })
    }

    @Test
    fun parsesSwapPairs() {
        val swaps = AIDeckRules.parseSwaps("Why.\n[SWAPS]\nOUT: 2x Card A\nIN: 2x Card B\nIN: 1x Orphan\nOUT: 1x Card C\nIN: 1x Card D\n[/SWAPS]")
        assertEquals(2, swaps.size)
        assertEquals(AIDeckRules.ParsedSwap("Card A", 2, "Card B", 2), swaps[0])
        assertEquals("Card D", swaps[1].inName)
    }

    @Test
    fun matchesFuzzyNames() {
        val input = listOf(
            AIDeckSuggestion(cardName = "Elsa - Snow Queen", quantity = 4),
            AIDeckSuggestion(cardName = "Elsa – Snow Quen", quantity = 2),
            AIDeckSuggestion(cardName = "Totally Invented Card - Of Nowhere Land", quantity = 1),
        )
        val out = AIDeckRules.matchSuggestions(input, normals)
        assertEquals("Elsa - Snow Queen", out[0].matchedCard?.name)
        assertEquals("Elsa - Snow Queen", out[1].matchedCard?.name)
        assertNull(out[2].matchedCard)
    }

    @Test
    fun inkHelpersHandleDualInk() {
        assertEquals(setOf("Ruby", "Steel"), AIDeckRules.inks("Ruby-Steel"))
        assertTrue(AIDeckRules.fits("Ruby-Steel", setOf("Ruby", "Steel")))
        assertTrue(!AIDeckRules.fits("Ruby-Steel", setOf("Ruby", "Amber")))
        assertEquals(setOf("Ruby", "Steel"), AIDeckRules.declaredInks("[INKS] Ruby / Steel\nrest", 2))
        assertNull(AIDeckRules.declaredInks("[INKS] Ruby / Steel / Amber", 2))
    }

    @Test
    fun auditFlagsCopyAndCountViolations() {
        val elsa = normals.first { it.name == "Elsa - Snow Queen" }
        val report = AIDeckRules.audit(listOf(AIDeckRules.Entry(elsa, 5)), DeckFormat.INFINITY_CONSTRUCTED, null, 60)
        assertTrue(report.violations.any { it.contains("5 copies") })
        assertTrue(report.violations.any { it.contains("of 60 cards") })
    }
}
