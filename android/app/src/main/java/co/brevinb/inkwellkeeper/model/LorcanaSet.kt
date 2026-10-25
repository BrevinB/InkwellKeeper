package co.brevinb.inkwellkeeper.model

import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

data class LorcanaSet(
    val id: String,
    val name: String,
    val setCode: String,
    val setNumber: String?,
    val releaseDate: String?,
    val cardCount: Int,
    val description: String,
    val isReleased: Boolean,
) {
    val releaseDateFormatted: String
        get() {
            val day = ReleaseSchedule.releaseDay(releaseDate) ?: return releaseDate ?: "Unknown"
            return day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM))
        }

    /** Whether this set hasn't reached its release day yet (see [ReleaseSchedule]). */
    fun isUpcoming(today: LocalDate = LocalDate.now()): Boolean =
        ReleaseSchedule.isUpcoming(releaseDate, today)

    /** Main sets have a number; promo and special collections don't. */
    val isMainSet: Boolean get() = setNumber?.toIntOrNull() != null
}
