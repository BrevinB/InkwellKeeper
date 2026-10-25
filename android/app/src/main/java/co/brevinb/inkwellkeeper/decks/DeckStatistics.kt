package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.data.CollectionManager
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant

data class DeckStatistics(
    val totalCards: Int,
    val uniqueCards: Int,
    val averageCost: Double,
    val inkableCount: Int,
    val inkableRatio: Double,
    val costDistribution: Map<Int, Int>,
    val typeDistribution: Map<String, Int>,
    val rarityDistribution: Map<CardRarity, Int>,
    val totalValue: Double,
    val ownedCards: Int,
    val missingCards: Int,
    val completionPercentage: Double,
    val costToComplete: Double,
) {
    companion object {
        /** Copies of a deck card the collector owns (ID first, then name + set). */
        fun ownedQuantity(deckCard: DeckCard, collection: CollectionManager): Int {
            val byId = collection.getCollectedQuantity(deckCard.cardId)
            if (byId > 0) return byId
            return if (deckCard.cardVariant == CardVariant.NORMAL) {
                collection.getCollectedQuantityAnyVariant(deckCard.name, deckCard.setName)
            } else {
                collection.getCollectedQuantityByName(deckCard.name, deckCard.setName, deckCard.cardVariant)
            }
        }

        fun calculate(deck: Deck, collection: CollectionManager): DeckStatistics {
            val cards = deck.cards
            val total = deck.totalCards
            val costDist = mutableMapOf<Int, Int>()
            var totalCost = 0
            val typeDist = mutableMapOf<String, Int>()
            val rarityDist = mutableMapOf<CardRarity, Int>()
            var owned = 0
            var value = 0.0
            var toComplete = 0.0
            for (card in cards) {
                costDist.merge(card.cost, card.quantity, Int::plus)
                totalCost += card.cost * card.quantity
                typeDist.merge(card.type, card.quantity, Int::plus)
                rarityDist.merge(card.cardRarity, card.quantity, Int::plus)
                val have = ownedQuantity(card, collection)
                val missing = maxOf(0, card.quantity - have)
                owned += minOf(have, card.quantity)
                card.price?.let {
                    value += it * card.quantity
                    toComplete += it * missing
                }
            }
            val inkable = cards.filter { it.inkwell }.sumOf { it.quantity }
            return DeckStatistics(
                totalCards = total,
                uniqueCards = cards.size,
                averageCost = if (total > 0) totalCost.toDouble() / total else 0.0,
                inkableCount = inkable,
                inkableRatio = if (total > 0) inkable.toDouble() / total else 0.0,
                costDistribution = costDist,
                typeDistribution = typeDist,
                rarityDistribution = rarityDist,
                totalValue = value,
                ownedCards = owned,
                missingCards = total - owned,
                completionPercentage = if (total > 0) owned.toDouble() / total * 100 else 0.0,
                costToComplete = toComplete,
            )
        }
    }
}
