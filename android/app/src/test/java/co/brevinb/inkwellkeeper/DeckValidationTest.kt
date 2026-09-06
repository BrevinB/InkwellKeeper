package co.brevinb.inkwellkeeper

import co.brevinb.inkwellkeeper.model.Card
import co.brevinb.inkwellkeeper.model.Deck
import co.brevinb.inkwellkeeper.model.health
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DeckValidationTest {
    private val amber = Card("amber", "Amber Card", 2, "Character", "Common", "The First Chapter", "TFC", "", "", 1, "TFC-001", "Amber", true)
    private val sapphire = amber.copy(id = "sapphire", name = "Sapphire Card", inkColor = "Sapphire")

    @Test
    fun incompleteDeckReportsCardsNeededAndColors() {
        val health = Deck("1", "Test", "Casual", mapOf("amber" to 4, "sapphire" to 2)).health(listOf(amber, sapphire))
        assertEquals(6, health.totalCards)
        assertEquals(listOf("Amber", "Sapphire"), health.inkColors)
        assertTrue(health.issues.any { it.contains("54") })
    }

    @Test
    fun overLimitDeckReportsCopyLimit() {
        val health = Deck("1", "Test", "Casual", mapOf("amber" to 5)).health(listOf(amber))
        assertTrue(health.issues.any { it.contains("maximum is 4") })
    }

    @Test
    fun infinityAllowsMoreThanTwoColors() {
        val ruby = amber.copy(id = "ruby", inkColor = "Ruby")
        val emerald = amber.copy(id = "emerald", inkColor = "Emerald")
        val health = Deck("1", "Test", "Infinity Constructed", mapOf("amber" to 1, "sapphire" to 1, "ruby" to 1, "emerald" to 1)).health(listOf(amber, sapphire, ruby, emerald))
        assertTrue(health.issues.none { it.contains("2 ink") })
    }
}
