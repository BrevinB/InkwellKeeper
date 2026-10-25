package co.brevinb.inkwellkeeper.model

import java.time.LocalDate

/**
 * Decides whether a set is still upcoming from its bundled `releaseDate`. The date itself is
 * the gate: cards unlock (spoiler shield lifts, legality begins) at local midnight on release day.
 */
object ReleaseSchedule {
    /** The local-calendar day a `yyyy-MM-dd` release date refers to, or null if unparseable. */
    fun releaseDay(releaseDate: String?): LocalDate? {
        val parts = releaseDate?.split("-")?.mapNotNull { it.toIntOrNull() } ?: return null
        if (parts.size != 3) return null
        return runCatching { LocalDate.of(parts[0], parts[1], parts[2]) }.getOrNull()
    }

    /** True until release day. Sets with no or malformed dates count as released. */
    fun isUpcoming(releaseDate: String?, today: LocalDate = LocalDate.now()): Boolean {
        val day = releaseDay(releaseDate) ?: return false
        return today.isBefore(day)
    }
}
