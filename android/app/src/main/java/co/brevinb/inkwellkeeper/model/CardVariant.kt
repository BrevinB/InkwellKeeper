package co.brevinb.inkwellkeeper.model

import kotlinx.serialization.Serializable

/** A printing of a card. Raw values match the iOS app and the bundled catalog JSON. */
@Serializable
enum class CardVariant(val rawValue: String, val shortName: String) {
    NORMAL("Normal", "N"),
    FOIL("Foil", "F"),
    BORDERLESS("Borderless", "B"),
    PROMO("Promo", "P"),
    ENCHANTED("Enchanted", "E"),
    EPIC("Epic", "EP"),
    ICONIC("Iconic", "I");

    val displayName: String get() = rawValue

    /** Enchanted, Epic, Iconic and Promo are distinct cards rather than finishes of a normal card. */
    val isSpecialPrinting: Boolean
        get() = this == ENCHANTED || this == EPIC || this == ICONIC || this == PROMO

    companion object {
        fun fromRaw(raw: String?): CardVariant? = entries.firstOrNull { it.rawValue == raw }
        fun fromRawOrNormal(raw: String?): CardVariant = fromRaw(raw) ?: NORMAL
    }
}
