package co.brevinb.inkwellkeeper.transfer

import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.storage.StoredCard
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The app's own JSON backup — byte-for-byte the same keys as the iOS `InkwellBackup`, so a
 * backup made on either platform restores on the other (cards plus binders and boxes).
 */
@Serializable
data class InkwellBackup(
    val exportDate: String,
    val appVersion: String,
    val totalCards: Int,
    val totalQuantity: Int,
    val cards: List<Card>,
    val storage: List<Container>? = null,
) {
    @Serializable
    data class Card(
        val id: String,
        val name: String,
        val setName: String,
        val cardNumber: Int? = null,
        val uniqueId: String? = null,
        val variant: String,
        val quantity: Int,
        val rarity: String,
        val inkColor: String? = null,
        val cardType: String,
        val cost: Int,
        val strength: Int? = null,
        val willpower: Int? = null,
        val lore: Int? = null,
        val inkwell: Boolean? = null,
        val franchise: String? = null,
        val price: Double? = null,
        val condition: String? = null,
        val notes: String? = null,
        val dateAdded: String? = null,
        val imageUrl: String,
    )

    @Serializable
    data class Container(
        val id: String,
        val name: String,
        val kind: String,
        val coverStyle: String,
        val colorName: String,
        val sortOrder: Int,
        val notes: String,
        val pocketsPerPage: Int,
        val sheetCount: Int,
        val isDoubleSided: Boolean,
        val capacity: Int? = null,
        val linkedSetName: String? = null,
        val hasFoilPockets: Boolean,
        val linkedDeckId: String? = null,
        val items: List<Item>,
    ) {
        fun toContainer(): StorageContainer = StorageContainer(
            id = id, name = name, kindRaw = kind, coverStyle = coverStyle, colorName = colorName, sortOrder = sortOrder,
            notes = notes, pocketsPerPage = pocketsPerPage, sheetCount = sheetCount, isDoubleSided = isDoubleSided,
            capacity = capacity, linkedSetName = linkedSetName, hasFoilPockets = hasFoilPockets, linkedDeckId = linkedDeckId,
            items = items.map { it.toStoredCard(id) }.toMutableList(),
        )

        companion object {
            fun from(container: StorageContainer) = Container(
                id = container.id.uppercase(), name = container.name, kind = container.kindRaw, coverStyle = container.coverStyle,
                colorName = container.colorName, sortOrder = container.sortOrder, notes = container.notes,
                pocketsPerPage = container.pocketsPerPage, sheetCount = container.sheetCount, isDoubleSided = container.isDoubleSided,
                capacity = container.capacity, linkedSetName = container.linkedSetName, hasFoilPockets = container.hasFoilPockets,
                linkedDeckId = container.linkedDeckId?.uppercase(), items = container.items.map { Item.from(it) },
            )
        }
    }

    @Serializable
    data class Item(
        val cardId: String,
        val name: String,
        val cost: Int,
        val type: String,
        val rarity: String,
        val setName: String,
        val imageUrl: String,
        val inkColor: String? = null,
        val variant: String,
        val cardNumber: Int? = null,
        val uniqueId: String? = null,
        val price: Double? = null,
        val quantity: Int,
        val slotIndex: Int? = null,
        val originContainerId: String? = null,
        val originSlot: Int? = null,
    ) {
        val card: LorcanaCard
            get() = LorcanaCard(
                id = cardId, name = name, cost = cost, type = type, rarity = CardRarity.fromRaw(rarity) ?: CardRarity.COMMON,
                setName = setName, imageUrl = imageUrl, price = price, variant = CardVariant.fromRawOrNormal(variant),
                cardNumber = cardNumber, uniqueId = uniqueId, inkColor = inkColor,
            )

        fun toStoredCard(containerId: String) = StoredCard.from(card, quantity, slotIndex, containerId).also {
            it.originContainerId = originContainerId
            it.originSlot = originSlot
        }

        companion object {
            fun from(row: StoredCard) = Item(
                cardId = row.cardId, name = row.name, cost = row.cost, type = row.type, rarity = row.rarity, setName = row.setName,
                imageUrl = row.imageUrl, inkColor = row.inkColor, variant = row.variant, cardNumber = row.cardNumber,
                uniqueId = row.uniqueId, price = row.price, quantity = row.quantity, slotIndex = row.slotIndex,
                originContainerId = row.originContainerId?.uppercase(), originSlot = row.originSlot,
            )
        }
    }

    companion object {
        private val json = Json { ignoreUnknownKeys = true; prettyPrint = true; explicitNulls = false }

        fun looksLikeBackup(text: String): Boolean {
            val trimmed = text.trim()
            return trimmed.startsWith("{") && "\"appVersion\"" in trimmed && "\"exportDate\"" in trimmed && "\"cards\"" in trimmed
        }

        fun decode(text: String): InkwellBackup? = runCatching { json.decodeFromString(serializer(), text) }.getOrNull()

        fun encode(backup: InkwellBackup): String = json.encodeToString(serializer(), backup)
    }
}
