package co.brevinb.inkwellkeeper.storage

import co.brevinb.inkwellkeeper.model.LorcanaCard

/** What it takes to assemble a built deck in its deck box. */
class DeckPullPlan {
    /** One trip to one place: "2× Elsa from Main Binder, p.3 pockets 5–6". */
    data class Pull(
        val card: LorcanaCard,
        /** Null means Unsorted. */
        val sourceId: String?,
        val sourceName: String,
        val sourceKind: StorageKind?,
        val quantity: Int,
        val slots: List<Int>,
        val pockets: List<StorageAllocation.BinderPocket>,
    ) {
        val id: String get() = "${sourceId ?: "unsorted"}|${card.identityKey}"
    }

    data class Shortfall(val card: LorcanaCard, val quantity: Int)

    data class SourceGroup(val sourceName: String, val sourceKind: StorageKind?, val pulls: List<Pull>)

    val pulls = mutableListOf<Pull>()
    val missing = mutableListOf<Shortfall>()
    var inBox = 0
    var total = 0

    val toPull: Int get() = pulls.sumOf { it.quantity }
    val missingCount: Int get() = missing.sumOf { it.quantity }
    val isComplete: Boolean get() = inBox >= total

    /** Pulls grouped by source, Unsorted first, so the collector can empty one place at a time. */
    val pullsBySource: List<SourceGroup>
        get() {
            val groups = LinkedHashMap<String, MutableList<Pull>>()
            for (pull in pulls) groups.getOrPut(pull.sourceId ?: "unsorted") { mutableListOf() }.add(pull)
            return groups.values.map { group ->
                val first = group.first()
                SourceGroup(
                    first.sourceName,
                    first.sourceKind,
                    group.sortedWith(compareBy({ it.slots.firstOrNull() ?: Int.MAX_VALUE }, { it.card.name })),
                )
            }
        }
}
