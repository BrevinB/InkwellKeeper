package co.brevinb.inkwellkeeper.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.decks.DeckManager
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.storage.StorageManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.io.File

/**
 * App-wide object graph — the Android counterpart of the managers ContentView injects into the
 * SwiftUI environment. Created once by [co.brevinb.inkwellkeeper.InkwellKeeperApp].
 */
class AppContainer(context: Context) {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val dataDir = File(context.filesDir, "data")

    val photosDir: File = File(context.filesDir, "photos").apply { mkdirs() }

    val collection = CollectionManager(
        JsonFileStore(File(dataDir, "collection.json"), CollectionManager.serializer, scope),
        scope,
    )
    val decks = DeckManager(JsonFileStore(File(dataDir, "decks.json"), DeckManager.serializer, scope), scope)
    val storage = StorageManager(JsonFileStore(File(dataDir, "storage.json"), StorageManager.serializer, scope), collection)

    /** The multi-scan tray, kept for the session so switching tabs doesn't drop scans. */
    val scan = co.brevinb.inkwellkeeper.scan.ScanSession()
    val rules by lazy { co.brevinb.inkwellkeeper.ai.RulesAssistant(context) }
    val aiDecks by lazy { co.brevinb.inkwellkeeper.ai.AIDeckService(context) }

    var isReady by mutableStateOf(false)
        private set

    init {
        collection.onOwnedQuantityChanged = { card, owned -> storage.reconcile(card, owned) }
        collection.onAllDataDeleted = {
            decks.deleteAll()
            storage.deleteAll()
        }
        collection.onCardAdded = { count -> ReviewManager.recordCardAdded(count) }
        storage.deckNameLookup = { id -> decks.deck(id)?.name }
        scope.launch {
            collection.load()
            decks.load()
            storage.load()
            isReady = true
        }
    }

    /** Copies of a card sitting in built decks' boxes. Idea decks don't claim cards. */
    fun deckAllocations(card: LorcanaCard): List<DeckAllocation> {
        val byDeck = mutableMapOf<String, Int>()
        for (container in storage.containers) {
            val deckId = container.linkedDeckId ?: continue
            for (item in container.items) {
                if (item.name == card.name && item.setName == card.setName) byDeck.merge(deckId, item.quantity, Int::plus)
            }
        }
        return byDeck.mapNotNull { (id, qty) -> decks.deck(id)?.let { DeckAllocation(it.name, qty) } }
    }

    /** Writes every store immediately (app going to the background). */
    fun flush() {
        if (!isReady) return
        collection.flush()
        decks.flush()
        storage.flush()
    }
}
