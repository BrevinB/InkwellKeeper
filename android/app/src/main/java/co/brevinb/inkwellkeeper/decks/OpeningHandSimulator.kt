package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.model.LorcanaCard

/**
 * Deals sample opening hands with Lorcana's alteration rule: set aside any number of cards,
 * draw that many, then shuffle the set-aside cards back. One use per hand.
 */
class OpeningHandSimulator private constructor(private val fullDeck: List<LorcanaCard>) {
    var hand: List<LorcanaCard> = emptyList()
        private set
    var remainingDeck: List<LorcanaCard> = emptyList()
        private set
    var hasMulliganed = false
        private set

    init {
        drawNewHand()
    }

    fun drawNewHand() {
        val deck = fullDeck.shuffled()
        hand = deck.take(HAND_SIZE)
        remainingDeck = deck.drop(HAND_SIZE)
        hasMulliganed = false
    }

    fun mulligan(indices: Set<Int>) {
        if (hasMulliganed || indices.isEmpty()) return
        val setAside = indices.filter { it in hand.indices }.map { hand[it] }
        if (setAside.isEmpty()) return
        val kept = hand.filterIndexed { index, _ -> index !in indices }
        val drawCount = minOf(setAside.size, remainingDeck.size)
        hand = kept + remainingDeck.take(drawCount)
        remainingDeck = (remainingDeck.drop(drawCount) + setAside).shuffled()
        hasMulliganed = true
    }

    val inkableCount: Int get() = hand.count { it.inkwell == true }

    companion object {
        const val HAND_SIZE = 7

        fun create(deckCards: List<DeckCard>): OpeningHandSimulator? {
            val cards = deckCards.flatMap { card -> List(card.quantity) { card.toLorcanaCard() } }
            return if (cards.size >= HAND_SIZE) OpeningHandSimulator(cards) else null
        }
    }
}
