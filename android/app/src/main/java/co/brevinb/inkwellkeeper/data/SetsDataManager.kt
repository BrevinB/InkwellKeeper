package co.brevinb.inkwellkeeper.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.model.CardGroup
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.LorcanaSet
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate

/**
 * The bundled card catalog (the iOS app's `Data` folder JSON, copied into assets at build time).
 * Loads once on a background thread; [isDataLoaded] flips when search and lookups are ready.
 */
object SetsDataManager {
    var sets: List<LorcanaSet> by mutableStateOf(emptyList())
        private set
    var isDataLoaded: Boolean by mutableStateOf(false)
        private set
    var errorMessage: String? by mutableStateOf(null)
        private set

    private val _loaded = MutableStateFlow(false)
    /** Flow form of [isDataLoaded] for non-UI code that needs to wait for the catalog. */
    val loaded: StateFlow<Boolean> = _loaded

    private var setCards: Map<String, List<LorcanaCard>> = emptyMap()
    private var cachedAllCards: List<LorcanaCard> = emptyList()
    private var cardsById: Map<String, LorcanaCard> = emptyMap()
    private var normalizedSearchIndex: Map<String, String> = emptyMap()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    fun load(context: Context) {
        if (isDataLoaded) return
        val appContext = context.applicationContext
        scope.launch {
            runCatching {
                withContext(Dispatchers.IO) { loadFromAssets(appContext) }
            }.onSuccess { loaded ->
                sets = loaded.sets
                setCards = loaded.cardsBySet
                cachedAllCards = loaded.allCards
                cardsById = loaded.allCards.associateBy { it.id }
                normalizedSearchIndex = loaded.searchIndex
                isDataLoaded = true
                _loaded.value = true
            }.onFailure {
                errorMessage = it.message
            }
        }
    }

    private class Loaded(
        val sets: List<LorcanaSet>,
        val cardsBySet: Map<String, List<LorcanaCard>>,
        val allCards: List<LorcanaCard>,
        val searchIndex: Map<String, String>,
    )

    private fun loadFromAssets(context: Context): Loaded {
        val assets = context.assets
        val available = assets.list("")?.toSet().orEmpty()
        val parsedSets = CardJsonParser.parseSets(assets.open("sets.json").bufferedReader().use { it.readText() })
        val sortedSets = parsedSets.sortedWith(
            compareBy<LorcanaSet>({ it.setNumber?.toIntOrNull() ?: Int.MAX_VALUE }, { it.releaseDate ?: "" }),
        )

        val cardsBySet = mutableMapOf<String, List<LorcanaCard>>()
        for (set in sortedSets) {
            val file = "${set.id}.json"
            if (file !in available) continue
            runCatching {
                cardsBySet[set.name] = CardJsonParser.parseSetCards(assets.open(file).bufferedReader().use { it.readText() })
            }
        }

        // Deterministic set order (main sets by number, then promos) so tie-breaks in
        // scanning and search resolve identically on every launch, as on iOS.
        val all = sortedSets.flatMap { cardsBySet[it.name].orEmpty() }
        val index = HashMap<String, String>(all.size)
        for (card in all) {
            index[card.id] = listOf(card.name, card.cardText, card.type, card.setName)
                .joinToString(" ") { normalizeSearchText(it) }
        }
        return Loaded(sortedSets, cardsBySet, all, index)
    }

    // MARK: - Lookups

    fun getAllCards(): List<LorcanaCard> = cachedAllCards

    fun getCardsForSet(setName: String): List<LorcanaCard> = setCards[setName].orEmpty()

    fun getSet(byName: String): LorcanaSet? = sets.firstOrNull { it.name == byName }

    fun getSetByCode(code: String): LorcanaSet? = sets.firstOrNull { it.setCode == code }

    fun card(byId: String): LorcanaCard? = cardsById[byId]

    fun hasLocalCards(setName: String): Boolean = setCards.containsKey(setName)

    /** Names of sets whose release day hasn't arrived; their cards are hidden as spoilers. */
    fun upcomingSetNames(today: LocalDate = LocalDate.now()): Set<String> =
        sets.filter { it.isUpcoming(today) }.map { it.name }.toSet()

    /** Release order per set name (`Int.MAX_VALUE` for un-numbered promo sets). */
    fun setOrder(): Map<String, Int> = sets.associate { it.name to (it.setNumber?.toIntOrNull() ?: Int.MAX_VALUE) }

    fun getSetsForCard(cardName: String): List<String> =
        setCards.values.filter { cards -> cards.any { it.name == cardName } }
            .mapNotNull { it.firstOrNull()?.setName }
            .distinct()
            .sorted()

    // MARK: - Search

    fun searchCards(query: String): List<LorcanaCard> {
        if (query.isBlank() || !isDataLoaded) return emptyList()
        val normalizedQuery = normalizeSearchText(query)
        val filtered = cachedAllCards.filter { card ->
            val indexed = normalizedSearchIndex[card.id] ?: return@filter false
            indexed.contains(normalizedQuery) || isExactMatch(normalizedQuery, normalizeSearchText(card.name))
        }
        return filtered.sortedWith { a, b ->
            val nameA = normalizeSearchText(a.name)
            val nameB = normalizeSearchText(b.name)
            val exactA = isExactMatch(normalizedQuery, nameA)
            val exactB = isExactMatch(normalizedQuery, nameB)
            when {
                exactA && !exactB -> -1
                !exactA && exactB -> 1
                else -> nameA.compareTo(nameB)
            }
        }
    }

    fun searchCardGroups(query: String): List<CardGroup> = groupCards(searchCards(query))

    fun getAllCardGroups(): List<CardGroup> = if (isDataLoaded) groupCards(cachedAllCards) else emptyList()

    /** Groups printings by name + set; special printings group separately. */
    fun groupCards(cards: List<LorcanaCard>): List<CardGroup> {
        val grouped = LinkedHashMap<String, MutableList<LorcanaCard>>()
        for (card in cards) {
            val key = if (card.variant.isSpecialPrinting) {
                "${card.name}_${card.variant.rawValue}_${card.uniqueId ?: card.setName}"
            } else {
                "${card.name}_${card.setName}"
            }
            grouped.getOrPut(key) { mutableListOf() }.add(card)
        }
        return grouped.map { (key, groupCards) ->
            val first = groupCards.first()
            val suffix = if (first.variant.isSpecialPrinting) " (${first.variant.displayName})" else ""
            CardGroup(
                id = key.replace(" ", "_"),
                name = first.name + suffix,
                cards = groupCards.sortedWith(compareByDescending<LorcanaCard> { it.setName }.thenByDescending { it.uniqueId ?: "" }),
            )
        }.sortedBy { it.name }
    }

    fun normalizeSearchText(text: String): String =
        text.lowercase().replace("'", "").replace("-", " ").replace("  ", " ").trim()

    private fun isExactMatch(query: String, cardName: String): Boolean {
        val queryWords = query.split(" ").filter { it.isNotEmpty() }
        val nameWords = cardName.split(" ").filter { it.isNotEmpty() }
        return queryWords.all { q -> nameWords.any { it.startsWith(q) || it.contains(q) } }
    }

    /** Catalog row for a collected snapshot: same uniqueId + printing, else name + set. */
    fun catalogCard(card: LorcanaCard): LorcanaCard? {
        val lookupVariant = if (card.variant == CardVariant.FOIL) CardVariant.NORMAL else card.variant
        return cardsById[card.id]
            ?: cachedAllCards.firstOrNull { !card.uniqueId.isNullOrEmpty() && it.uniqueId == card.uniqueId && it.variant == lookupVariant }
            ?: cachedAllCards.firstOrNull { it.name == card.name && it.setName == card.setName }
    }
}
