package co.brevinb.inkwellkeeper.decks

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.CollectionManager
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.data.JsonFileStore
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.DeckArchetype
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.net.URI
import java.net.URLDecoder
import java.util.Base64

/** Deck creation, editing, sharing, and import — a port of the iOS `DeckManager`. */
class DeckManager(
    private val store: JsonFileStore<List<Deck>>,
    private val scope: CoroutineScope,
) {
    private var all = mutableListOf<Deck>()

    var revision by mutableIntStateOf(0)
        private set

    /** Decks, most recently modified first. */
    var decks: List<Deck> by mutableStateOf(emptyList())
        private set

    suspend fun load() {
        all = store.load()?.toMutableList() ?: mutableListOf()
        mergeDuplicateDeckCards()
        refresh()
    }

    private fun refresh() {
        decks = all.sortedByDescending { it.lastModified }
        revision++
    }

    private fun persist() = store.scheduleSave { all.toList() }

    fun flush() = store.saveNow(all.toList())

    fun deck(id: String): Deck? {
        revision
        return all.firstOrNull { it.id == id }
    }

    /** Saves edits made directly to a deck's fields (rename, edit info). */
    fun updateDeck(deck: Deck) {
        deck.lastModified = System.currentTimeMillis()
        persist()
        refresh()
    }

    private fun mergeDuplicateDeckCards() {
        var changed = false
        for (deck in all) {
            val groups = deck.cards.groupBy { card ->
                val identity = if (!card.uniqueId.isNullOrEmpty()) card.uniqueId!! else "${card.name}||${card.setName}"
                "$identity|${card.variant}"
            }
            for ((_, rows) in groups) {
                if (rows.size < 2) continue
                val sorted = rows.sortedBy { it.cardId }
                val survivor = sorted.first()
                for (dup in sorted.drop(1)) {
                    survivor.quantity = minOf(maxOf(survivor.quantity, dup.quantity), deck.maxCopies(survivor.name))
                    if (survivor.price == null) survivor.price = dup.price
                    deck.cards.remove(dup)
                    changed = true
                }
            }
        }
        if (changed) persist()
    }

    fun createDeck(
        name: String,
        description: String = "",
        format: DeckFormat = DeckFormat.INFINITY_CONSTRUCTED,
        inkColors: List<InkColor> = emptyList(),
        archetype: DeckArchetype? = null,
        coconutLeader: String? = null,
    ): Deck {
        val deck = Deck(
            name = name,
            deckDescription = description,
            format = format.rawValue,
            inkColors = inkColors.map { it.rawValue },
            archetype = archetype?.rawValue,
            coconutLeader = coconutLeader,
        )
        all += deck
        persist()
        refresh()
        Analytics.send("deck.created", mapOf("format" to format.rawValue))
        return deck
    }

    fun deleteDeck(deck: Deck) {
        all.removeAll { it.id == deck.id }
        persist()
        refresh()
    }

    fun deleteAll() {
        all.clear()
        persist()
        refresh()
    }

    /**
     * Adds copies, capped so every printing sharing the card's name stays within the copy limit.
     */
    fun addCard(card: LorcanaCard, deck: Deck, quantity: Int = 1) {
        val cap = deck.maxCopies(card.name)
        val existing = deck.cards.firstOrNull { it.cardId == card.id }
        val otherVariants = deck.cards.filter { it.name == card.name && it.cardId != card.id }.sumOf { it.quantity }
        val room = maxOf(0, cap - otherVariants)
        val target: DeckCard = when {
            existing != null -> existing.also { it.quantity = minOf(it.quantity + quantity, room) }
            room > 0 -> DeckCard.from(card, minOf(quantity, room)).also { deck.cards += it }
            else -> return
        }
        deck.lastModified = System.currentTimeMillis()
        persist()
        refresh()
        scope.launch {
            val price = PricingService.getMarketPrice(target.toLorcanaCard()) ?: return@launch
            target.price = price
            persist()
            refresh()
        }
    }

    fun removeCard(deckCard: DeckCard, deck: Deck) {
        if (deck.cards.remove(deckCard)) {
            deck.lastModified = System.currentTimeMillis()
            persist()
            refresh()
        }
    }

    fun updateCardQuantity(deckCard: DeckCard, deck: Deck, quantity: Int) {
        if (quantity <= 0) {
            removeCard(deckCard, deck)
            return
        }
        val cap = deck.maxCopies(deckCard.name)
        val others = deck.cards.filter { it.name == deckCard.name && it.cardId != deckCard.cardId }.sumOf { it.quantity }
        deckCard.quantity = minOf(quantity, maxOf(0, cap - others))
        deck.lastModified = System.currentTimeMillis()
        persist()
        refresh()
    }

    fun duplicateDeck(deck: Deck): Deck {
        val copy = createDeck(
            name = "${deck.name} (Copy)",
            description = deck.deckDescription,
            format = deck.deckFormat,
            inkColors = deck.deckInkColors,
            archetype = deck.deckArchetype,
            coconutLeader = deck.coconutLeader,
        )
        for (card in deck.cards) addCard(card.toLorcanaCard(), copy, card.quantity)
        return copy
    }

    fun validateDeck(deck: Deck): DeckValidation = DeckValidation.validate(deck)

    fun statistics(deck: Deck, collection: CollectionManager): DeckStatistics = DeckStatistics.calculate(deck, collection)

    /** Detailed export with a header, grouped by cost. */
    fun exportDeckList(deck: Deck): String = buildString {
        append("Deck: ${deck.name}\n")
        append("Format: ${deck.deckFormat.rawValue}\n")
        if (deck.deckInkColors.isNotEmpty()) append("Colors: ${deck.deckInkColors.joinToString(", ") { it.rawValue }}\n")
        deck.deckArchetype?.let { append("Archetype: ${it.rawValue}\n") }
        append("Cards: ${deck.totalCards}\n\n")
        for ((_, cards) in deck.cards.groupBy { it.cost }.toSortedMap()) {
            for (card in cards.sortedBy { it.name }) append("${card.quantity}x ${card.name} (${card.setName})\n")
        }
        append("\nExported from Ink Well Keeper\n")
    }

    fun exportCommunityDeckList(deck: Deck): String = DeckListTextCodec.export(deck)

    data class MissingCard(val card: DeckCard, val needed: Int)

    fun getMissingCards(deck: Deck, collection: CollectionManager): List<MissingCard> =
        deck.cards.mapNotNull { card ->
            val missing = maxOf(0, card.quantity - DeckStatistics.ownedQuantity(card, collection))
            if (missing > 0) MissingCard(card, missing) else null
        }.sortedBy { it.card.name }

    data class TextImportResult(val deck: Deck, val unmatched: List<DeckListTextCodec.UnmatchedLine>)

    fun importDeck(fromText: String, name: String): TextImportResult? {
        val result = DeckListTextCodec.parse(fromText, SetsDataManager.getAllCards())
        if (result.entries.isEmpty()) return null
        val deck = Deck(
            name = name,
            format = (if (result.coconutLeader != null) DeckFormat.COCONUT else DeckFormat.INFINITY_CONSTRUCTED).rawValue,
            coconutLeader = result.coconutLeader,
        )
        result.entries.forEach { deck.cards += DeckCard.from(it.card, it.quantity) }
        all += deck
        updateDeckColorsFromCards(deck)
        persist()
        refresh()
        Analytics.send("deck.imported", mapOf("format" to deck.format))
        return TextImportResult(deck, result.unmatched)
    }

    /** Detects inks from the cards when the deck has one or two. */
    fun updateDeckColorsFromCards(deck: Deck) {
        val detected = deck.cards.mapNotNull { it.cardInkColor }.toSet()
        if (detected.isNotEmpty() && detected.size <= 2) {
            deck.deckInkColors = detected.sortedBy { it.rawValue }
            deck.lastModified = System.currentTimeMillis()
            persist()
            refresh()
        }
    }

    // MARK: - Share codes

    @Serializable
    private data class CompactShareableDeck(
        @SerialName("n") val name: String,
        @SerialName("d") val description: String = "",
        @SerialName("f") val format: String,
        @SerialName("i") val inkColors: List<String> = emptyList(),
        @SerialName("a") val archetype: String? = null,
        @SerialName("l") val coconutLeader: String? = null,
        @SerialName("c") val cards: List<CompactShareableCard>,
    )

    @Serializable
    private data class CompactShareableCard(
        val id: String,
        @SerialName("v") val variant: String? = null,
        @SerialName("q") val quantity: Int,
    )

    /** Legacy `IWK:` payload with full card snapshots; still imported. */
    @Serializable
    private data class ShareableDeck(
        val name: String,
        val description: String = "",
        val format: String,
        val inkColors: List<String> = emptyList(),
        val archetype: String? = null,
        val cards: List<ShareableCard>,
    )

    @Serializable
    private data class ShareableCard(
        val cardId: String,
        val name: String,
        val cost: Int,
        val type: String,
        val rarity: String,
        val setName: String,
        val imageUrl: String,
        val inkColor: String? = null,
        val inkwell: Boolean = false,
        val quantity: Int,
        val variant: String,
    )

    private class DecodedSharedDeck(
        val name: String,
        val description: String,
        val format: String,
        val inkColors: List<String>,
        val archetype: String?,
        val coconutLeader: String?,
        val cards: List<Pair<LorcanaCard, Int>>,
        val totalCards: Int,
    )

    private val shareJson = Json { ignoreUnknownKeys = true; explicitNulls = false; encodeDefaults = false }

    /** Compact `IWK2:` code: LZFSE-compressed JSON, URL-safe base64 — identical to iOS. */
    fun generateShareCode(deck: Deck): String {
        val shareable = CompactShareableDeck(
            name = deck.name,
            description = deck.deckDescription,
            format = deck.format,
            inkColors = deck.inkColors,
            archetype = deck.archetype,
            coconutLeader = deck.coconutLeader,
            cards = deck.cards.map {
                CompactShareableCard(it.cardId, if (it.cardVariant == CardVariant.NORMAL) null else it.variant, it.quantity)
            },
        )
        val bytes = Json { encodeDefaults = true; explicitNulls = false }
            .encodeToString(CompactShareableDeck.serializer(), shareable).toByteArray()
        return SHARE_PREFIX_V2 + base64UrlEncode(Lzfse.encode(bytes))
    }

    data class SharePreview(val name: String, val totalCards: Int)

    fun previewShareCode(code: String): SharePreview? = decodeShareCode(code)?.let { SharePreview(it.name, it.totalCards) }

    fun importDeck(shareCode: String): Deck? {
        val decoded = decodeShareCode(shareCode) ?: return null
        val deck = Deck(
            name = decoded.name,
            deckDescription = decoded.description,
            format = (DeckFormat.fromRaw(decoded.format) ?: DeckFormat.INFINITY_CONSTRUCTED).rawValue,
            inkColors = decoded.inkColors.mapNotNull { InkColor.fromString(it)?.rawValue },
            archetype = DeckArchetype.fromRaw(decoded.archetype)?.rawValue,
            coconutLeader = decoded.coconutLeader,
        )
        decoded.cards.forEach { (card, quantity) -> deck.cards += DeckCard.from(card, quantity) }
        all += deck
        persist()
        refresh()
        Analytics.send("deck.imported", mapOf("format" to deck.format))
        return deck
    }

    private fun decodeShareCode(input: String): DecodedSharedDeck? {
        val code = extractShareCode(input) ?: return null
        return runCatching {
            if (code.startsWith(SHARE_PREFIX_V2)) {
                val data = base64UrlDecode(code.removePrefix(SHARE_PREFIX_V2)) ?: return null
                val shareable = shareJson.decodeFromString(CompactShareableDeck.serializer(), String(Lzfse.decode(data)))
                val resolved = shareable.cards.mapNotNull { compact ->
                    val dbCard = SetsDataManager.card(compact.id) ?: return@mapNotNull null
                    val variant = CardVariant.fromRaw(compact.variant) ?: CardVariant.NORMAL
                    Pair(if (variant == dbCard.variant) dbCard else dbCard.copy(variant = variant), compact.quantity)
                }
                DecodedSharedDeck(
                    shareable.name, shareable.description, shareable.format, shareable.inkColors,
                    shareable.archetype, shareable.coconutLeader, resolved, shareable.cards.sumOf { it.quantity },
                )
            } else if (code.startsWith(SHARE_PREFIX_V1)) {
                val data = Base64.getMimeDecoder().decode(code.removePrefix(SHARE_PREFIX_V1))
                val shareable = shareJson.decodeFromString(ShareableDeck.serializer(), String(Lzfse.decode(data)))
                val cards = shareable.cards.map {
                    Pair(
                        LorcanaCard(
                            id = it.cardId, name = it.name, cost = it.cost, type = it.type,
                            rarity = CardRarity.fromRaw(it.rarity) ?: CardRarity.COMMON, setName = it.setName,
                            imageUrl = it.imageUrl, variant = CardVariant.fromRawOrNormal(it.variant),
                            inkwell = it.inkwell, inkColor = it.inkColor,
                        ),
                        it.quantity,
                    )
                }
                DecodedSharedDeck(
                    shareable.name, shareable.description, shareable.format, shareable.inkColors,
                    shareable.archetype, null, cards, shareable.cards.sumOf { it.quantity },
                )
            } else {
                null
            }
        }.getOrNull()
    }

    companion object {
        const val SHARE_PREFIX_V2 = "IWK2:"
        const val SHARE_PREFIX_V1 = "IWK:"

        val serializer = ListSerializer(Deck.serializer())

        /**
         * Pulls a share code out of pasted text: a raw code, an https://inkwellkeeper.app/deck?code=
         * link, or an inkwellkeeper://deck?code= deep link.
         */
        fun extractShareCode(text: String): String? {
            val trimmed = text.trim()
            if (trimmed.startsWith(SHARE_PREFIX_V2) || trimmed.startsWith(SHARE_PREFIX_V1)) return trimmed
            val lowered = trimmed.lowercase()
            if (lowered.startsWith("http") || lowered.startsWith("inkwellkeeper://")) {
                val query = runCatching { URI(trimmed).rawQuery }.getOrNull() ?: return null
                val code = query.split("&").map { it.split("=", limit = 2) }
                    .firstOrNull { it.size == 2 && it[0] == "code" }
                    ?.let { URLDecoder.decode(it[1].replace("+", "%2B"), "UTF-8") } ?: return null
                if (code.startsWith(SHARE_PREFIX_V2) || code.startsWith(SHARE_PREFIX_V1)) return code
            }
            return null
        }

        /** URL-safe, unpadded base64 (RFC 4648 §5) so codes survive a `?code=` query. */
        fun base64UrlEncode(data: ByteArray): String = Base64.getUrlEncoder().withoutPadding().encodeToString(data)

        fun base64UrlDecode(text: String): ByteArray? = runCatching { Base64.getUrlDecoder().decode(text) }.getOrNull()
    }
}
