package co.brevinb.inkwellkeeper.model

data class DeckHealth(
    val totalCards: Int,
    val uniqueCards: Int,
    val inkColors: List<String>,
    val issues: List<String>
) {
    val isValid: Boolean get() = issues.isEmpty()
}

fun Deck.health(cards: List<Card>): DeckHealth {
    val byId = cards.associateBy { it.id }
    val resolved = cardQuantities.mapNotNull { (id, quantity) -> byId[id]?.let { it to quantity } }
    val colors = resolved.flatMap { it.first.inkColor.orEmpty().split(",") }
        .map { it.trim() }.filter { it.isNotEmpty() }.distinct().sorted()
    val issues = mutableListOf<String>()
    if (totalCards < 60) issues += "Add ${60 - totalCards} more cards to reach 60."
    if (format != "Infinity Constructed" && colors.size > 2) issues += "This format allows only 2 ink colors."
    cardQuantities.filter { it.value > 4 }.forEach { (id, quantity) ->
        byId[id]?.let { issues += "${it.name} has $quantity copies (maximum is 4)." }
    }
    if (resolved.size < cardQuantities.count { it.value > 0 }) issues += "Some cards in this deck are missing from the catalog."
    return DeckHealth(totalCards, cardQuantities.count { it.value > 0 }, colors, issues)
}
