package co.brevinb.inkwellkeeper.model

import java.util.Locale

enum class CardVariant { Normal, Foil, Borderless, Promo, Enchanted, Epic, Iconic }

data class Card(
    val id: String,
    val name: String,
    val cost: Int,
    val type: String,
    val rarity: String,
    val setName: String,
    val setCode: String,
    val cardText: String,
    val imageUrl: String,
    val cardNumber: Int?,
    val uniqueId: String?,
    val inkColor: String?,
    val inkwell: Boolean,
    val variant: CardVariant = CardVariant.Normal,
    val price: Double? = null,
    val setNumber: String? = null
)

data class CollectionEntry(
    val cardId: String,
    val quantity: Int = 1,
    val condition: String = "Near Mint",
    val notes: String = "",
    val wishlisted: Boolean = false
)

data class Deck(
    val id: String,
    val name: String,
    val format: String = "Infinity Constructed",
    val cardQuantities: Map<String, Int> = emptyMap()
) {
    val totalCards: Int get() = cardQuantities.values.sum()
}

/** Creates the synthetic foil printing used when a catalog only contains the normal card row. */
fun Card.withVariant(target: CardVariant): Card {
    if (target == variant) return this
    val baseId = id.removeSuffix("_Foil")
    val targetId = when (target) {
        CardVariant.Foil -> "\${baseId}_Foil"
        CardVariant.Normal -> baseId
        else -> "\${baseId}_\${target.name}"
    }
    return copy(id = targetId, variant = target)
}

fun String.normalizedCardName(): String = lowercase(Locale.US)
    .replace('–', '-')
    .replace('—', '-')
    .replace("’", "'")
    .replace(Regex("\\s+"), " ")
    .trim()

fun Card.matches(query: String): Boolean {
    val needle = query.normalizedCardName()
    return needle.isBlank() || name.normalizedCardName().contains(needle) ||
        uniqueId.orEmpty().lowercase(Locale.US).contains(needle) ||
        setName.normalizedCardName().contains(needle)
}
