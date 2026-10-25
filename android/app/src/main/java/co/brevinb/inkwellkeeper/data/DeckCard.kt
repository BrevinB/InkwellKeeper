package co.brevinb.inkwellkeeper.data

import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.serialization.Serializable

@Serializable
class DeckCard(
    var cardId: String = "",
    var name: String = "",
    var cost: Int = 0,
    var type: String = "",
    var rarity: String = "",
    var setName: String = "",
    var imageUrl: String = "",
    var inkColor: String? = null,
    var inkwell: Boolean = false,
    var quantity: Int = 1,
    var variant: String = CardVariant.NORMAL.rawValue,
    var price: Double? = null,
    var cardNumber: Int? = null,
    var uniqueId: String? = null,
) {
    val cardRarity: CardRarity get() = CardRarity.fromRaw(rarity) ?: CardRarity.COMMON
    val cardVariant: CardVariant get() = CardVariant.fromRawOrNormal(variant)
    val cardInkColor: InkColor? get() = inkColor?.let { InkColor.fromString(it) }

    fun toLorcanaCard(): LorcanaCard = LorcanaCard(
        id = cardId,
        name = name,
        cost = cost,
        type = type,
        rarity = cardRarity,
        setName = setName,
        imageUrl = imageUrl,
        price = price,
        variant = cardVariant,
        cardNumber = cardNumber,
        uniqueId = uniqueId,
        inkwell = inkwell,
        inkColor = inkColor,
    )

    companion object {
        fun from(card: LorcanaCard, quantity: Int) = DeckCard(
            cardId = card.id,
            name = card.name,
            cost = card.cost,
            type = card.type,
            rarity = card.rarity.rawValue,
            setName = card.setName,
            imageUrl = card.imageUrl,
            inkColor = card.inkColor,
            inkwell = card.inkwell ?: false,
            quantity = quantity,
            variant = card.variant.rawValue,
            price = card.price,
            cardNumber = card.cardNumber,
            uniqueId = card.uniqueId,
        )
    }
}
