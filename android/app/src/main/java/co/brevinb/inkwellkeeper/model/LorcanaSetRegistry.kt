package co.brevinb.inkwellkeeper.model

/**
 * Rotating-format rules: which sets are Core-legal and which cards are banned. iOS can
 * override these from CloudKit; Android ships the same baked-in defaults.
 */
object LorcanaSetRegistry {
    /** Update at each rotation (sets 5–8 rotated out July 2026, leaving sets 9+). */
    val coreLegalSets: Set<String> = setOf(
        "Fabled", "Whispers in the Well", "Winterspell", "Wilds Unknown", "Attack of the Vine!",
        "Hyperia City",
    )

    /** Banned 2025-04-08. */
    val coreBannedCards: List<String> = listOf("Hiram Flaversham - Toymaker", "Fortisphere")

    /** As of 2026-03-26. */
    val infinityBannedCards: List<String> = listOf("Hiram Flaversham - Toymaker")
}
