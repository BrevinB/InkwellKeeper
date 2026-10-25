package co.brevinb.inkwellkeeper.storage

import kotlin.math.ceil
import kotlin.math.sqrt

/**
 * Pure page/pocket math for binders.
 *
 * - sheet: a physical plastic page you turn.
 * - page: one face of a sheet. Double-sided sheets have two pages.
 * - pocket: one card position on a page.
 * - slot: a pocket's global index across the whole binder, counting page by page.
 * - spread: what you see with the binder open — a left and a right page.
 */
data class BinderLayout(
    val pocketsPerPage: Int,
    val sheetCount: Int,
    val isDoubleSided: Boolean,
) {
    init {
        require(pocketsPerPage >= 1 && sheetCount >= 1)
    }

    /** 4 → 2×2, 9 → 3×3, 12 → 4×3. */
    val columns: Int
        get() = when (pocketsPerPage) {
            4 -> 2
            9 -> 3
            12 -> 4
            else -> maxOf(1, ceil(sqrt(pocketsPerPage.toDouble())).toInt())
        }

    val rows: Int get() = (pocketsPerPage + columns - 1) / columns

    val pagesPerSheet: Int get() = if (isDoubleSided) 2 else 1
    val pageCount: Int get() = sheetCount * pagesPerSheet
    val totalSlots: Int get() = pageCount * pocketsPerPage

    fun sheetsNeeded(cardCount: Int): Int {
        val perSheet = pocketsPerPage * pagesPerSheet
        return maxOf(1, (cardCount + perSheet - 1) / perSheet)
    }

    fun slot(page: Int, pocket: Int): Int = page * pocketsPerPage + pocket

    /** (page, pocket), both zero-based. */
    fun position(slot: Int): Pair<Int, Int> = Pair(slot / pocketsPerPage, slot % pocketsPerPage)

    fun slotsOnPage(page: Int): IntRange {
        val start = page * pocketsPerPage
        return start until start + pocketsPerPage
    }

    fun contains(slot: Int): Boolean = slot in 0 until totalSlots

    /**
     * Double-sided: the first spread shows the inside cover on the left and page 0 on the
     * right; after that each spread pairs the back of one sheet with the front of the next.
     */
    val spreadCount: Int get() = if (isDoubleSided) spread(pageCount - 1) + 1 else pageCount

    fun pages(spread: Int): Pair<Int?, Int?> {
        if (!isDoubleSided) return Pair(null, if (spread < pageCount) spread else null)
        if (spread == 0) return Pair(null, 0)
        val left = spread * 2 - 1
        val right = spread * 2
        return Pair(if (left < pageCount) left else null, if (right < pageCount) right else null)
    }

    fun spread(page: Int): Int = if (!isDoubleSided) page else if (page == 0) 0 else (page + 1) / 2

    fun firstEmptySlot(occupied: Set<Int>, startingAt: Int = 0): Int? {
        var slot = maxOf(0, startingAt)
        while (slot < totalSlots) {
            if (slot !in occupied) return slot
            slot++
        }
        return null
    }

    companion object {
        val supportedPocketCounts = listOf(4, 9, 12)

        fun of(pocketsPerPage: Int, sheetCount: Int, isDoubleSided: Boolean) =
            BinderLayout(maxOf(1, pocketsPerPage), maxOf(1, sheetCount), isDoubleSided)

        /** Maps each occupied slot to its new slot when every gap is closed, keeping order. */
        fun compactionMap(occupied: List<Int>): Map<Int, Int> =
            occupied.sorted().withIndex().associate { (newSlot, oldSlot) -> oldSlot to newSlot }
    }
}
