package co.brevinb.inkwellkeeper.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer

/**
 * The collector's cards and wishlist — a port of the iOS `CollectionManager`. All rows live in
 * memory (main thread only) and are persisted to JSON after each change.
 */
class CollectionManager(
    private val store: JsonFileStore<List<CollectedCard>>,
    private val scope: CoroutineScope,
) {
    private var rows = mutableListOf<CollectedCard>()

    /** Bumped on every change; read by query helpers so Compose recomposes. */
    var revision by mutableIntStateOf(0)
        private set

    var collectedCards: List<LorcanaCard> by mutableStateOf(emptyList())
        private set
    var wishlistCards: List<LorcanaCard> by mutableStateOf(emptyList())
        private set
    var isLoaded by mutableStateOf(false)
        private set

    /** Card key ("name||setName") → owned quantity (Normal + Foil), for deck building. */
    var collectedCardQuantities: Map<String, Int> = emptyMap()
        private set
    private var ownedQuantityByCardId: Map<String, Int> = emptyMap()
    private var ownedQuantityByNameSetVariant: Map<String, Int> = emptyMap()

    /** Fired after a card's owned count changes through an edit or removal. */
    var onOwnedQuantityChanged: ((LorcanaCard, Int) -> Unit)? = null
    /** Fired after Delete All Data. */
    var onAllDataDeleted: (() -> Unit)? = null
    /** Fired when the collection grows, with the new number of distinct printings. */
    var onCardAdded: ((Int) -> Unit)? = null

    suspend fun load() {
        rows = store.load()?.toMutableList() ?: mutableListOf()
        mergeDuplicateCollectedCards()
        refresh()
        isLoaded = true
    }

    /** Every non-wishlist row; callers must not mutate them except through this manager. */
    val collectedRows: List<CollectedCard> get() {
        revision
        return rows.filter { !it.isWishlisted }
    }

    private fun refresh() {
        val collected = rows.filter { !it.isWishlisted }.sortedByDescending { it.dateAdded }
        val wishlist = rows.filter { it.isWishlisted }.sortedByDescending { it.dateAdded }
        rebuildIndexes(collected)
        collectedCards = collected.map { it.toLorcanaCard() }
        wishlistCards = wishlist.map { it.toLorcanaCard() }
        revision++
    }

    private fun rebuildIndexes(collected: List<CollectedCard>) {
        val byId = HashMap<String, Int>()
        val byNameSetVariant = HashMap<String, Int>()
        val quantities = HashMap<String, Int>()
        for (card in collected) {
            val variant = card.variant ?: "Normal"
            byId.merge(card.cardId, card.quantity, Int::plus)
            byNameSetVariant.merge(ownershipKey(card.name, card.setName, variant), card.quantity, Int::plus)
            val parsed = CardVariant.fromRawOrNormal(variant)
            if (parsed == CardVariant.NORMAL || parsed == CardVariant.FOIL) {
                quantities.merge(cardKey(card.name, card.setName), card.quantity, Int::plus)
            }
        }
        ownedQuantityByCardId = byId
        ownedQuantityByNameSetVariant = byNameSetVariant
        collectedCardQuantities = quantities
    }

    private fun persist() {
        store.scheduleSave { rows.toList() }
    }

    /** Saves edits made directly to a row (condition, notes, purchase price, photos). */
    fun saveContext() {
        persist()
        refresh()
    }

    fun flush() = store.saveNow(rows.toList())

    /**
     * Collapses duplicate rows (same wishlist state + identity + variant), keeping the earliest.
     * Mirrors the iOS merge so restored backups and imports can't double up.
     */
    private fun mergeDuplicateCollectedCards() {
        val groups = rows.groupBy { card ->
            val identity = if (!card.uniqueId.isNullOrEmpty()) card.uniqueId!! else "${card.name}||${card.setName}"
            "${card.isWishlisted}|$identity|${card.variant ?: "Normal"}"
        }
        var changed = false
        for ((_, group) in groups) {
            if (group.size < 2) continue
            val sorted = group.sortedBy { it.dateAdded }
            val survivor = sorted.first()
            for (dup in sorted.drop(1)) {
                survivor.quantity = maxOf(survivor.quantity, dup.quantity)
                if (survivor.price == null) survivor.price = dup.price
                if (dup.photoPaths.isNotEmpty()) survivor.photoPaths = survivor.photoPaths + dup.photoPaths
                rows.remove(dup)
                changed = true
            }
        }
        if (changed) persist()
    }

    // MARK: - Adding & removing

    private fun findExisting(card: LorcanaCard, wishlisted: Boolean = false): CollectedCard? {
        val variant = card.variant.rawValue
        return if (!card.uniqueId.isNullOrEmpty()) {
            rows.firstOrNull { it.uniqueId == card.uniqueId && it.variant == variant && it.isWishlisted == wishlisted }
        } else {
            rows.firstOrNull { it.name == card.name && it.setName == card.setName && it.variant == variant && it.isWishlisted == wishlisted }
        }
    }

    /**
     * Adds copies of a printing (merging into the existing row). With [bulkImport] the caller
     * must call [finalizeBulkImport] once at the end; prices are then fetched lazily.
     */
    fun addCard(
        card: LorcanaCard,
        quantity: Int = 1,
        photoPaths: List<String> = emptyList(),
        bulkImport: Boolean = false,
        source: String = "manual",
    ) {
        val existing = findExisting(card)
        if (existing != null) {
            existing.quantity += quantity
            existing.dateAdded = System.currentTimeMillis()
            if (photoPaths.isNotEmpty()) existing.photoPaths = existing.photoPaths + photoPaths
        } else {
            rows += CollectedCard.from(card, quantity).also { it.photoPaths = photoPaths }
        }
        Analytics.send("collection.cardAdded", mapOf("rarity" to card.rarity.rawValue, "set" to card.setName, "source" to source))
        if (bulkImport) return

        persist()
        refresh()
        onCardAdded?.invoke(collectedCards.size)
        scope.launch { updateCardPrice(card) }
    }

    fun finalizeBulkImport() {
        persist()
        refresh()
        onCardAdded?.invoke(collectedCards.size)
    }

    fun attachPhotos(paths: List<String>, card: LorcanaCard) {
        if (paths.isEmpty()) return
        val row = getCollectedCardDataForVariant(card) ?: return
        row.photoPaths = row.photoPaths + paths
        saveContext()
    }

    fun removeCard(card: LorcanaCard) {
        val removed = if (!card.uniqueId.isNullOrEmpty()) {
            rows.removeAll { it.uniqueId == card.uniqueId && it.variant == card.variant.rawValue && !it.isWishlisted }
        } else {
            rows.removeAll { it.cardId == card.id && !it.isWishlisted }
        }
        if (!removed) return
        persist()
        refresh()
        onOwnedQuantityChanged?.invoke(card, 0)
    }

    fun addToWishlist(card: LorcanaCard) {
        rows += CollectedCard.from(card, quantity = 1, wishlisted = true)
        persist()
        refresh()
    }

    fun removeFromWishlist(card: LorcanaCard) {
        if (rows.removeAll { it.cardId == card.id && it.isWishlisted }) {
            persist()
            refresh()
        }
    }

    fun isWishlisted(card: LorcanaCard): Boolean {
        revision
        return rows.any { it.isWishlisted && it.cardId == card.id }
    }

    fun updateCardQuantity(card: LorcanaCard, newQuantity: Int) {
        val existing = if (!card.uniqueId.isNullOrEmpty()) findExisting(card)
        else rows.firstOrNull { it.cardId == card.id && !it.isWishlisted }
        existing ?: return
        if (newQuantity <= 0) rows.remove(existing) else existing.quantity = newQuantity
        persist()
        refresh()
        onOwnedQuantityChanged?.invoke(card, maxOf(0, newQuantity))
    }

    fun clearAllData() {
        rows.clear()
        persist()
        refresh()
    }

    /** Settings → Delete All Data: collection and wishlist here; decks and storage via callback. */
    fun deleteAllData() {
        rows.clear()
        persist()
        refresh()
        onAllDataDeleted?.invoke()
    }

    // MARK: - Lookups

    /**
     * The collected row for a card. Special printings match uniqueId + variant; Normal/Foil
     * match uniqueId alone (either finish), falling back to name + set.
     */
    fun getCollectedCardData(card: LorcanaCard): CollectedCard? {
        revision
        val collected = rows.filter { !it.isWishlisted }
        val special = card.variant.isSpecialPrinting
        if (!card.uniqueId.isNullOrEmpty()) {
            val found = if (special) collected.firstOrNull { it.uniqueId == card.uniqueId && it.variant == card.variant.rawValue }
            else collected.firstOrNull { it.uniqueId == card.uniqueId }
            if (found != null) return found
        }
        return if (special) {
            collected.firstOrNull { it.name == card.name && it.setName == card.setName && it.variant == card.variant.rawValue }
        } else {
            collected.firstOrNull { it.name == card.name && it.setName == card.setName && !it.cardVariant.isSpecialPrinting }
        }
    }

    /** The collected row for exactly this printing (Normal and Foil treated separately). */
    fun getCollectedCardDataForVariant(card: LorcanaCard): CollectedCard? {
        revision
        return findExisting(card)
    }

    /** Variant-aware row for normal/foil cards, any-match for special printings. */
    fun collectedRow(card: LorcanaCard): CollectedCard? =
        if (card.variant == CardVariant.NORMAL || card.variant == CardVariant.FOIL) getCollectedCardDataForVariant(card)
        else getCollectedCardData(card)

    fun collectedRowsByIdentity(): Map<String, CollectedCard> {
        revision
        val result = HashMap<String, CollectedCard>()
        for (row in rows) {
            if (row.isWishlisted) continue
            val variant = row.variant ?: "Normal"
            if (!row.uniqueId.isNullOrEmpty()) result["${row.uniqueId}|$variant"] = row
            result["${row.name}|${row.setName}|$variant"] = row
        }
        return result
    }

    /** Owned copies keyed by identity (see [LorcanaCard.identityKey]). */
    fun ownedQuantitiesByIdentity(): Map<String, Int> {
        revision
        val owned = HashMap<String, Int>()
        for (row in rows) if (!row.isWishlisted) owned.merge(row.identityKey, row.quantity, Int::plus)
        return owned
    }

    fun ownedQuantity(card: LorcanaCard): Int {
        revision
        val key = card.identityKey
        return rows.filter { !it.isWishlisted && it.identityKey == key }.sumOf { it.quantity }
    }

    fun isCardCollected(cardId: String): Boolean {
        revision
        return (ownedQuantityByCardId[cardId] ?: 0) > 0
    }

    fun isCardCollectedByName(name: String, setName: String, variant: CardVariant): Boolean =
        getCollectedQuantityByName(name, setName, variant) > 0

    fun getCollectedQuantity(cardId: String): Int {
        revision
        return ownedQuantityByCardId[cardId] ?: 0
    }

    fun getCollectedQuantityByName(name: String, setName: String, variant: CardVariant): Int {
        revision
        return ownedQuantityByNameSetVariant[ownershipKey(name, setName, variant.rawValue)] ?: 0
    }

    /** Owned quantity across Normal + Foil combined. */
    fun getCollectedQuantityAnyVariant(name: String, setName: String): Int {
        revision
        return collectedCardQuantities[cardKey(name, setName)] ?: 0
    }

    fun isCardCollectedAnyVariant(name: String, setName: String): Boolean = getCollectedQuantityAnyVariant(name, setName) > 0

    /** Whether any copy of this catalog card is owned, matching the Sets screen's rules. */
    fun isOwned(card: LorcanaCard): Boolean = if (card.variant.isSpecialPrinting) {
        if (!card.uniqueId.isNullOrEmpty()) getCollectedQuantityByUniqueId(card.uniqueId, card.variant) > 0
        else isCardCollectedByName(card.name, card.setName, card.variant)
    } else {
        isCardCollectedAnyVariant(card.name, card.setName)
    }

    fun getCollectedQuantityByUniqueId(uniqueId: String, variant: CardVariant): Int {
        revision
        return rows.firstOrNull { it.uniqueId == uniqueId && it.variant == variant.rawValue && !it.isWishlisted }?.quantity ?: 0
    }

    data class SetProgress(val collected: Int, val total: Int, val percentage: Double)

    fun getSetProgress(setName: String, totalCardsInSet: Int): SetProgress {
        revision
        val ownedSpecial = HashSet<String>()
        val ownedNormal = HashSet<String>()
        for (collected in collectedCards) {
            if (collected.variant.isSpecialPrinting) {
                ownedSpecial += if (!collected.uniqueId.isNullOrEmpty()) collected.uniqueId
                else "${collected.name}||${collected.setName}||${collected.variant.rawValue}"
            } else {
                ownedNormal += "${collected.name}||${collected.setName}"
            }
        }
        val count = SetsDataManager.getCardsForSet(setName).count { card ->
            if (card.variant.isSpecialPrinting) {
                if (!card.uniqueId.isNullOrEmpty()) card.uniqueId in ownedSpecial
                else "${card.name}||${card.setName}||${card.variant.rawValue}" in ownedSpecial
            } else {
                "${card.name}||${card.setName}" in ownedNormal
            }
        }
        val pct = if (totalCardsInSet > 0) count.toDouble() / totalCardsInSet * 100 else 0.0
        return SetProgress(count, totalCardsInSet, pct)
    }

    // MARK: - Prices

    private suspend fun updateCardPrice(card: LorcanaCard) {
        val price = PricingService.getMarketPrice(card) ?: return
        val variant = card.variant.rawValue
        val targets = if (!card.uniqueId.isNullOrEmpty()) rows.filter { it.uniqueId == card.uniqueId && it.variant == variant }
        else rows.filter { it.name == card.name && it.setName == card.setName && it.variant == variant }
        if (targets.isEmpty()) return
        targets.forEach { it.price = price }
        persist()
        refresh()
    }

    var isRefreshingPrices by mutableStateOf(false)
        private set

    /** Refreshes every row's price, gently rate-limited. */
    suspend fun refreshAllPrices(onProgress: (Int, Int) -> Unit = { _, _ -> }) {
        if (isRefreshingPrices) return
        isRefreshingPrices = true
        val snapshot = rows.toList()
        for ((index, row) in snapshot.withIndex()) {
            if (index > 0 && index % 10 == 0) delay(1000)
            row.price = PricingService.getMarketPrice(row.toLorcanaCard())
            onProgress(index + 1, snapshot.size)
        }
        persist()
        refresh()
        isRefreshingPrices = false
    }

    /** Replaces the whole collection (backup restore with "replace"). */
    fun replaceAll(newRows: List<CollectedCard>) {
        rows = newRows.toMutableList()
        persist()
        refresh()
    }

    companion object {
        fun cardKey(name: String, setName: String) = "$name||$setName"
        private fun ownershipKey(name: String, setName: String, variant: String) = "$name||$setName||$variant"

        val serializer = ListSerializer(CollectedCard.serializer())
    }
}

/** A deck that claims copies of a card (it's built into a deck box). */
@Serializable
data class DeckAllocation(val deckName: String, val quantity: Int)
