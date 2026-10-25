package co.brevinb.inkwellkeeper.storage

import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard

/** How auto-fill arranges cards into binder pockets. */
enum class BinderSortOrder(val rawValue: String, val displayName: String) {
    SET_NUMBER("setNumber", "Set & Number"),
    INK("ink", "Ink Color"),
    RARITY("rarity", "Rarity"),
    COST("cost", "Ink Cost"),
    NAME("name", "Name");

    /** Every order falls back to set → number → variant, matching how collectors file cards. */
    fun sorted(cards: List<LorcanaCard>, setOrder: Map<String, Int>): List<LorcanaCard> {
        val catalogOrder = compareBy<LorcanaCard>(
            { setOrder[it.setName] ?: Int.MAX_VALUE },
            { it.setName },
            { it.cardNumber ?: Int.MAX_VALUE },
            { CardVariant.entries.indexOf(it.variant) },
            { it.name },
        )
        val comparator: Comparator<LorcanaCard> = when (this) {
            SET_NUMBER -> catalogOrder
            INK -> compareBy<LorcanaCard> { it.inkColor ?: "~" }.then(catalogOrder)
            RARITY -> compareByDescending<LorcanaCard> { it.rarity.sortOrder }.then(catalogOrder)
            COST -> compareBy<LorcanaCard> { it.cost }.then(catalogOrder)
            NAME -> compareBy<LorcanaCard, String>(String.CASE_INSENSITIVE_ORDER) { it.name }.then(catalogOrder)
        }
        return cards.sortedWith(comparator)
    }
}
