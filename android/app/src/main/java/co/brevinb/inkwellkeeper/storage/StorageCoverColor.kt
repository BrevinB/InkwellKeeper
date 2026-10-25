package co.brevinb.inkwellkeeper.storage

import androidx.compose.ui.graphics.Color
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Cover colors for binders and boxes: the six inks plus two neutrals. */
enum class StorageCoverColor(val rawValue: String, val highlight: Color, val shadow: Color) {
    AMBER("amber", Color(0.96f, 0.70f, 0.25f), Color(0.62f, 0.38f, 0.08f)),
    AMETHYST("amethyst", Color(0.62f, 0.40f, 0.85f), Color(0.30f, 0.14f, 0.48f)),
    EMERALD("emerald", Color(0.25f, 0.72f, 0.45f), Color(0.07f, 0.38f, 0.22f)),
    RUBY("ruby", Color(0.88f, 0.28f, 0.32f), Color(0.50f, 0.08f, 0.14f)),
    SAPPHIRE("sapphire", Color(0.28f, 0.55f, 0.92f), Color(0.08f, 0.24f, 0.55f)),
    STEEL("steel", Color(0.66f, 0.70f, 0.76f), Color(0.30f, 0.34f, 0.40f)),
    MIDNIGHT("midnight", Color(0.22f, 0.24f, 0.40f), Color(0.06f, 0.07f, 0.16f)),
    IVORY("ivory", Color(0.95f, 0.91f, 0.82f), Color(0.70f, 0.64f, 0.52f));

    val displayName: String get() = rawValue.replaceFirstChar { it.uppercase() }

    /** Text and trim drawn on top of the cover. */
    val trim: Color get() = if (this == IVORY || this == STEEL) LorcanaDark else LorcanaGold

    companion object {
        fun fromRaw(raw: String?): StorageCoverColor = entries.firstOrNull { it.rawValue == raw } ?: AMETHYST
    }
}
