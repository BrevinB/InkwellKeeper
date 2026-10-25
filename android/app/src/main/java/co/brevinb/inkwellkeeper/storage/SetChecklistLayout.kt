package co.brevinb.inkwellkeeper.storage

import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant

/**
 * Which pocket each card of a set belongs in, for a set checklist binder.
 *
 * One per card (default): card #N goes in pocket N, whichever printing you have.
 * Master set: each card with a normal printing gets two neighbouring pockets — normal, then
 * foil — while foil-only printings (Epic, Enchanted, Iconic, promos) get one.
 */
class SetChecklistLayout(
    val printings: Map<Int, CardVariant>,
    val hasFoilPockets: Boolean,
) {
    data class Pocket(val number: Int, val isFoilPocket: Boolean)

    private val pairedPockets: List<Pocket>
    private val pairedSlots: Map<Int, Pair<Int, Int?>>

    init {
        val pockets = mutableListOf<Pocket>()
        val slots = mutableMapOf<Int, Pair<Int, Int?>>()
        if (hasFoilPockets) {
            for (number in printings.keys.sorted()) {
                val first = pockets.size
                if (printings[number] == CardVariant.NORMAL) {
                    pockets += Pocket(number, false)
                    pockets += Pocket(number, true)
                    slots[number] = Pair(first, first + 1)
                } else {
                    pockets += Pocket(number, false)
                    slots[number] = Pair(first, null)
                }
            }
        }
        pairedPockets = pockets
        pairedSlots = slots
    }

    val pocketCount: Int get() = if (hasFoilPockets) pairedPockets.size else (printings.keys.maxOrNull() ?: 0)

    fun slot(number: Int, variant: CardVariant): Int? {
        printings[number]?.let { expected ->
            val printing = if (variant == CardVariant.FOIL) CardVariant.NORMAL else variant
            if (printing != expected) return null
        }
        if (!hasFoilPockets) return number - 1
        val slots = pairedSlots[number] ?: return null
        return if (variant == CardVariant.FOIL) slots.second else slots.first
    }

    fun pocket(slot: Int): Pocket? {
        if (hasFoilPockets) return pairedPockets.getOrNull(slot)
        return if (printings[slot + 1] == null) null else Pocket(slot + 1, false)
    }

    companion object {
        fun catalogPrintings(setName: String): Map<Int, CardVariant> {
            val printings = mutableMapOf<Int, CardVariant>()
            for (card in SetsDataManager.getCardsForSet(setName)) {
                val number = card.cardNumber ?: continue
                if (number !in printings) printings[number] = card.variant
            }
            return printings
        }
    }
}
