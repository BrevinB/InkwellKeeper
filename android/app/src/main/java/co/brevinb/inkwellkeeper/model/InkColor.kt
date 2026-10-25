package co.brevinb.inkwellkeeper.model

import androidx.compose.ui.graphics.Color

enum class InkColor(val rawValue: String, val color: Color) {
    AMBER("Amber", Color(1.0f, 0.7f, 0.2f)),
    AMETHYST("Amethyst", Color(0.6f, 0.3f, 0.8f)),
    EMERALD("Emerald", Color(0.2f, 0.8f, 0.4f)),
    RUBY("Ruby", Color(0.9f, 0.2f, 0.2f)),
    SAPPHIRE("Sapphire", Color(0.2f, 0.5f, 1.0f)),
    STEEL("Steel", Color(0.6f, 0.6f, 0.7f));

    companion object {
        fun fromString(value: String): InkColor? =
            entries.firstOrNull { it.rawValue == value } ?: entries.firstOrNull { it.rawValue.equals(value, ignoreCase = true) }
    }
}
