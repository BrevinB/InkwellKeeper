package co.brevinb.inkwellkeeper.model

/** Printings of one card grouped together for search results. */
data class CardGroup(
    val id: String,
    val name: String,
    val cards: List<LorcanaCard>,
) {
    val primaryCard: LorcanaCard
        get() = cards.maxWithOrNull(compareBy<LorcanaCard>({ it.setName }, { it.uniqueId ?: "" })) ?: cards.first()

    val isReprint: Boolean get() = cards.size > 1
}
