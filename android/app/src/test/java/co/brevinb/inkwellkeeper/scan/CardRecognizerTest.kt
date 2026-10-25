package co.brevinb.inkwellkeeper.scan

import co.brevinb.inkwellkeeper.TestCatalog
import co.brevinb.inkwellkeeper.model.CardVariant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CardRecognizerTest {
    private val recognizer = CardRecognizer(TestCatalog.cards, TestCatalog.sets, TestCatalog::search)

    private fun found(texts: List<String>) = (recognizer.recognize(texts) as? CardRecognizer.Resolution.Found)?.card

    @Test
    fun matchesNameAndCollectorLine() {
        val card = found(listOf("ELSA", "Spirit of Winter", "Floodborn • Hero • Queen • Sorcerer", "43/204 · EN · 9"))
        assertEquals("Elsa - Spirit of Winter", card?.name)
        assertEquals("Fabled", card?.setName)
        assertEquals(CardVariant.NORMAL, card?.variant)
    }

    @Test
    fun numberBeyondSetTotalIsSpecialPrinting() {
        val card = found(listOf("ELSA", "Spirit of Winter", "207/204 · EN · 1"))
        assertEquals("Elsa - Spirit of Winter", card?.name)
        assertTrue(card!!.variant.isSpecialPrinting)
    }

    @Test
    fun reprintWithoutCollectorLineAsksForSet() {
        val result = recognizer.recognize(listOf("ELSA", "Spirit of Winter"))
        assertTrue(result is CardRecognizer.Resolution.ChooseSet)
    }

    @Test
    fun brandTextAloneIsNotACard() {
        assertNull(recognizer.recognize(listOf("Disney", "LORCANA", "EN")))
    }

    @Test
    fun extractsMainAndSubtitleCombos() {
        val names = CardRecognizer.extractCardNames(listOf("RAFIKI", "Shaman of the Savanna", "Disney Lorcana"))
        assertEquals("RAFIKI - Shaman of the Savanna", names.first())
    }
}
