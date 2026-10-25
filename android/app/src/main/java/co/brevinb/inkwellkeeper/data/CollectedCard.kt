package co.brevinb.inkwellkeeper.data

import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * One owned (or wishlisted) printing and how many copies. Mutable like the iOS SwiftData
 * model; [CollectionManager] owns every instance and persists after each change.
 */
@Serializable
class CollectedCard(
    var id: String = UUID.randomUUID().toString(),
    var cardId: String = "",
    var name: String = "",
    var cost: Int = 0,
    var type: String = "",
    var rarity: String = "",
    var setName: String = "",
    var cardText: String = "",
    var imageUrl: String = "",
    var price: Double? = null,
    var dateAdded: Long = System.currentTimeMillis(),
    var quantity: Int = 1,
    var condition: String = "Near Mint",
    var isWishlisted: Boolean = false,
    var notes: String = "",
    var variant: String? = null,
    var inkColor: String? = null,
    var uniqueId: String? = null,
    var cardNumber: Int? = null,
    /** What the collector paid per copy, when recorded. */
    var purchasePrice: Double? = null,
    /** Absolute paths of the collector's own photos of this card, in app storage. */
    var photoPaths: List<String> = emptyList(),
) {
    val cardRarity: CardRarity get() = CardRarity.fromRaw(rarity) ?: CardRarity.COMMON
    val cardVariant: CardVariant get() = CardVariant.fromRawOrNormal(variant)

    val identityKey: String
        get() {
            val v = variant ?: CardVariant.NORMAL.rawValue
            return if (!uniqueId.isNullOrEmpty()) "$uniqueId|$v" else "$name|$setName|$v"
        }

    fun toLorcanaCard(): LorcanaCard = LorcanaCard(
        id = cardId,
        name = name,
        cost = cost,
        type = type,
        rarity = cardRarity,
        setName = setName,
        cardText = cardText,
        imageUrl = imageUrl,
        price = price,
        variant = cardVariant,
        cardNumber = cardNumber,
        uniqueId = uniqueId,
        inkColor = inkColor,
        dateAdded = dateAdded,
    )

    companion object {
        fun from(card: LorcanaCard, quantity: Int, wishlisted: Boolean = false) = CollectedCard(
            cardId = card.id,
            name = card.name,
            cost = card.cost,
            type = card.type,
            rarity = card.rarity.rawValue,
            setName = card.setName,
            cardText = card.cardText,
            imageUrl = card.imageUrl,
            price = card.price,
            quantity = quantity,
            isWishlisted = wishlisted,
            variant = card.variant.rawValue,
            inkColor = card.inkColor,
            uniqueId = card.uniqueId,
            cardNumber = card.cardNumber,
        )
    }
}
