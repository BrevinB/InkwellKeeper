package co.brevinb.inkwellkeeper.stats

import co.brevinb.inkwellkeeper.data.CollectedCard
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.LorcanaCard

data class TopValuableCard(val card: LorcanaCard, val unitPrice: Double, val quantity: Int) {
    val stackValue: Double get() = unitPrice * quantity
}

/** Chart-ready aggregates of the owned collection (the iOS `StatsViewModel`). */
data class CollectionStatsSnapshot(
    val totalCards: Int = 0,
    val uniqueCards: Int = 0,
    val totalValue: Double = 0.0,
    val pricedCardCount: Int = 0,
    val rarityCounts: Map<CardRarity, Int> = emptyMap(),
    val inkColorCounts: Map<String, Int> = emptyMap(),
    val costCounts: Map<Int, Int> = emptyMap(),
    val typeCounts: Map<String, Int> = emptyMap(),
    val inkableCount: Int = 0,
    val nonInkableCount: Int = 0,
    val valueBySet: Map<String, Double> = emptyMap(),
    val topValuable: List<TopValuableCard> = emptyList(),
    val recentCards: List<LorcanaCard> = emptyList(),
) {
    val unpricedCardCount: Int get() = maxOf(0, totalCards - pricedCardCount)
    val averageValuePerPricedCard: Double get() = if (pricedCardCount > 0) totalValue / pricedCardCount else 0.0
    val hasInkableData: Boolean get() = inkableCount + nonInkableCount > 0

    companion object {
        /** [livePrices] (by `variantAwareId`) are preferred over stored prices so totals match the chart. */
        fun build(records: List<CollectedCard>, livePrices: Map<String, Double> = emptyMap()): CollectionStatsSnapshot {
            val inkable = HashMap<String, Boolean>()
            for (card in SetsDataManager.getAllCards()) card.inkwell?.let { inkable["${card.name}||${card.setName}"] = it }
            var total = 0
            var value = 0.0
            var priced = 0
            val rarity = mutableMapOf<CardRarity, Int>()
            val inks = mutableMapOf<String, Int>()
            val costs = mutableMapOf<Int, Int>()
            val types = mutableMapOf<String, Int>()
            var inkableCount = 0
            var nonInkable = 0
            val bySet = mutableMapOf<String, Double>()
            val top = mutableListOf<TopValuableCard>()
            for (record in records) {
                val quantity = maxOf(1, record.quantity)
                val card = record.toLorcanaCard()
                total += quantity
                rarity.merge(record.cardRarity, quantity, Int::plus)
                record.inkColor?.takeIf { it.isNotEmpty() }?.let { inks.merge(it, quantity, Int::plus) }
                costs.merge(minOf(record.cost, 10), quantity, Int::plus)
                types.merge(primaryType(record.type), quantity, Int::plus)
                when (inkable["${record.name}||${record.setName}"]) {
                    true -> inkableCount += quantity
                    false -> nonInkable += quantity
                    null -> {}
                }
                val price = livePrices[card.variantAwareId] ?: record.price
                if (price != null && price > 0) {
                    priced += quantity
                    value += price * quantity
                    bySet.merge(record.setName, price * quantity, Double::plus)
                    top += TopValuableCard(card, price, quantity)
                }
            }
            return CollectionStatsSnapshot(
                totalCards = total,
                uniqueCards = records.size,
                totalValue = value,
                pricedCardCount = priced,
                rarityCounts = rarity,
                inkColorCounts = inks,
                costCounts = costs,
                typeCounts = types,
                inkableCount = inkableCount,
                nonInkableCount = nonInkable,
                valueBySet = bySet,
                topValuable = top.sortedByDescending { it.stackValue }.take(10),
                recentCards = records.sortedByDescending { it.dateAdded }.take(5).map { it.toLorcanaCard() },
            )
        }

        /** "Character - Storyborn" → "Character". */
        private fun primaryType(raw: String): String =
            raw.substringBefore(",").substringBefore("-").trim().lowercase().replaceFirstChar { it.uppercase() }
    }
}
