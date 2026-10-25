package co.brevinb.inkwellkeeper.model

import kotlinx.serialization.Serializable

@Serializable
enum class CardRarity(val rawValue: String, val sortOrder: Int) {
    COMMON("Common", 0),
    UNCOMMON("Uncommon", 1),
    RARE("Rare", 2),
    SUPER_RARE("Super Rare", 3),
    LEGENDARY("Legendary", 4),
    EPIC("Epic", 5),
    ENCHANTED("Enchanted", 6),
    ICONIC("Iconic", 7),
    PROMO("Promo", 8);

    val displayName: String get() = rawValue

    companion object {
        fun fromRaw(raw: String?): CardRarity? = entries.firstOrNull { it.rawValue == raw }

        /** Lenient parse used for catalog data; mirrors the iOS `CardRarity.fromString`. */
        fun fromString(value: String): CardRarity = when (value.lowercase()) {
            "common" -> COMMON
            "uncommon" -> UNCOMMON
            "rare" -> RARE
            "super rare" -> SUPER_RARE
            "legendary" -> LEGENDARY
            "enchanted" -> ENCHANTED
            "epic" -> EPIC
            "special", "promo" -> PROMO
            "iconic" -> ICONIC
            else -> COMMON
        }
    }
}
