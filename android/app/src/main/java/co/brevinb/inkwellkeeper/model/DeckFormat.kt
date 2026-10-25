package co.brevinb.inkwellkeeper.model

import co.brevinb.inkwellkeeper.data.SetsDataManager

enum class DeckFormat(val rawValue: String, val shortName: String, val description: String) {
    CASUAL("Casual", "Casual", "All sets, up to 2 inks"),
    CORE_CONSTRUCTED("Core Constructed", "Core", "Rotating format (Sets 9+)"),
    INFINITY_CONSTRUCTED("Infinity Constructed", "Infinity", "All sets, all 6 inks"),
    TRIPLE_DECK("Triple Deck", "Triple", "3 decks, each a unique ink pair covering all 6 colors"),
    COCONUT(
        "Coconut (Beta)",
        "Coconut",
        "Multiplayer beta — singleton with a leader, up to 3 inks, play to 25 lore",
    );

    val minimumCards: Int get() = 60

    val maxInkColors: Int
        get() = when (this) {
            CASUAL, CORE_CONSTRUCTED, TRIPLE_DECK -> 2
            INFINITY_CONSTRUCTED -> 6
            COCONUT -> 3
        }

    /** Baseline copy limit. Coconut is singleton apart from the leader's associated cards. */
    val maxCopiesPerCard: Int get() = if (this == COCONUT) 1 else 4

    /** Sets legal for this format; null means every set is legal (no rotation). */
    val legalSets: Set<String>?
        get() = when (this) {
            CORE_CONSTRUCTED -> LorcanaSetRegistry.coreLegalSets - SetsDataManager.upcomingSetNames()
            else -> null
        }

    /** Only Casual allows cards from sets that haven't reached their release day. */
    val allowsUnreleasedCards: Boolean get() = this == CASUAL

    val bannedCards: List<String>
        get() = when (this) {
            CORE_CONSTRUCTED -> LorcanaSetRegistry.coreBannedCards
            INFINITY_CONSTRUCTED -> LorcanaSetRegistry.infinityBannedCards
            else -> emptyList()
        }

    fun isBanned(cardName: String): Boolean {
        if (bannedCards.isEmpty()) return false
        val normalized = normalizeCardName(cardName)
        return bannedCards.any { normalizeCardName(it) == normalized }
    }

    companion object {
        /** Formats offered when creating a deck (Triple Deck is legacy-only). */
        val creatable = listOf(CASUAL, CORE_CONSTRUCTED, INFINITY_CONSTRUCTED, COCONUT)

        fun fromRaw(raw: String?): DeckFormat? = entries.firstOrNull { it.rawValue == raw }

        /** Unifies dash characters, lowercases, and collapses whitespace. */
        fun normalizeCardName(name: String): String =
            name.replace("–", "-").replace("—", "-").lowercase()
                .split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
    }
}
