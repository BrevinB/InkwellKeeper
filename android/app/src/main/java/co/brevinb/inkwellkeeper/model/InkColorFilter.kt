package co.brevinb.inkwellkeeper.model

import androidx.compose.ui.graphics.Color

enum class InkColorFilter(val rawValue: String, val color: Color) {
    ALL("All", Color.Gray),
    AMBER("Amber", Color(1.0f, 0.75f, 0.0f)),
    AMETHYST("Amethyst", Color(0.58f, 0.29f, 0.78f)),
    EMERALD("Emerald", Color(0.0f, 0.7f, 0.4f)),
    RUBY("Ruby", Color(0.9f, 0.1f, 0.26f)),
    SAPPHIRE("Sapphire", Color(0.12f, 0.46f, 0.82f)),
    STEEL("Steel", Color(0.5f, 0.5f, 0.5f));

    val displayName: String get() = rawValue
}
