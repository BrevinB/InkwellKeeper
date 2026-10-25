package co.brevinb.inkwellkeeper.model

import kotlinx.serialization.Serializable
import java.util.Locale

/**
 * A card printing from the catalog (or a snapshot of one stored in the collection, a deck,
 * or a binder). Mirrors the iOS `LorcanaCard` so ids, identity keys, and backups line up
 * across platforms.
 */
@Serializable
data class LorcanaCard(
    val id: String,
    val name: String,
    val cost: Int,
    val type: String,
    val rarity: CardRarity,
    val setName: String,
    val cardText: String = "",
    val imageUrl: String,
    val price: Double? = null,
    val variant: CardVariant = CardVariant.NORMAL,
    val cardNumber: Int? = null,
    val uniqueId: String? = null,
    val inkwell: Boolean? = null,
    val strength: Int? = null,
    val willpower: Int? = null,
    val lore: Int? = null,
    val franchise: String? = null,
    val inkColor: String? = null,
    /** Epoch millis; only set for collection snapshots. */
    val dateAdded: Long? = null,
) {
    /**
     * Identity for list keys that stays unique when a normal card and its foil share the same
     * `id` (foils saved by older iOS versions reused the base card's id).
     */
    val variantAwareId: String get() = "$id|${variant.rawValue}"

    /**
     * Same key format as the iOS `CollectionManager.identityKey(for:)`: uniqueId when present
     * (variant-qualified), name|set|variant otherwise.
     */
    val identityKey: String
        get() = if (!uniqueId.isNullOrEmpty()) "$uniqueId|${variant.rawValue}"
        else "$name|$setName|${variant.rawValue}"

    /** Image to load. Foils share the normal art; the app draws the foil finish as an effect. */
    val bestImageUrl: String get() = imageUrl

    /** A copy of this card as a different printing, with the id the iOS app would generate. */
    fun withVariant(newVariant: CardVariant): LorcanaCard = copy(
        id = generatedId(setName, cardNumber, newVariant, name),
        variant = newVariant,
    )

    /**
     * Enchanted, Epic, Iconic, and Promo are separate cards; everything else can be owned as a
     * Normal or Foil copy.
     */
    fun availableVariants(): List<CardVariant> =
        if (variant.isSpecialPrinting) listOf(variant) else listOf(CardVariant.NORMAL, CardVariant.FOIL)

    /** Dual-ink cards are stored as e.g. "Ruby-Steel"; this splits them into their colors. */
    val inkColors: List<String>
        get() = inkColor
            ?.split(',', '-', '/')
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            .orEmpty()

    companion object {
        /**
         * The id format the iOS JSON decoder and `withVariant` generate:
         * `{first 3 letters of set, uppercased, spaces removed}_{number:03}_{variant short}_{name}`.
         */
        fun generatedId(setName: String, cardNumber: Int?, variant: CardVariant, name: String): String {
            val setCode = setName.take(3).uppercase().replace(" ", "")
            val number = String.format(Locale.US, "%03d", cardNumber ?: 0)
            val safeName = name.replace(" ", "_").replace("'", "").replace("-", "_")
            return "${setCode}_${number}_${variant.shortName}_$safeName"
        }
    }
}
