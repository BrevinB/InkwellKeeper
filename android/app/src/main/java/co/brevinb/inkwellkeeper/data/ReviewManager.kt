package co.brevinb.inkwellkeeper.data

/**
 * Tracks the milestones the iOS app uses to time its review prompt. The Play In-App Review
 * API isn't wired up (it needs the Play Core library), so this only records progress.
 */
object ReviewManager {
    private val milestones = listOf(10, 50, 100, 250, 500)

    var pendingPrompt: Boolean = false
        private set

    fun recordCardAdded(totalCardCount: Int) {
        val reached = milestones.lastOrNull { totalCardCount >= it } ?: return
        if (AppSettings.getInt("review.lastMilestone", 0) < reached) {
            AppSettings.putInt("review.lastMilestone", reached)
            pendingPrompt = true
        }
    }

    fun consumePrompt(): Boolean = pendingPrompt.also { pendingPrompt = false }
}
