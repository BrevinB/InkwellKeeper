package co.brevinb.inkwellkeeper.data

import co.brevinb.inkwellkeeper.model.CoconutLeader
import co.brevinb.inkwellkeeper.model.CoconutLeaders
import co.brevinb.inkwellkeeper.model.DeckArchetype
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
class Deck(
    var id: String = UUID.randomUUID().toString(),
    var name: String = "",
    var deckDescription: String = "",
    var format: String = DeckFormat.INFINITY_CONSTRUCTED.rawValue,
    var inkColors: List<String> = emptyList(),
    var archetype: String? = null,
    var createdDate: Long = System.currentTimeMillis(),
    var lastModified: Long = System.currentTimeMillis(),
    var notes: String = "",
    /** Chosen Format [Coconut] leader name; only meaningful for Coconut decks. */
    var coconutLeader: String? = null,
    var cards: MutableList<DeckCard> = mutableListOf(),
) {
    var deckFormat: DeckFormat
        get() = DeckFormat.fromRaw(format) ?: DeckFormat.INFINITY_CONSTRUCTED
        set(value) { format = value.rawValue }

    var deckInkColors: List<InkColor>
        get() = inkColors.mapNotNull { InkColor.fromString(it) }
        set(value) { inkColors = value.map { it.rawValue } }

    var deckArchetype: DeckArchetype?
        get() = DeckArchetype.fromRaw(archetype)
        set(value) { archetype = value?.rawValue }

    val totalCards: Int get() = cards.sumOf { it.quantity }

    val coconutLeaderInfo: CoconutLeader?
        get() = if (deckFormat == DeckFormat.COCONUT) CoconutLeaders.leader(coconutLeader) else null

    /**
     * Copy limit for a card in this deck: the flat per-format limit, except Coconut, where the
     * leader's associated cards may run 4 copies.
     */
    fun maxCopies(cardName: String): Int {
        if (deckFormat != DeckFormat.COCONUT) return deckFormat.maxCopiesPerCard
        val leader = coconutLeaderInfo ?: return 1
        val normalized = DeckFormat.normalizeCardName(cardName)
        return if (leader.fourOfCardNames.any { DeckFormat.normalizeCardName(it) == normalized }) 4 else 1
    }

    /** Copies of a card across every printing sharing its name. */
    fun totalQuantity(cardName: String): Int = cards.filter { it.name == cardName }.sumOf { it.quantity }
}
