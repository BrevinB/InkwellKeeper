package co.brevinb.inkwellkeeper.storage

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.CollectionManager
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.JsonFileStore
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.serialization.builtins.ListSerializer

/**
 * The collector's physical storage: binders, troves, boxes and bins, and which copies of each
 * card live where. A port of the iOS `StorageManager`.
 *
 * Invariant: for any card, the copies stored across all containers never exceed the copies
 * owned. Copies not stored anywhere are "Unsorted" — derived, never persisted.
 */
class StorageManager(
    private val store: JsonFileStore<List<StorageContainer>>,
    private val collection: CollectionManager,
) {
    var revision by mutableIntStateOf(0)
        private set

    var containers: List<StorageContainer> by mutableStateOf(emptyList())
        private set

    private var itemsByIdentity: Map<String, List<StoredCard>> = emptyMap()

    /** Total copies stored anywhere, keyed by identity. */
    var storedQuantityByIdentity: Map<String, Int> by mutableStateOf(emptyMap())
        private set

    /** Looks up a deck's name for deck-box labels. */
    var deckNameLookup: (String) -> String? = { null }

    private val printingsCache = mutableMapOf<String, Map<Int, CardVariant>>()

    suspend fun load() {
        containers = (store.load() ?: emptyList()).sortedWith(compareBy({ it.sortOrder }, { it.createdDate }))
        containers.forEach { container -> container.items.forEach { it.containerId = container.id } }
        mergeDuplicateStoredCards()
        rebuildIndex()
        reconcileAll()
    }

    private fun rebuildIndex() {
        val byIdentity = HashMap<String, MutableList<StoredCard>>()
        val quantities = HashMap<String, Int>()
        for (container in containers) {
            for (item in container.items) {
                byIdentity.getOrPut(item.identityKey) { mutableListOf() }.add(item)
                quantities.merge(item.identityKey, item.quantity, Int::plus)
            }
        }
        itemsByIdentity = byIdentity
        storedQuantityByIdentity = quantities
        revision++
    }

    private fun save() {
        store.scheduleSave { containers.toList() }
        rebuildIndex()
    }

    fun flush() = store.saveNow(containers.toList())

    fun container(id: String?): StorageContainer? {
        revision
        return containers.firstOrNull { it.id == id }
    }

    // MARK: - Containers

    /** Deck boxes holding a built deck don't count: building decks is never paywalled. */
    fun canCreateContainer(isSubscribed: Boolean): Boolean =
        isSubscribed || containers.count { it.linkedDeckId == null } < FREE_CONTAINER_LIMIT

    fun createContainer(name: String, kind: StorageKind, configure: (StorageContainer) -> Unit = {}): StorageContainer {
        val trimmed = name.trim()
        val container = StorageContainer.create(
            name = trimmed.ifEmpty { kind.displayName },
            kind = kind,
            sortOrder = (containers.maxOfOrNull { it.sortOrder } ?: -1) + 1,
        )
        configure(container)
        containers = containers + container
        save()
        Analytics.send("storage.containerCreated", mapOf("kind" to kind.rawValue))
        return container
    }

    fun rename(container: StorageContainer, name: String) {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) return
        container.name = trimmed
        save()
    }

    /** Saves edits made directly to a container's properties (settings sheet). */
    fun containerDidChange(container: StorageContainer) {
        if (container.kind.usesSlots) relocateOutOfRangeItems(container)
        save()
    }

    /** Deletes the container; its cards simply become Unsorted again. */
    fun delete(container: StorageContainer) {
        containers = containers.filter { it.id != container.id }
        save()
    }

    fun moveContainer(from: Int, to: Int) {
        val list = containers.toMutableList()
        if (from !in list.indices || to !in list.indices) return
        list.add(to, list.removeAt(from))
        list.forEachIndexed { index, container -> container.sortOrder = index }
        containers = list
        save()
    }

    fun deleteAll() {
        containers = emptyList()
        save()
    }

    // MARK: - Queries

    fun storedQuantity(card: LorcanaCard): Int = storedQuantityByIdentity[card.identityKey] ?: 0

    fun unsortedQuantity(card: LorcanaCard): Int = maxOf(0, collection.ownedQuantity(card) - storedQuantity(card))

    fun locations(card: LorcanaCard): List<StorageAllocation> {
        revision
        val items = itemsByIdentity[card.identityKey] ?: return emptyList()
        return containers.mapNotNull { container ->
            val held = items.filter { it.containerId == container.id }
            if (held.isEmpty()) return@mapNotNull null
            val layout = container.binderLayout
            StorageAllocation(
                containerId = container.id,
                containerName = container.name,
                kind = container.kind,
                quantity = held.sumOf { it.quantity },
                pockets = held.mapNotNull { it.slotIndex }.sorted().map { slot ->
                    val (page, pocket) = layout.position(slot)
                    StorageAllocation.BinderPocket(page + 1, pocket + 1)
                },
            )
        }
    }

    fun identityKeys(container: StorageContainer): Set<String> = container.items.map { it.identityKey }.toSet()

    /** Value from prices snapshotted when cards were stored. */
    fun value(container: StorageContainer): Double = container.items.sumOf { (it.price ?: 0.0) * it.quantity }

    /** Unsorted copies of every card that has any, keyed by identity. */
    fun unsortedQuantitiesByIdentity(): Map<String, Int> {
        revision
        val stored = storedQuantityByIdentity
        return collection.ownedQuantitiesByIdentity().mapNotNull { (key, owned) ->
            val remaining = owned - (stored[key] ?: 0)
            if (remaining > 0) key to remaining else null
        }.toMap()
    }

    // MARK: - Room

    /** Free pockets in a binder, remaining capacity in a box; null means unlimited. */
    fun freeSpace(container: StorageContainer): Int? {
        if (container.kind.usesSlots) return maxOf(0, container.binderLayout.totalSlots - occupiedSlots(container).size)
        val capacity = container.capacity ?: return null
        return maxOf(0, capacity - container.cardCount)
    }

    fun isFull(container: StorageContainer): Boolean = freeSpace(container) == 0

    // MARK: - Storing

    /** Stores up to [quantity] unsorted copies, capped by room. Returns how many were stored. */
    fun store(card: LorcanaCard, quantity: Int = 1, container: StorageContainer, source: String = "detail"): Int {
        val stored = insert(card, minOf(quantity, unsortedQuantity(card)), container)
        if (stored <= 0) return 0
        save()
        Analytics.send("storage.cardsStored", mapOf("count" to "$stored", "kind" to container.kind.rawValue, "source" to source))
        return stored
    }

    data class StoreResult(val stored: Int, val added: Int)

    /**
     * Puts cards away even when no copies are unsorted: missing copies are added to the
     * collection first, but only copies that will actually fit.
     */
    fun storeAddingToCollection(picks: List<Pair<LorcanaCard, Int>>, container: StorageContainer): StoreResult {
        var room = freeSpace(container)
        val claimedPockets = mutableSetOf<Int>()
        val plan = mutableListOf<Pair<LorcanaCard, Int>>()
        var added = 0
        for ((card, quantity) in picks) {
            if (!canAccept(card, container)) continue
            var take = minOf(quantity, room ?: quantity)
            val pocket = setPocket(card, container)
            if (pocket != null) {
                // A checklist pocket holds one card, and two picks can't share it.
                if (!claimedPockets.add(pocket)) continue
                take = minOf(take, 1)
            }
            if (take <= 0) continue
            val missing = maxOf(0, take - unsortedQuantity(card))
            if (missing > 0) {
                collection.addCard(card, missing, bulkImport = true, source = "storage")
                added += missing
            }
            room = room?.minus(take)
            plan += Pair(card, take)
        }
        if (added > 0) collection.finalizeBulkImport()
        val stored = plan.sumOf { (card, q) -> store(card, q, container, source = "catalog") }
        return StoreResult(stored, added)
    }

    /** Inserts without the owned check or a save. Room is enforced here. */
    private fun insert(card: LorcanaCard, requested: Int, container: StorageContainer): Int {
        val quantity = minOf(requested, freeSpace(container) ?: requested)
        if (quantity <= 0 || !accepts(card, container)) return 0
        if (container.kind.usesSlots) {
            val occupied = occupiedSlots(container).toMutableSet()
            var stored = 0
            repeat(quantity) {
                val slot = preferredSlot(card, container, occupied) ?: return stored
                container.items += StoredCard.from(card, 1, slot, container.id)
                occupied += slot
                stored++
            }
            return stored
        }
        val key = card.identityKey
        val existing = container.items.firstOrNull { it.identityKey == key && it.originContainerId == null && it.originSlot == null }
        if (existing != null) {
            existing.quantity += quantity
            existing.price = card.price ?: existing.price
        } else {
            container.items += StoredCard.from(card, quantity, null, container.id)
        }
        return quantity
    }

    fun unstore(card: LorcanaCard, quantity: Int = 1, container: StorageContainer) {
        val key = card.identityKey
        removeCopies(quantity, container.items.filter { it.identityKey == key }.sortedByDescending { it.slotIndex ?: 0 })
        save()
    }

    fun move(card: LorcanaCard, quantity: Int = 1, source: StorageContainer, destination: StorageContainer) {
        if (source.id == destination.id) return
        val key = card.identityKey
        val held = source.items.filter { it.identityKey == key }
        val toMove = minOf(quantity, held.sumOf { it.quantity })
        if (toMove <= 0) return
        val moved = insert(card, toMove, destination)
        removeCopies(moved, held.sortedByDescending { it.slotIndex ?: 0 })
        save()
    }

    data class BulkMoveResult(val moved: Int, val leftBehind: Int)

    /** Moves every copy in [items] to [destination] (or Unsorted when null). */
    fun moveItems(items: List<StoredCard>, destination: StorageContainer?): BulkMoveResult {
        var moved = 0
        var left = 0
        for (item in items.sortedBy { it.slotIndex ?: 0 }) {
            if (item.containerId == destination?.id) continue
            val copies = item.quantity
            val count = destination?.let { insert(item.toLorcanaCard(), copies, it) } ?: copies
            removeCopies(count, listOf(item))
            moved += count
            left += copies - count
        }
        if (moved > 0) save()
        return BulkMoveResult(moved, left)
    }

    fun remove(item: StoredCard) {
        container(item.containerId)?.items?.removeAll { it.id == item.id }
        save()
    }

    private fun removeCopies(count: Int, rows: List<StoredCard>) {
        var remaining = count
        for (row in rows) {
            if (remaining <= 0) break
            if (row.quantity > remaining) {
                row.quantity -= remaining
                remaining = 0
            } else {
                remaining -= row.quantity
                containers.firstOrNull { it.id == row.containerId }?.items?.removeAll { it.id == row.id }
            }
        }
    }

    // MARK: - Binder pockets

    fun occupiedSlots(binder: StorageContainer): Set<Int> = binder.items.mapNotNull { it.slotIndex }.toSet()

    fun item(slot: Int, binder: StorageContainer): StoredCard? = binder.items.firstOrNull { it.slotIndex == slot }

    private fun preferredSlot(card: LorcanaCard, binder: StorageContainer, occupied: Set<Int>): Int? {
        if (binder.linkedSetName != null) {
            val slot = setPocket(card, binder) ?: return null
            return if (slot in occupied) null else slot
        }
        return binder.binderLayout.firstEmptySlot(occupied)
    }

    fun setPocket(card: LorcanaCard, binder: StorageContainer): Int? {
        val setName = binder.linkedSetName ?: return null
        if (card.setName != setName) return null
        val number = card.cardNumber ?: return null
        val slot = checklistLayout(binder)?.slot(number, card.variant) ?: return null
        return if (binder.binderLayout.contains(slot)) slot else null
    }

    fun checklistLayout(binder: StorageContainer): SetChecklistLayout? {
        val setName = binder.linkedSetName ?: return null
        return SetChecklistLayout(printings(setName), binder.hasFoilPockets)
    }

    /** The "missing card" ghost for every pocket of a set binder, keyed by slot. */
    fun checklistGhosts(binder: StorageContainer): Map<Int, LorcanaCard> {
        val setName = binder.linkedSetName ?: return emptyMap()
        val layout = checklistLayout(binder) ?: return emptyMap()
        val byNumber = mutableMapOf<Int, LorcanaCard>()
        for (card in SetsDataManager.getCardsForSet(setName)) {
            val number = card.cardNumber ?: continue
            byNumber.putIfAbsent(number, card)
        }
        val ghosts = mutableMapOf<Int, LorcanaCard>()
        for (slot in 0 until minOf(layout.pocketCount, binder.binderLayout.totalSlots)) {
            val pocket = layout.pocket(slot) ?: continue
            val card = byNumber[pocket.number] ?: continue
            ghosts[slot] = if (pocket.isFoilPocket) card.withVariant(CardVariant.FOIL) else card
        }
        return ghosts
    }

    fun upgradeTarget(card: LorcanaCard, binder: StorageContainer): StoredCard? {
        if (card.variant != CardVariant.FOIL || binder.hasFoilPockets) return null
        val slot = setPocket(card, binder) ?: return null
        val occupant = item(slot, binder) ?: return null
        return if (occupant.cardVariant == CardVariant.NORMAL && unsortedQuantity(card) > 0) occupant else null
    }

    /** Swaps a foil into the pocket its normal copy holds; the normal goes to Unsorted. */
    fun upgradeToFoil(card: LorcanaCard, binder: StorageContainer): Boolean {
        val occupant = upgradeTarget(card, binder) ?: return false
        val slot = occupant.slotIndex ?: return false
        binder.items.removeAll { it.id == occupant.id }
        binder.items += StoredCard.from(card, 1, slot, binder.id)
        save()
        return true
    }

    private fun printings(setName: String): Map<Int, CardVariant> {
        printingsCache[setName]?.takeIf { it.isNotEmpty() }?.let { return it }
        return SetChecklistLayout.catalogPrintings(setName).also { printingsCache[setName] = it }
    }

    fun accepts(card: LorcanaCard, container: StorageContainer): Boolean =
        container.linkedSetName == null || setPocket(card, container) != null

    fun canAccept(card: LorcanaCard, container: StorageContainer): Boolean {
        if (!accepts(card, container) || isFull(container)) return false
        if (container.linkedSetName != null) {
            setPocket(card, container)?.let { return item(it, container) == null }
        }
        return true
    }

    fun refusal(card: LorcanaCard, container: StorageContainer): String? {
        if (!accepts(card, container)) return "Only ${container.linkedSetName ?: ""} cards"
        if (isFull(container)) return "Full"
        if (!canAccept(card, container)) {
            return if (upgradeTarget(card, container) != null) "Pocket #${card.cardNumber ?: 0} has the normal copy"
            else "Pocket #${card.cardNumber ?: 0} is taken"
        }
        return null
    }

    fun place(card: LorcanaCard, slot: Int, binder: StorageContainer): Boolean {
        if (!binder.binderLayout.contains(slot) || item(slot, binder) != null) return false
        if (binder.linkedSetName != null && setPocket(card, binder) != slot) return false
        if (unsortedQuantity(card) <= 0) return false
        binder.items += StoredCard.from(card, 1, slot, binder.id)
        save()
        return true
    }

    fun placeAddingToCollection(card: LorcanaCard, slot: Int, binder: StorageContainer): Boolean {
        if (!binder.binderLayout.contains(slot) || item(slot, binder) != null) return false
        if (binder.linkedSetName != null && setPocket(card, binder) != slot) return false
        if (unsortedQuantity(card) == 0) collection.addCard(card, source = "storage")
        return place(card, slot, binder)
    }

    /** Moves a pocket's card to another pocket, swapping if that pocket is occupied. */
    fun moveItem(item: StoredCard, slot: Int) {
        val binder = container(item.containerId) ?: return
        if (!binder.binderLayout.contains(slot) || item.slotIndex == slot) return
        item(slot, binder)?.slotIndex = item.slotIndex
        item.slotIndex = slot
        save()
    }

    fun compact(binder: StorageContainer) {
        val map = BinderLayout.compactionMap(binder.items.mapNotNull { it.slotIndex })
        for (item in binder.items) item.slotIndex?.let { old -> map[old]?.let { item.slotIndex = it } }
        save()
    }

    /** Fills free pockets with unsorted copies of [cards], in the chosen order. */
    fun autoFill(binder: StorageContainer, cards: List<LorcanaCard>, order: BinderSortOrder): List<StoredCard> {
        if (!binder.kind.usesSlots) return emptyList()
        val occupied = occupiedSlots(binder).toMutableSet()
        val placed = mutableListOf<StoredCard>()
        val placedByIdentity = mutableMapOf<String, Int>()
        for (card in order.sorted(cards, SetsDataManager.setOrder())) {
            val key = card.identityKey
            val copies = unsortedQuantity(card) - (placedByIdentity[key] ?: 0)
            for (i in 0 until maxOf(0, copies)) {
                val slot = preferredSlot(card, binder, occupied) ?: break
                val item = StoredCard.from(card, 1, slot, binder.id)
                binder.items += item
                occupied += slot
                placed += item
                placedByIdentity.merge(key, 1, Int::plus)
            }
        }
        if (placed.isEmpty()) return emptyList()
        save()
        Analytics.send("storage.binderAutoFilled", mapOf("count" to "${placed.size}", "order" to order.rawValue))
        return placed
    }

    fun addSheets(count: Int, binder: StorageContainer) {
        binder.sheetCount += maxOf(0, count)
        save()
    }

    private fun relocateOutOfRangeItems(binder: StorageContainer) {
        val layout = binder.binderLayout
        val occupied = binder.items.mapNotNull { it.slotIndex }.filter { layout.contains(it) }.toMutableSet()
        for (item in binder.items.toList()) {
            val slot = item.slotIndex ?: continue
            if (layout.contains(slot)) continue
            val free = if (binder.linkedSetName == null) layout.firstEmptySlot(occupied) else null
            if (free != null) {
                item.slotIndex = free
                occupied += free
            } else {
                binder.items.remove(item)
            }
        }
    }

    // MARK: - Reconciliation

    /** If more copies are stored than owned, trims the most recently stored copies. */
    fun reconcile(card: LorcanaCard, ownedQuantity: Int): List<StorageAllocation> {
        val key = card.identityKey
        val before = locations(card)
        val excess = (storedQuantityByIdentity[key] ?: 0) - maxOf(0, ownedQuantity)
        if (excess <= 0) return emptyList()
        removeCopies(excess, (itemsByIdentity[key] ?: emptyList()).sortedByDescending { it.dateStored })
        save()
        val after = locations(card).associate { it.containerId to it.quantity }
        return before.mapNotNull { allocation ->
            val removed = allocation.quantity - (after[allocation.containerId] ?: 0)
            if (removed > 0) allocation.copy(quantity = removed, pockets = emptyList()) else null
        }
    }

    /** Trims over-stored cards across the collection. Cards with no collection row are left alone. */
    fun reconcileAll() {
        if (itemsByIdentity.isEmpty()) return
        val owned = collection.ownedQuantitiesByIdentity()
        var changed = false
        for ((key, items) in itemsByIdentity) {
            val ownedCount = owned[key] ?: continue
            val stored = items.sumOf { it.quantity }
            if (stored > ownedCount) {
                removeCopies(stored - ownedCount, items.sortedByDescending { it.dateStored })
                changed = true
            }
        }
        if (changed) save()
    }

    private fun mergeDuplicateStoredCards() {
        var changed = false
        for (container in containers) {
            if (container.items.size < 2) continue
            if (container.kind.usesSlots) {
                val layout = container.binderLayout
                val occupied = mutableSetOf<Int>()
                for (item in container.items.sortedBy { it.dateStored }) {
                    val slot = item.slotIndex ?: continue
                    if (slot in occupied) {
                        val free = layout.firstEmptySlot(occupied + container.items.mapNotNull { it.slotIndex })
                        if (free != null) {
                            item.slotIndex = free
                            occupied += free
                        } else {
                            container.items.remove(item)
                        }
                        changed = true
                    } else {
                        occupied += slot
                    }
                }
            } else {
                val groups = container.items.groupBy { "${it.identityKey}|${it.originContainerId ?: ""}|${it.originSlot ?: ""}" }
                for ((_, rows) in groups) {
                    if (rows.size < 2) continue
                    val sorted = rows.sortedBy { it.dateStored }
                    val survivor = sorted.first()
                    for (dup in sorted.drop(1)) {
                        survivor.quantity = maxOf(survivor.quantity, dup.quantity)
                        container.items.remove(dup)
                        changed = true
                    }
                }
            }
        }
        if (changed) store.scheduleSave { containers.toList() }
    }

    // MARK: - Built decks

    fun deckBox(deckId: String): StorageContainer? {
        revision
        return containers.firstOrNull { it.linkedDeckId == deckId }
    }

    fun isBuilt(deck: Deck): Boolean = deckBox(deck.id) != null

    val availableDeckBoxes: List<StorageContainer>
        get() = containers.filter { it.kind == StorageKind.DECK_BOX && it.linkedDeckId == null }

    fun deckName(deckId: String): String? = deckNameLookup(deckId)

    /** Makes a new deck box for a deck, bypassing the free limit. */
    fun createDeckBox(deck: Deck): StorageContainer {
        val color = deck.deckInkColors.firstOrNull()?.let { StorageCoverColor.fromRaw(it.rawValue.lowercase()) } ?: StorageCoverColor.MIDNIGHT
        return createContainer(deck.name, StorageKind.DECK_BOX) { box ->
            box.coverColor = color
            box.linkedDeckId = deck.id
            box.capacity = maxOf(box.capacity ?: 0, deck.totalCards)
        }
    }

    fun link(box: StorageContainer, deck: Deck) {
        box.linkedDeckId = deck.id
        box.capacity?.let { if (it < deck.totalCards) box.capacity = deck.totalCards }
        save()
    }

    fun unlinkDeck(deckId: String) {
        containers.filter { it.linkedDeckId == deckId }.forEach { it.linkedDeckId = null }
        save()
    }

    data class DeckProgress(val inBox: Int, val total: Int)

    fun deckProgress(deck: Deck, box: StorageContainer): DeckProgress {
        val boxRemaining = mutableMapOf<String, Int>()
        for (item in box.items) boxRemaining.merge(item.identityKey, item.quantity, Int::plus)
        var inBox = 0
        var total = 0
        for (deckCard in deck.cards) {
            var need = deckCard.quantity
            total += need
            for (candidate in interchangeableVariants(deckCard.toLorcanaCard())) {
                if (need <= 0) break
                val key = candidate.identityKey
                val have = minOf(need, boxRemaining[key] ?: 0)
                boxRemaining[key] = (boxRemaining[key] ?: 0) - have
                need -= have
                inBox += have
            }
        }
        return DeckProgress(inBox, total)
    }

    /**
     * Where to find every copy the deck still needs: Unsorted first, then binders and boxes in
     * shelf order, never another built deck's box. Normal and foil copies are interchangeable.
     */
    fun pullPlan(deck: Deck, box: StorageContainer): DeckPullPlan {
        val plan = DeckPullPlan()
        val sources = containers.filter { it.linkedDeckId == null && it.id != box.id }
        val boxRemaining = mutableMapOf<String, Int>()
        for (item in box.items) boxRemaining.merge(item.identityKey, item.quantity, Int::plus)
        val unsortedRemaining = unsortedQuantitiesByIdentity().toMutableMap()
        val takenItems = mutableSetOf<String>()
        val takenFromBoxRows = mutableMapOf<String, Int>()

        for (deckCard in deck.cards.sortedWith(compareBy({ it.cost }, { it.name }))) {
            val wanted = deckCard.toLorcanaCard()
            var need = deckCard.quantity
            plan.total += need
            val candidates = interchangeableVariants(wanted)

            for (candidate in candidates) {
                if (need <= 0) break
                val key = candidate.identityKey
                val have = minOf(need, boxRemaining[key] ?: 0)
                boxRemaining[key] = (boxRemaining[key] ?: 0) - have
                need -= have
                plan.inBox += have
            }
            for (candidate in candidates) {
                if (need <= 0) break
                val key = candidate.identityKey
                val take = minOf(need, unsortedRemaining[key] ?: 0)
                if (take <= 0) continue
                unsortedRemaining[key] = (unsortedRemaining[key] ?: 0) - take
                need -= take
                plan.pulls += DeckPullPlan.Pull(candidate, null, "Unsorted", null, take, emptyList(), emptyList())
            }
            for (container in sources) {
                if (need <= 0) break
                for (candidate in candidates) {
                    if (need <= 0) break
                    val key = candidate.identityKey
                    val rows = container.items.filter { it.identityKey == key }
                    if (container.kind.usesSlots) {
                        val free = rows.filter { it.id !in takenItems }.sortedBy { it.slotIndex ?: 0 }.take(need)
                        if (free.isEmpty()) continue
                        free.forEach { takenItems += it.id }
                        val slots = free.mapNotNull { it.slotIndex }
                        val layout = container.binderLayout
                        need -= free.size
                        plan.pulls += DeckPullPlan.Pull(
                            candidate, container.id, container.name, container.kind, free.size, slots,
                            slots.map { val (page, pocket) = layout.position(it); StorageAllocation.BinderPocket(page + 1, pocket + 1) },
                        )
                    } else {
                        var take = 0
                        for (row in rows) {
                            if (need <= take) break
                            val left = row.quantity - (takenFromBoxRows[row.id] ?: 0)
                            val used = minOf(left, need - take)
                            takenFromBoxRows.merge(row.id, used, Int::plus)
                            take += used
                        }
                        if (take <= 0) continue
                        need -= take
                        plan.pulls += DeckPullPlan.Pull(candidate, container.id, container.name, container.kind, take, emptyList(), emptyList())
                    }
                }
            }
            if (need > 0) plan.missing += DeckPullPlan.Shortfall(wanted, need)
        }
        return plan
    }

    /** Moves one planned pull into the deck box, remembering where each copy came from. */
    fun pull(pull: DeckPullPlan.Pull, box: StorageContainer): Int {
        var room = freeSpace(box) ?: Int.MAX_VALUE
        var moved = 0
        val key = pull.card.identityKey

        fun addToBox(copies: Int, origin: String?, slot: Int?) {
            val existing = box.items.firstOrNull { it.identityKey == key && it.originContainerId == origin && it.originSlot == slot }
            if (existing != null) {
                existing.quantity += copies
            } else {
                box.items += StoredCard.from(pull.card, copies, null, box.id).also {
                    it.originContainerId = origin
                    it.originSlot = slot
                }
            }
        }

        val sourceId = pull.sourceId
        if (sourceId != null) {
            val source = containers.firstOrNull { it.id == sourceId } ?: return 0
            val rows = source.items.filter { it.identityKey == key }
            if (source.kind.usesSlots) {
                for (row in rows) {
                    if (room <= 0 || moved >= pull.quantity) break
                    if ((row.slotIndex ?: -1) !in pull.slots) continue
                    addToBox(1, source.id, row.slotIndex)
                    source.items.removeAll { it.id == row.id }
                    moved++
                    room--
                }
            } else {
                moved = minOf(minOf(pull.quantity, room), rows.sumOf { it.quantity })
                if (moved <= 0) return 0
                removeCopies(moved, rows)
                addToBox(moved, source.id, null)
            }
        } else {
            moved = minOf(pull.quantity, room, unsortedQuantity(pull.card))
            if (moved <= 0) return 0
            addToBox(moved, null, null)
        }
        save()
        return moved
    }

    fun pullAll(plan: DeckPullPlan, box: StorageContainer): Int = plan.pulls.sumOf { pull(it, box) }

    data class TakeApartResult(val returned: Int, val unsorted: Int)

    /** Empties a deck box; with [returnToOrigins] copies go back where they came from when there's room. */
    fun takeApart(box: StorageContainer, returnToOrigins: Boolean): TakeApartResult {
        var returned = 0
        var unsorted = 0
        for (item in box.items.toList()) {
            var copies = item.quantity
            val origin = item.originContainerId?.let { id -> containers.firstOrNull { it.id == id } }
            if (returnToOrigins && origin != null && origin.id != box.id) {
                val card = item.toLorcanaCard()
                if (origin.kind.usesSlots) {
                    val occupied = occupiedSlots(origin).toMutableSet()
                    while (copies > 0) {
                        val preferred = item.originSlot?.takeIf { it !in occupied && origin.binderLayout.contains(it) }
                        val fallback = if (origin.linkedSetName == null) origin.binderLayout.firstEmptySlot(occupied) else null
                        val slot = preferred ?: fallback ?: break
                        origin.items += StoredCard.from(card, 1, slot, origin.id)
                        occupied += slot
                        copies--
                        returned++
                    }
                } else {
                    val placed = insert(card, copies, origin)
                    copies -= placed
                    returned += placed
                }
            }
            unsorted += copies
            box.items.remove(item)
        }
        box.linkedDeckId = null
        save()
        return TakeApartResult(returned, unsorted)
    }

    // MARK: - Backup restore

    data class RestoreSummary(val containers: Int, val cards: Int)

    /** Recreates containers from a backup (after its cards were imported); never over-stores. */
    fun restore(saved: List<StorageContainer>, deckExists: (String) -> Boolean): RestoreSummary {
        val existingIds = containers.map { it.id }.toSet()
        val room = collection.ownedQuantitiesByIdentity().toMutableMap()
        for ((key, stored) in storedQuantityByIdentity) room[key] = (room[key] ?: 0) - stored
        var restoredContainers = 0
        var restoredCards = 0
        val toRestore = saved.filter { it.id !in existingIds }.sortedBy { it.sortOrder }
        val newContainers = containers.toMutableList()
        for ((offset, backup) in toRestore.withIndex()) {
            val container = StorageContainer(
                id = backup.id, name = backup.name, kindRaw = backup.kindRaw, coverStyle = backup.coverStyle,
                colorName = backup.colorName, sortOrder = containers.size + offset, notes = backup.notes,
                pocketsPerPage = backup.pocketsPerPage, sheetCount = backup.sheetCount, isDoubleSided = backup.isDoubleSided,
                capacity = backup.capacity, linkedSetName = backup.linkedSetName, hasFoilPockets = backup.hasFoilPockets,
                linkedDeckId = backup.linkedDeckId?.takeIf(deckExists),
            )
            restoredContainers++
            val totalSlots = container.binderLayout.totalSlots
            val usedSlots = mutableSetOf<Int>()
            for (item in backup.items) {
                val key = item.identityKey
                val copies = minOf(item.quantity, room[key] ?: 0)
                if (copies <= 0) continue
                if (container.kind.usesSlots) {
                    val slot = item.slotIndex ?: continue
                    if (slot >= totalSlots || !usedSlots.add(slot)) continue
                }
                container.items += StoredCard.from(item.toLorcanaCard(), copies, if (container.kind.usesSlots) item.slotIndex else null, container.id).also {
                    it.originContainerId = item.originContainerId
                    it.originSlot = item.originSlot
                }
                room[key] = (room[key] ?: 0) - copies
                restoredCards += copies
            }
            newContainers += container
        }
        if (restoredContainers > 0) {
            containers = newContainers
            save()
        }
        return RestoreSummary(restoredContainers, restoredCards)
    }

    companion object {
        /** Containers a free user may create; Pro removes the limit. */
        const val FREE_CONTAINER_LIMIT = 3

        val serializer = ListSerializer(StorageContainer.serializer())

        fun interchangeableVariants(card: LorcanaCard): List<LorcanaCard> = when (card.variant) {
            CardVariant.NORMAL -> listOf(card, card.withVariant(CardVariant.FOIL))
            CardVariant.FOIL -> listOf(card, card.withVariant(CardVariant.NORMAL))
            else -> listOf(card)
        }
    }
}
