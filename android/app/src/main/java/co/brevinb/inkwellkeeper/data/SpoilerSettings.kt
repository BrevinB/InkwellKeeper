package co.brevinb.inkwellkeeper.data

import androidx.compose.runtime.mutableStateListOf
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.ReleaseSchedule

/**
 * Spoiler shield for sets that haven't released yet. Upcoming sets are covered until the user
 * opts in (per set, remembered) or turns the shield off in Settings. Cards the user owns are
 * never shielded; only catalog browsing surfaces consult this.
 */
object SpoilerSettings {
    /** Cards revealed one at a time from search; session-only on purpose. */
    private val revealedCardIds = mutableStateListOf<String>()

    fun isHidden(setName: String): Boolean {
        if (AppSettings.showAllSpoilers || setName in AppSettings.revealedSetNames) return false
        return ReleaseSchedule.isUpcoming(SetsDataManager.getSet(setName)?.releaseDate)
    }

    fun isHidden(card: LorcanaCard): Boolean = card.id !in revealedCardIds && isHidden(card.setName)

    fun visibleCards(cards: List<LorcanaCard>): List<LorcanaCard> = cards.filter { !isHidden(it.setName) }

    fun reveal(setName: String) = AppSettings.revealSet(setName)

    fun reveal(card: LorcanaCard) {
        if (card.id !in revealedCardIds) revealedCardIds += card.id
    }
}
