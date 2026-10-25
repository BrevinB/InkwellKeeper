package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.DeckFormat

/** Format-aware validation: size, inks, rotation, bans, copy limits, inkable ratio. */
data class DeckValidation(val isValid: Boolean, val warnings: List<String>, val errors: List<String>) {
    companion object {
        const val MINIMUM_INKABLE_RATIO = 0.6

        fun validate(deck: Deck): DeckValidation {
            val warnings = mutableListOf<String>()
            val errors = mutableListOf<String>()
            val format = deck.deckFormat
            val total = deck.totalCards

            if (total < format.minimumCards) {
                errors += "Deck has only $total cards. Minimum is ${format.minimumCards}."
            }
            if (total in 1 until 60) warnings += "Most competitive decks run exactly 60 cards."

            val inks = deck.deckInkColors
            if (inks.size > format.maxInkColors) {
                errors += "Deck has ${inks.size} ink colors. Maximum is ${format.maxInkColors}."
            }
            if (inks.isEmpty() && total > 0) warnings += "No ink colors selected. Cards may not match deck colors."

            val pairs = deck.cards.map { Pair(it.name, it.setName) }
            format.legalSets?.let { legal ->
                val illegal = FormatLegality.illegalSets(pairs, legal) - SetsDataManager.upcomingSetNames()
                if (illegal.isNotEmpty()) {
                    errors += "Contains cards from rotated/illegal sets: ${illegal.sorted().joinToString(", ")}"
                }
            }
            if (!format.allowsUnreleasedCards) {
                for (setName in FormatLegality.unreleasedSets(pairs).sorted()) {
                    val date = SetsDataManager.getSet(setName)?.releaseDateFormatted ?: "its release date"
                    errors += "Contains cards from $setName, which isn't legal until $date."
                }
            }
            if (format.bannedCards.isNotEmpty()) {
                val banned = deck.cards.map { it.name }.filter { format.isBanned(it) }.toSet()
                if (banned.isNotEmpty()) errors += "Contains banned cards: ${banned.sorted().joinToString(", ")}"
            }

            if (format == DeckFormat.COCONUT) {
                val leader = deck.coconutLeaderInfo
                if (leader != null) {
                    if (inks.isNotEmpty() && leader.ink !in inks) {
                        errors += "Deck inks must include ${leader.ink.rawValue} to match your leader (${leader.name})."
                    }
                } else {
                    errors += "Choose a Coconut leader for this deck (Edit Deck Info)."
                }
            }

            for (card in deck.cards) {
                val max = deck.maxCopies(card.name)
                if (card.quantity > max) errors += "${card.name}: ${card.quantity} copies (max $max)"
            }

            val wrongInk = deck.cards.filter { card -> card.cardInkColor?.let { it !in inks } ?: false }
            if (wrongInk.isNotEmpty() && inks.isNotEmpty()) warnings += "${wrongInk.size} cards don't match deck ink colors"

            val inkable = deck.cards.filter { it.inkwell }.sumOf { it.quantity }
            val ratio = if (total > 0) inkable.toDouble() / total else 0.0
            if (ratio < MINIMUM_INKABLE_RATIO && total >= 30) {
                warnings += "Low inkable ratio (${(ratio * 100).toInt()}%). Most decks run 70%+ inkable."
            }
            return DeckValidation(errors.isEmpty(), warnings, errors)
        }
    }
}
