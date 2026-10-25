package co.brevinb.inkwellkeeper.storage

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BinderLayoutTest {
    @Test
    fun gridShapes() {
        assertEquals(2 to 2, BinderLayout.of(4, 1, false).let { it.columns to it.rows })
        assertEquals(3 to 3, BinderLayout.of(9, 1, false).let { it.columns to it.rows })
        assertEquals(4 to 3, BinderLayout.of(12, 1, false).let { it.columns to it.rows })
    }

    @Test
    fun slotsAndPositionsRoundTrip() {
        val layout = BinderLayout.of(9, 10, true)
        assertEquals(180, layout.totalSlots)
        assertEquals(2 to 4, layout.position(22))
        assertEquals(22, layout.slot(2, 4))
        assertEquals(9 until 18, layout.slotsOnPage(1))
    }

    @Test
    fun doubleSidedSpreadsStartWithInsideCover() {
        val layout = BinderLayout.of(9, 2, true) // pages 0–3
        assertEquals(3, layout.spreadCount)
        assertEquals(null to 0, layout.pages(0))
        assertEquals(1 to 2, layout.pages(1))
        assertEquals(3 to null, layout.pages(2))
        assertEquals(1, layout.spread(2))
    }

    @Test
    fun sheetsNeededAndEmptySlots() {
        val layout = BinderLayout.of(9, 1, true)
        assertEquals(1, layout.sheetsNeeded(0))
        assertEquals(2, layout.sheetsNeeded(19))
        assertEquals(2, layout.firstEmptySlot(setOf(0, 1, 3)))
        assertNull(layout.firstEmptySlot((0 until 18).toSet()))
    }

    @Test
    fun compactionKeepsOrder() {
        assertEquals(mapOf(2 to 0, 5 to 1, 9 to 2), BinderLayout.compactionMap(listOf(9, 2, 5)))
    }
}
