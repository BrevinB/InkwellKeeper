package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.DeckFormat

/**
 * Set legality for rotating formats. Core legality is per card NAME: any printing is legal
 * when that card was printed in at least one legal set (Comprehensive Rules 2.2.0).
 */
object FormatLegality {
    private var cachedNames: Pair<Set<String>, Set<String>>? = null

    fun illegalSets(cards: List<Pair<String, String>>, legalSets: Set<String>, legalCardNames: Set<String>): Set<String> =
        cards.mapNotNull { (name, setName) ->
            when {
                setName in legalSets -> null
                DeckFormat.normalizeCardName(name) in legalCardNames -> null
                else -> setName
            }
        }.toSet()

    fun illegalSets(cards: List<Pair<String, String>>, legalSets: Set<String>): Set<String> =
        illegalSets(cards, legalSets, legalCardNames(legalSets))

    fun legalCardNames(legalSets: Set<String>): Set<String> {
        cachedNames?.let { (sets, names) -> if (sets == legalSets) return names }
        val names = legalSets.flatMap { SetsDataManager.getCardsForSet(it) }.map { DeckFormat.normalizeCardName(it.name) }.toSet()
        if (names.isNotEmpty()) cachedNames = Pair(legalSets, names)
        return names
    }

    fun unreleasedSets(cards: List<Pair<String, String>>, upcomingSets: Set<String>, releasedCardNames: Set<String>): Set<String> =
        cards.mapNotNull { (name, setName) ->
            if (setName !in upcomingSets) null
            else if (DeckFormat.normalizeCardName(name) in releasedCardNames) null
            else setName
        }.toSet()

    fun unreleasedSets(cards: List<Pair<String, String>>): Set<String> {
        val upcoming = SetsDataManager.upcomingSetNames()
        if (upcoming.isEmpty() || cards.none { it.second in upcoming }) return emptySet()
        val released = SetsDataManager.sets.map { it.name }.toSet() - upcoming
        return unreleasedSets(cards, upcoming, legalCardNames(released))
    }
}
