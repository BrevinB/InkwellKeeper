package co.brevinb.inkwellkeeper.storage

import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Copies of one card in a container. In a binder one row is one pocket (quantity 1,
 * [slotIndex] set); in a box one row holds every copy of that card.
 */
@Serializable
class StoredCard(
    var id: String = UUID.randomUUID().toString(),
    var cardId: String = "",
    var name: String = "",
    var cost: Int = 0,
    var type: String = "",
    var rarity: String = "",
    var setName: String = "",
    var imageUrl: String = "",
    var inkColor: String? = null,
    var variant: String = CardVariant.NORMAL.rawValue,
    var cardNumber: Int? = null,
    var uniqueId: String? = null,
    var price: Double? = null,
    var quantity: Int = 1,
    var slotIndex: Int? = null,
    var dateStored: Long = System.currentTimeMillis(),
    /** For cards pulled into a deck box: where they came from, so take-apart can return them. */
    var originContainerId: String? = null,
    var originSlot: Int? = null,
    var containerId: String = "",
) {
    val cardVariant: CardVariant get() = CardVariant.fromRawOrNormal(variant)

    val identityKey: String
        get() = if (!uniqueId.isNullOrEmpty()) "$uniqueId|$variant" else "$name|$setName|$variant"

    fun toLorcanaCard(): LorcanaCard = LorcanaCard(
        id = cardId,
        name = name,
        cost = cost,
        type = type,
        rarity = CardRarity.fromRaw(rarity) ?: CardRarity.COMMON,
        setName = setName,
        imageUrl = imageUrl,
        price = price,
        variant = cardVariant,
        cardNumber = cardNumber,
        uniqueId = uniqueId,
        inkColor = inkColor,
    )

    companion object {
        fun from(card: LorcanaCard, quantity: Int = 1, slotIndex: Int? = null, containerId: String) = StoredCard(
            cardId = card.id,
            name = card.name,
            cost = card.cost,
            type = card.type,
            rarity = card.rarity.rawValue,
            setName = card.setName,
            imageUrl = card.imageUrl,
            inkColor = card.inkColor,
            variant = card.variant.rawValue,
            cardNumber = card.cardNumber,
            uniqueId = card.uniqueId,
            price = card.price,
            quantity = quantity,
            slotIndex = slotIndex,
            containerId = containerId,
        )
    }
}
