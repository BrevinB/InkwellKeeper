package co.brevinb.inkwellkeeper.ai

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.CollectionManager
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.decks.DeckManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.DeckArchetype
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import kotlin.math.abs

/**
 * AI deck building, completion, swaps, and strategy — a port of iOS AIDeckService with the
 * same prompts, catalog construction, fuzzy matching, and deterministic post-processing.
 */
class AIDeckService(context: Context) {
    var isLoading by mutableStateOf(false); private set
    var streaming by mutableStateOf(""); private set
    var suggestions by mutableStateOf<List<AIDeckSuggestion>>(emptyList())
    var swaps by mutableStateOf<List<AIDeckSwap>>(emptyList())
    var rawResponse by mutableStateOf(""); private set
    var errorMessage by mutableStateOf<String?>(null); private set
    var colorConstraintNote by mutableStateOf<String?>(null); private set
    var inksChosenByAI by mutableStateOf(false); private set
    var isRetry by mutableStateOf(false); private set
    var generation by mutableStateOf(0); private set

    var strategyLoading by mutableStateOf(false); private set
    var strategyStreaming by mutableStateOf(""); private set
    var strategyResponse by mutableStateOf(""); private set
    var strategyError by mutableStateOf<String?>(null); private set
    var strategyDeckId: String? = null; private set

    private val prefs = context.getSharedPreferences("ai_deck", Context.MODE_PRIVATE)
    private var collectionOnly = false
    private var owned: Map<String, Int> = emptyMap()
    private var maxInks = 2
    private var format = DeckFormat.CASUAL
    private var allowed: Set<String>? = null
    private var target = 60
    private var normalCards: List<LorcanaCard> = emptyList()
    private var existingEntries: List<AIDeckRules.Entry> = emptyList()
    private var existingQuantities: Map<String, Int> = emptyMap()

    val remainingToday: Int
        get() = if (prefs.getString("day", null) != LocalDate.now().toString()) DAILY_LIMIT else maxOf(0, DAILY_LIMIT - prefs.getInt("count", 0))

    private fun consumeAllowance() {
        val today = LocalDate.now().toString()
        val count = if (prefs.getString("day", null) == today) prefs.getInt("count", 0) else 0
        prefs.edit().putString("day", today).putInt("count", count + 1).apply()
    }

    private val limitMessage get() = "You've reached today's limit of $DAILY_LIMIT AI generations. Please try again tomorrow."

    private val previousLines get() = suggestions.mapNotNull { s -> s.matchedCard?.let { "${s.quantity}x ${it.name}" } }

    private fun retryNote(feedback: AIDeckFeedbackReason?, previous: List<String>): String {
        if (feedback == null) return ""
        var note = "\n\nPLAYER FEEDBACK ON THE PREVIOUS ATTEMPT: ${feedback.retryGuidance}\n"
        if (previous.isNotEmpty()) {
            note += "The rejected attempt was:\n" + previous.joinToString("\n") { "  $it" } + "\nMake clearly different choices where the feedback applies.\n"
        }
        return note
    }

    /** Shared guard for every generation entry point. */
    private fun preflight(fmt: DeckFormat, coconutMessage: String): Boolean {
        val error = when {
            !OpenAIService.isConfigured -> "Service not available. Please try again later."
            remainingToday <= 0 -> limitMessage
            fmt == DeckFormat.COCONUT -> coconutMessage
            else -> null
        }
        if (error != null) { errorMessage = error; isLoading = false }
        return error == null
    }

    // MARK: - Generate

    suspend fun generateDeck(
        description: String,
        format: DeckFormat,
        inkColors: List<InkColor>,
        archetype: DeckArchetype?,
        collectionOnly: Boolean = false,
        ownedQuantities: Map<String, Int> = emptyMap(),
        excludedInks: Set<InkColor> = emptySet(),
        feedback: AIDeckFeedbackReason? = null,
    ) {
        val previous = previousLines
        reset()
        isRetry = feedback != null
        inksChosenByAI = inkColors.isEmpty()
        maxInks = format.maxInkColors
        this.format = format
        allowed = inkColors.takeIf { it.isNotEmpty() }?.map { it.rawValue }?.toSet()
        isLoading = true
        if (!preflight(format, "AI deck building doesn't support the Coconut beta yet.")) return
        normalCards = releasedNormalCards()

        var prompt = "Create a 60-card Disney Lorcana deck with the following requirements:\n"
        prompt += "- Format: ${format.rawValue}\n"
        if (inkColors.isNotEmpty()) {
            prompt += "- Ink Colors: ${inkColors.joinToString(" / ") { it.rawValue }}\n"
        } else {
            prompt += "- Ink Colors: your choice — pick the inks (up to ${format.maxInkColors}) that best deliver the player's description\n"
            prompt += "- Decide your inks BEFORE writing anything else: the very first line of your response must be exactly \"[INKS] Color / Color\" (e.g. \"[INKS] Ruby / Steel\"), and every card must fit those inks\n"
            if (excludedInks.isNotEmpty()) prompt += "- Do NOT use these inks (the player wants to try something different): ${excludedInks.map { it.rawValue }.sorted().joinToString(", ")}\n"
        }
        archetype?.let { prompt += "- Archetype: ${it.rawValue}\n" }
        format.legalSets?.let { prompt += "- IMPORTANT: Only use cards from these legal sets: ${it.sorted().joinToString(", ")}\n" }
        prompt += "\nPlayer's description (THIS IS THE TOP PRIORITY — build the deck around this): $description"
        prompt += "\nREMINDER: Maximize the use of cards that match the player's description. Include ALL available cards that fit the theme before adding any non-themed cards."
        prompt += retryNote(feedback, previous)
        prompt += buildCatalog(format, inkColors, if (inkColors.isEmpty()) excludedInks else emptySet(), collectionOnly, ownedQuantities, description)
        streamCompletion(prompt, collectionOnly, ownedQuantities)
    }

    suspend fun completeDeck(
        existing: List<DeckCard>,
        format: DeckFormat,
        inkColors: List<InkColor>,
        archetype: DeckArchetype?,
        notes: String = "",
        collectionOnly: Boolean = false,
        ownedQuantities: Map<String, Int> = emptyMap(),
        feedback: AIDeckFeedbackReason? = null,
    ) {
        val previous = previousLines
        reset()
        isRetry = feedback != null
        maxInks = format.maxInkColors
        this.format = format
        isLoading = true
        if (!preflight(format, "AI completion doesn't support the Coconut beta yet.")) return
        val currentCount = existing.sumOf { it.quantity }
        val remaining = 60 - currentCount
        if (remaining <= 0) { errorMessage = "Deck already has $currentCount cards."; isLoading = false; return }
        target = remaining
        val colors = inkColors.ifEmpty { existing.flatMap { AIDeckRules.inks(it.inkColor) }.toSet().sorted().mapNotNull { InkColor.fromString(it) } }
        if (colors.isEmpty()) { errorMessage = "Add a few cards or set the deck's ink colors first, so suggestions match your deck."; isLoading = false; return }
        allowed = colors.map { it.rawValue }.toSet()
        setExisting(existing)
        normalCards = releasedNormalCards()

        val inkList = colors.joinToString(" / ") { it.rawValue }
        var prompt = "I have a partial Disney Lorcana deck and need help completing it.\n\n"
        prompt += "Format: ${format.rawValue}\n"
        prompt += "Ink Colors: $inkList\n"
        prompt += "IMPORTANT: Only suggest cards that match these ink colors ($inkList). Do NOT add cards from other colors.\n"
        if (notes.isNotBlank()) prompt += "Guidance from the user: ${notes.trim()}\n"
        prompt += retryNote(feedback, previous)
        archetype?.let { prompt += "Archetype: ${it.rawValue}\n" }
        prompt += "Current cards ($currentCount/60):\n"
        existing.sortedBy { it.cost }.forEach { prompt += "  ${it.quantity}x ${it.name} (${it.setName})\n" }
        prompt += "\nI need $remaining more cards to reach 60. "
        prompt += "Suggest ONLY the additional cards needed (totaling $remaining cards). "
        prompt += "Analyze the existing cards, identify the deck's strategy, and fill in gaps. "
        prompt += "Consider the cost curve, inkable ratio, and synergies with existing cards."
        format.legalSets?.let { prompt += "\nIMPORTANT: Only suggest cards from these legal sets: ${it.sorted().joinToString(", ")}." }
        prompt += buildCatalog(format, colors, emptySet(), collectionOnly, ownedQuantities, "")
        streamCompletion(prompt, collectionOnly, ownedQuantities)
    }

    suspend fun improveDeck(existing: List<DeckCard>, format: DeckFormat, inkColors: List<InkColor>, archetype: DeckArchetype?, notes: String = "", feedback: AIDeckFeedbackReason? = null) {
        val previous = swaps.map { "OUT ${it.removeQuantity}x ${it.removeName} / IN ${it.add.quantity}x ${it.add.cardName}" }
        reset()
        isRetry = feedback != null
        maxInks = format.maxInkColors
        isLoading = true
        if (!preflight(format, "AI improvements don't support the Coconut beta yet.")) return
        val colors = inkColors.ifEmpty { existing.flatMap { AIDeckRules.inks(it.inkColor) }.toSet().sorted().mapNotNull { InkColor.fromString(it) } }
        if (colors.isEmpty()) { errorMessage = "Set the deck's ink colors first, so suggestions match your deck."; isLoading = false; return }
        this.format = format
        allowed = colors.map { it.rawValue }.toSet()
        setExisting(existing)
        normalCards = releasedNormalCards()

        var prompt = "Here is my complete Disney Lorcana deck. Suggest 3 to 6 SWAPS to make it stronger.\n\n"
        prompt += "Format: ${format.rawValue}\n"
        prompt += "Ink Colors: ${colors.joinToString(" / ") { it.rawValue }}\n"
        archetype?.let { prompt += "Archetype: ${it.rawValue}\n" }
        if (notes.isNotBlank()) prompt += "Guidance from the user: ${notes.trim()}\n"
        prompt += retryNote(feedback, previous)
        prompt += "\nCurrent deck:\n"
        existing.sortedBy { it.cost }.forEach { prompt += "  ${it.quantity}x ${it.name} (Cost ${it.cost}, ${it.type})\n" }
        format.legalSets?.let { prompt += "\nIMPORTANT: Only suggest cards from these legal sets: ${it.sorted().joinToString(", ")}." }
        prompt += "\nRespond with a short explanation of the deck's weaknesses, then EXACTLY this format " +
            "(OUT lines name cards from the deck above; IN lines name cards from the AVAILABLE CARDS " +
            "list, same ink colors, NOT already in the deck, and each swap's quantities must match " +
            "so the deck stays at the same size):\n[SWAPS]\nOUT: 2x Card Name\nIN: 2x Replacement Card Name\nOUT: 1x Another Card\nIN: 1x Another Replacement\n[/SWAPS]"
        prompt += buildCatalog(format, colors, emptySet(), false, emptyMap(), "")

        if (!runStream(prompt, "Failed to generate improvements. Please try again.")) return
        if (rawResponse.isNotEmpty()) consumeAllowance()
        resolveSwaps(existing)
        isLoading = false
    }

    private suspend fun resolveSwaps(existing: List<DeckCard>) {
        val parsed = AIDeckRules.parseSwaps(rawResponse)
        if (parsed.isEmpty()) { errorMessage = errorMessage ?: "The AI didn't return usable swaps. Please try again."; return }
        val cards = normalCards
        val matched = withContext(Dispatchers.Default) { AIDeckRules.matchSuggestions(parsed.map { AIDeckSuggestion(cardName = it.inName, quantity = it.inQuantity) }, cards) }
        val deckByName = existing.associateBy { DeckFormat.normalizeCardName(it.name) }
        val removable = deckByName.mapValues { it.value.quantity }.toMutableMap()
        val added = HashSet<String>()
        val result = mutableListOf<AIDeckSwap>()
        parsed.forEachIndexed { i, pair ->
            val outKey = DeckFormat.normalizeCardName(pair.outName)
            val deckCard = deckByName[outKey] ?: return@forEachIndexed
            if (pair.outQuantity <= 0 || (removable[outKey] ?: 0) < pair.outQuantity) return@forEachIndexed
            val inCard = matched[i].matchedCard?.let { legalPrinting(it) } ?: return@forEachIndexed
            val inKey = DeckFormat.normalizeCardName(inCard.name)
            if (inKey in deckByName || inKey in added || pair.outQuantity > format.maxCopiesPerCard) return@forEachIndexed
            removable[outKey] = (removable[outKey] ?: 0) - pair.outQuantity
            added += inKey
            result += AIDeckSwap(removeName = deckCard.name, removeQuantity = pair.outQuantity, add = AIDeckSuggestion(matched[i].id, inCard.name, pair.outQuantity, inCard))
        }
        swaps = result
        if (result.isEmpty() && errorMessage == null) errorMessage = "The suggested swaps didn't match your deck. Please try again."
    }

    fun applySwaps(deck: Deck, decks: DeckManager) {
        for (swap in swaps.filter { it.isAccepted }) {
            val inCard = swap.add.matchedCard ?: continue
            deck.cards.firstOrNull { DeckFormat.normalizeCardName(it.name) == DeckFormat.normalizeCardName(swap.removeName) }?.let {
                decks.updateCardQuantity(it, deck, it.quantity - swap.removeQuantity)
            }
            decks.addCard(inCard, deck, swap.add.quantity)
        }
    }

    fun toggleSwap(id: String) { swaps = swaps.map { if (it.id == id) it.copy(isAccepted = !it.isAccepted) else it } }

    // MARK: - Strategy

    suspend fun generateStrategy(deck: Deck) {
        strategyResponse = ""; strategyStreaming = ""; strategyError = null; strategyLoading = true
        strategyDeckId = deck.id
        try {
            when {
                !OpenAIService.isConfigured -> { strategyError = "Service not available. Please try again later."; return }
                remainingToday <= 0 -> { strategyError = limitMessage; return }
            }
            var prompt = "Analyze this Disney Lorcana deck and provide a detailed strategy guide.\n\n"
            prompt += "Deck: ${deck.name}\nFormat: ${deck.deckFormat.rawValue}\n"
            prompt += "Ink Colors: ${deck.deckInkColors.joinToString(" / ") { it.rawValue }}\n"
            deck.deckArchetype?.let { prompt += "Archetype: ${it.rawValue}\n" }
            prompt += "\nDeck List (${deck.totalCards} cards):\n"
            deck.cards.sortedBy { it.cost }.forEach { prompt += "  ${it.quantity}x ${it.name} (Cost ${it.cost}, ${it.type}, ${it.inkColor ?: "Unknown"})\n" }
            try {
                OpenAIService.stream(listOf(ChatMessage("system", STRATEGY_PROMPT), ChatMessage("user", prompt)), AIFeature.DECK).collect { strategyStreaming += it }
            } catch (e: kotlinx.coroutines.CancellationException) {
                throw e
            } catch (e: Exception) {
                if (strategyStreaming.isEmpty()) strategyError = (e as? OpenAIException)?.takeIf { it.userFacing }?.message ?: "Failed to generate strategy. Please try again."
            }
            strategyResponse = strategyStreaming
            strategyStreaming = ""
            if (strategyResponse.isNotEmpty()) consumeAllowance()
        } finally {
            strategyLoading = false
        }
    }

    // MARK: - Streaming & post-processing

    private suspend fun runStream(prompt: String, failure: String): Boolean {
        try {
            OpenAIService.stream(listOf(ChatMessage("system", SYSTEM_PROMPT), ChatMessage("user", prompt)), AIFeature.DECK).collect { streaming += it }
        } catch (e: kotlinx.coroutines.CancellationException) {
            isLoading = false
            throw e
        } catch (e: Exception) {
            if (streaming.isEmpty()) { errorMessage = (e as? OpenAIException)?.takeIf { it.userFacing }?.message ?: failure; isLoading = false; return false }
        }
        rawResponse = streaming
        streaming = ""
        return true
    }

    private suspend fun streamCompletion(prompt: String, collectionOnly: Boolean, owned: Map<String, Int>) {
        this.collectionOnly = collectionOnly
        this.owned = owned
        if (!runStream(prompt, "Failed to generate deck. Please try again.")) return
        suggestions = AIDeckRules.parseSuggestions(rawResponse)
        if (rawResponse.isNotEmpty()) consumeAllowance()
        if (allowed == null) AIDeckRules.declaredInks(rawResponse, maxInks)?.let { allowed = it }
        postProcess()
        isLoading = false
    }

    private suspend fun postProcess() {
        if (suggestions.isEmpty()) return
        val snapshot = suggestions
        val cards = normalCards
        suggestions = withContext(Dispatchers.Default) { AIDeckRules.matchSuggestions(snapshot, cards) }
        preferLegalPrintings()
        enforceLegality()
        enforceColorConstraint()
        autoFixUnmatched()
        enforceLegality()
        enforceCopyLimit()
        enforceOwnedQuantities()
        enforceCostCurve()
        normalizeToTarget()
    }

    private fun releasedNormalCards(): List<LorcanaCard> {
        val upcoming = SetsDataManager.upcomingSetNames()
        return SetsDataManager.getAllCards().filter { it.variant == CardVariant.NORMAL && it.setName !in upcoming }
    }

    private fun isLegal(card: LorcanaCard): Boolean {
        format.legalSets?.let { if (card.setName !in it) return false }
        if (format.isBanned(card.name)) return false
        allowed?.let { if (!AIDeckRules.fits(card.inkColor, it)) return false }
        return true
    }

    private fun legalPrinting(card: LorcanaCard): LorcanaCard? {
        if (isLegal(card)) return card
        val name = DeckFormat.normalizeCardName(card.name)
        return normalCards.firstOrNull { DeckFormat.normalizeCardName(it.name) == name && isLegal(it) }
    }

    private fun preferLegalPrintings() {
        suggestions = suggestions.map { s -> s.matchedCard?.let { legalPrinting(it) }?.takeIf { it.id != s.matchedCard.id }?.let { s.copy(matchedCard = it) } ?: s }
    }

    private fun ownedOf(card: LorcanaCard) = owned[CollectionManager.cardKey(card.name, card.setName)]

    private fun allowance(card: LorcanaCard): Int {
        var a = format.maxCopiesPerCard - (existingQuantities[DeckFormat.normalizeCardName(card.name)] ?: 0)
        if (collectionOnly && owned.isNotEmpty()) a = minOf(a, ownedOf(card) ?: a)
        return maxOf(0, a)
    }

    private fun setExisting(cards: List<DeckCard>) {
        existingEntries = cards.map { AIDeckRules.Entry(it) }
        existingQuantities = cards.groupingBy { DeckFormat.normalizeCardName(it.name) }.fold(0) { acc, c -> acc + c.quantity }
    }

    private fun enforceLegality() { suggestions = suggestions.filter { s -> s.matchedCard?.let(::isLegal) ?: true } }

    private fun enforceCopyLimit() {
        suggestions = AIDeckRules.mergeDuplicates(suggestions).mapNotNull { s ->
            val card = s.matchedCard ?: return@mapNotNull s
            val a = allowance(card)
            if (a <= 0) null else if (s.quantity > a) s.withQuantity(a) else s
        }
    }

    private fun enforceColorConstraint() {
        val counts = HashMap<String, Int>()
        suggestions.forEach { s -> s.matchedCard?.let { c -> AIDeckRules.inks(c.inkColor).forEach { counts[it] = (counts[it] ?: 0) + s.quantity } } }
        if (counts.size <= maxInks) return
        val text = strategyText.lowercase()
        val mentioned = InkColor.entries.map { it.rawValue }.filter { counts[it] != null && text.contains(it.lowercase()) }
        val intended = if (mentioned.isNotEmpty() && mentioned.size <= maxInks) mentioned.toSet()
        else counts.entries.sortedByDescending { it.value }.take(maxInks).map { it.key }.toSet()
        val removed = counts.keys - intended
        suggestions = suggestions.filter { s -> s.matchedCard?.let { AIDeckRules.fits(it.inkColor, intended) } ?: true }
        colorConstraintNote = "Deck trimmed to $maxInks ink colors (${intended.sorted().joinToString(" & ")}). Removed cards from: ${removed.sorted().joinToString(", ")}."
    }

    private val replacementColors: Set<String>
        get() = allowed ?: suggestions.flatMap { AIDeckRules.inks(it.matchedCard?.inkColor) }.toSet()

    private fun pool(used: Set<String>, requireAllowance: Boolean): List<LorcanaCard> {
        val colors = replacementColors
        var p = normalCards.filter { AIDeckRules.fits(it.inkColor, colors) && it.name !in used && isLegal(it) && (!requireAllowance || allowance(it) > 0) }
        if (collectionOnly && owned.isNotEmpty()) p = p.filter { ownedOf(it) != null }
        return p
    }

    private fun autoFixUnmatched() {
        val unmatched = suggestions.indices.filter { suggestions[it].matchedCard == null }
        if (unmatched.isEmpty() || replacementColors.isEmpty()) return
        val used = suggestions.mapNotNull { it.matchedCard?.name }.toMutableSet()
        val p = pool(used, requireAllowance = true)
        if (p.isEmpty()) return
        val byCost = p.groupBy { it.cost }
        val list = suggestions.toMutableList()
        for (i in unmatched) {
            val candidates = byCost[3] ?: byCost[4] ?: byCost[2] ?: p.take(20)
            val replacement = candidates.firstOrNull { it.name !in used } ?: continue
            used += replacement.name
            list[i] = AIDeckSuggestion(cardName = replacement.name, quantity = minOf(list[i].quantity, allowance(replacement)), matchedCard = replacement)
        }
        suggestions = list
    }

    private fun enforceOwnedQuantities() {
        if (!collectionOnly || owned.isEmpty()) return
        suggestions = suggestions.map { s ->
            val c = s.matchedCard ?: return@map s
            val have = ownedOf(c) ?: 0
            if (s.quantity > have) s.withQuantity(maxOf(have, 1)) else s
        }.filter { s -> s.matchedCard?.let { (ownedOf(it) ?: 0) > 0 } ?: true }
    }

    private fun costMax(cost: Int) = when { cost >= 8 -> 2; cost >= 6 -> 3; else -> 4 }

    private fun enforceCostCurve() {
        val list = suggestions.map { s -> s.matchedCard?.let { c -> if (s.quantity > costMax(c.cost)) s.withQuantity(costMax(c.cost)) else s } ?: s }.toMutableList()
        val brackets = listOf(6..6 to 6, 7..7 to 4, 8..8 to 3, 9..99 to 2)
        for ((range, max) in brackets) {
            val idx = list.indices.filter { list[it].matchedCard?.cost?.let { c -> c in range } == true }.sortedByDescending { list[it].quantity }
            var total = idx.sumOf { list[it].quantity }
            for (i in idx.reversed()) {
                if (total <= max) break
                val reduction = minOf(list[i].quantity - 1, total - max)
                if (reduction > 0) { list[i] = list[i].withQuantity(list[i].quantity - reduction); total -= reduction }
            }
        }
        suggestions = list
    }

    private fun normalizeToTarget() {
        val list = suggestions.toMutableList()
        val total = list.sumOf { it.quantity }
        if (total == target) return
        if (total > target) {
            var excess = total - target
            val order = list.indices.sortedWith(compareByDescending<Int> { list[it].matchedCard?.cost ?: 0 }.thenByDescending { list[it].quantity })
            for (i in order) {
                if (excess <= 0) break
                val r = minOf(list[i].quantity - 1, excess)
                if (r > 0) { list[i] = list[i].withQuantity(list[i].quantity - r); excess -= r }
            }
            while (excess > 0 && list.isNotEmpty()) {
                val last = list.last()
                if (last.quantity <= excess) { excess -= last.quantity; list.removeAt(list.size - 1) }
                else { list[list.size - 1] = last.withQuantity(last.quantity - excess); excess = 0 }
            }
        } else {
            var deficit = target - total
            for (i in list.indices) {
                if (deficit <= 0) break
                val c = list[i].matchedCard ?: continue
                val inc = minOf(minOf(costMax(c.cost), allowance(c)) - list[i].quantity, deficit)
                if (inc > 0) { list[i] = list[i].withQuantity(list[i].quantity + inc); deficit -= inc }
            }
            if (deficit > 0) {
                val used = list.mapNotNull { it.matchedCard?.name }.toMutableSet()
                val p = pool(used, requireAllowance = false).sortedWith(compareBy({ if (it.inkwell == true) 0 else 1 }, { abs(it.cost - 3) }, { it.name }))
                for (c in p) {
                    if (deficit <= 0) break
                    val q = minOf(allowance(c), deficit)
                    if (q > 0) { list += AIDeckSuggestion(cardName = c.name, quantity = q, matchedCard = c); used += c.name; deficit -= q }
                }
            }
        }
        suggestions = list
    }

    // MARK: - Catalog

    private fun buildCatalog(format: DeckFormat, inkColors: List<InkColor>, excluded: Set<InkColor>, collectionOnly: Boolean, owned: Map<String, Int>, description: String): String {
        val legal = format.legalSets ?: normalCards.map { it.setName }.toSet()
        var cards = normalCards.filter { it.setName in legal && !format.isBanned(it.name) }.sortedBy { it.name }.distinctBy { it.name }
        if (excluded.isNotEmpty()) {
            val ex = excluded.map { it.rawValue }.toSet()
            cards = cards.filter { AIDeckRules.inks(it.inkColor).intersect(ex).isEmpty() }
        }
        if (collectionOnly && owned.isNotEmpty()) cards = cards.filter { owned[CollectionManager.cardKey(it.name, it.setName)] != null }
        val keywords = themeKeywords(description)
        val ownedNote = if (collectionOnly && owned.isNotEmpty()) "IMPORTANT: The number before each card is how many copies the player OWNS. You MUST NOT suggest more copies than the player owns. For example, if a card shows \"1x\", you can only use 1 copy in the deck.\n" else ""
        fun list(cs: List<LorcanaCard>) = formatCards(cs, collectionOnly, owned)

        if (inkColors.isNotEmpty()) {
            val names = inkColors.map { it.rawValue }.toSet()
            cards = capPerColor(cards.filter { AIDeckRules.fits(it.inkColor, names) }, CATALOG_PER_COLOR)
            if (cards.isEmpty()) return ""
            var catalog = "\n\nCRITICAL: ONLY use card names from the list below. Copy each name EXACTLY as written — do not modify, shorten, or invent names. Every card in your [DECKLIST] MUST appear in this list.\n$ownedNote"
            if (keywords.isNotEmpty()) {
                val (themed, other) = partitionByTheme(cards, keywords)
                if (themed.isNotEmpty()) {
                    catalog += "\n★★★ PRIORITY CHARACTERS (Use these for ALL character slots — pick the ones matching your ink colors) ★★★\n" + list(themed)
                    catalog += "\nOTHER AVAILABLE CARDS (use Items, Actions, Songs, and Locations from here to build a competitive support package):\n" + list(other)
                    return catalog
                }
            }
            return catalog + "AVAILABLE CARDS:\n" + list(cards)
        }
        if (cards.isEmpty()) return ""
        val max = format.maxInkColors
        var catalog = "\n\nCRITICAL RULE: You MUST choose UP TO $max ink color sections below and use cards ONLY from those sections. Every single card in your [DECKLIST] must come from your chosen colors (no more than $max). Do NOT use cards from any other color section.\nCopy each card name EXACTLY as written — do not modify, shorten, or invent names. Every card in your [DECKLIST] MUST appear in this list.\n$ownedNote"
        if (keywords.isNotEmpty()) {
            val (themed, _) = partitionByTheme(cards, keywords)
            if (themed.isNotEmpty()) {
                val themedColors = themed.mapNotNull { it.inkColor }.toSet().sorted()
                catalog += "\nThe player wants cards matching their theme. These themed cards are in: ${themedColors.joinToString(", ")}. Choose up to $max colors that include the MOST themed cards.\n"
                catalog += "\n★★★ PRIORITY CHARACTERS (Use these for ALL character slots — pick the ones matching your chosen ink colors) ★★★\n" + list(themed) + "\n"
            }
        }
        catalog += "\nCHOOSE UP TO $max COLORS AND USE ONLY THOSE:\n"
        capPerColor(cards, CATALOG_PER_COLOR).groupBy { it.inkColor ?: "Unknown" }.toSortedMap().forEach { (color, cs) ->
            catalog += "\n=== ${color.uppercase()} ===\n" + list(cs.sortedBy { it.name })
        }
        return catalog
    }

    private fun capPerColor(cards: List<LorcanaCard>, limit: Int): List<LorcanaCard> =
        cards.groupBy { it.inkColor ?: "Unknown" }.values.flatMap { cs ->
            if (cs.size <= limit) cs else {
                val sorted = cs.sortedWith(compareBy({ it.cost }, { it.name }))
                val stride = sorted.size.toDouble() / limit
                (0 until limit).map { sorted[(it * stride).toInt()] }
            }
        }

    private fun formatCards(cards: List<LorcanaCard>, collectionOnly: Boolean, owned: Map<String, Int>): String = buildString {
        for (c in cards.sortedBy { it.name }) {
            val details = mutableListOf(c.type, "Cost ${c.cost}", if (c.inkwell == true) "Inkable" else "Uninkable")
            if (AIDeckRules.inks(c.inkColor).size > 1) c.inkColor?.let { details += it }
            val info = "[${details.joinToString(", ")}]"
            val qty = if (collectionOnly) owned[CollectionManager.cardKey(c.name, c.setName)] else null
            append(if (qty != null) "- ${qty}x ${c.name} $info\n" else "- ${c.name} $info\n")
        }
    }

    private fun themeKeywords(description: String): List<String> {
        if (description.isBlank()) return emptyList()
        val lower = description.lowercase()
        val out = HashSet<String>()
        FRANCHISES.forEach { (trigger, chars) -> if (lower.contains(trigger)) out += chars }
        lower.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.length >= 3 && it !in STOP_WORDS }.forEach { out += it }
        return out.toList()
    }

    private fun partitionByTheme(cards: List<LorcanaCard>, keywords: List<String>): Pair<List<LorcanaCard>, List<LorcanaCard>> =
        cards.sortedBy { it.name }.partition { c -> val character = c.name.lowercase().substringBefore(" - "); keywords.any { character.contains(it) } }

    /** Strategy prose before the decklist, minus the [INKS] line and any "Part 2" header. */
    val strategyText: String
        get() {
            val idx = rawResponse.indexOf("[DECKLIST]").takeIf { it >= 0 } ?: return ""
            var text = rawResponse.substring(0, idx).replaceFirst(Regex("\\[INKS\\][^\\n]*"), "")
            Regex("(?i)\\n*\\**\\s*part\\s*2[^\\n]*").find(text)?.let { text = text.substring(0, it.range.first) }
            return text.trim()
        }

    val declaredInkColors: List<InkColor>
        get() {
            val inks = suggestions.flatMap { AIDeckRules.inks(it.matchedCard?.inkColor) }.toSet()
            return InkColor.entries.filter { it.rawValue in inks }
        }

    val resultFormat: DeckFormat get() = format
    val matchedCount get() = suggestions.count { it.matchedCard != null }
    val unmatchedCount get() = suggestions.count { it.matchedCard == null }

    val ruleReport: AIDeckRuleReport?
        get() {
            if (isLoading || matchedCount == 0) return null
            val suggested = suggestions.mapNotNull { s -> s.matchedCard?.let { AIDeckRules.Entry(it, s.quantity) } }
            return AIDeckRules.audit(existingEntries + suggested, format, allowed, existingEntries.sumOf { it.quantity } + target)
        }

    fun replace(id: String, card: LorcanaCard, quantity: Int) { suggestions = suggestions.map { if (it.id == id) AIDeckSuggestion(cardName = card.name, quantity = quantity, matchedCard = card) else it } }
    fun remove(id: String) { suggestions = suggestions.filterNot { it.id == id } }
    fun add(card: LorcanaCard, quantity: Int) { suggestions = suggestions + AIDeckSuggestion(cardName = card.name, quantity = quantity, matchedCard = card) }

    fun applySuggestions(deck: Deck, decks: DeckManager) {
        suggestions.forEach { s -> s.matchedCard?.let { decks.addCard(it, deck, s.quantity) } }
    }

    fun reset() {
        suggestions = emptyList(); swaps = emptyList(); rawResponse = ""; streaming = ""
        errorMessage = null; colorConstraintNote = null; isLoading = false
        collectionOnly = false; owned = emptyMap(); maxInks = 2; format = DeckFormat.CASUAL; allowed = null
        target = 60; existingEntries = emptyList(); existingQuantities = emptyMap()
        generation++; isRetry = false; inksChosenByAI = false
    }

    companion object {
        const val DAILY_LIMIT = 25
        private const val CATALOG_PER_COLOR = 130

        private val STOP_WORDS = setOf(
            "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "from", "by", "is", "it", "my", "me", "i", "we", "you",
            "make", "build", "create", "use", "using", "only", "just", "want",
            "deck", "card", "cards", "character", "characters", "movie", "film",
            "all", "every", "each", "some", "any", "that", "this", "these", "those",
            "new", "good", "best", "fun", "cool", "like", "based", "themed", "theme",
            "around", "about", "please", "can", "could", "would", "should",
            "disney", "lorcana", "groove", "tale", "tales", "story", "competitive",
            "centered", "center",
        )

        private val FRANCHISES: Map<String, List<String>> = mapOf(
            "lilo" to listOf("lilo", "stitch", "nani", "jumba", "pleakley", "gantu", "david", "cobra bubbles", "angel", "reuben", "hamsterviel"),
            "stitch" to listOf("lilo", "stitch", "nani", "jumba", "pleakley", "gantu", "david", "cobra bubbles", "angel", "reuben", "hamsterviel"),
            "emperor" to listOf("kuzco", "yzma", "kronk", "pacha", "kuzco's palace"),
            "kuzco" to listOf("kuzco", "yzma", "kronk", "pacha", "kuzco's palace"),
            "frozen" to listOf("elsa", "anna", "olaf", "kristoff", "sven", "hans", "marshmallow", "mattias"),
            "moana" to listOf("moana", "maui", "tamatoa", "te ka", "te fiti", "hei hei", "sina", "tui", "gramma tala"),
            "tangled" to listOf("rapunzel", "flynn rider", "pascal", "maximus", "mother gothel", "cassandra"),
            "aladdin" to listOf("aladdin", "jasmine", "genie", "jafar", "abu", "iago", "carpet", "rajah"),
            "lion king" to listOf("simba", "nala", "mufasa", "scar", "timon", "pumbaa", "rafiki", "zazu", "sarabi", "shenzi", "banzai"),
            "little mermaid" to listOf("ariel", "ursula", "flounder", "sebastian", "eric", "triton", "scuttle"),
            "mermaid" to listOf("ariel", "ursula", "flounder", "sebastian", "eric", "triton", "scuttle"),
            "beauty" to listOf("belle", "beast", "gaston", "lumiere", "cogsworth", "mrs. potts", "chip", "lefou", "maurice"),
            "beast" to listOf("belle", "beast", "gaston", "lumiere", "cogsworth", "mrs. potts", "chip", "lefou", "maurice"),
            "hercules" to listOf("hercules", "meg", "megara", "hades", "phil", "pegasus", "pain", "panic", "zeus"),
            "mulan" to listOf("mulan", "mushu", "shang", "shan yu", "li shang"),
            "cinderella" to listOf("cinderella", "prince charming", "fairy godmother", "lady tremaine", "anastasia", "drizella", "lucifer", "jaq", "gus"),
            "snow white" to listOf("snow white", "evil queen", "grumpy", "doc", "dopey", "bashful", "sleepy", "sneezy", "happy", "magic mirror"),
            "sleeping beauty" to listOf("aurora", "maleficent", "prince phillip", "flora", "fauna", "merryweather"),
            "peter pan" to listOf("peter pan", "tinker bell", "captain hook", "wendy", "john", "michael", "smee", "tick-tock", "tiger lily"),
            "101 dalmatians" to listOf("pongo", "perdita", "cruella", "cruella de vil", "horace", "jasper"),
            "dalmatians" to listOf("pongo", "perdita", "cruella", "cruella de vil", "horace", "jasper"),
            "jungle book" to listOf("mowgli", "baloo", "bagheera", "shere khan", "king louie", "kaa"),
            "pocahontas" to listOf("pocahontas", "john smith", "meeko", "flit", "percy", "ratcliffe"),
            "treasure planet" to listOf("jim hawkins", "john silver", "captain amelia", "b.e.n.", "morph", "doppler"),
            "pirates" to listOf("jack sparrow", "captain hook", "davy jones", "elizabeth swann", "will turner", "barbossa", "tia dalma"),
            "robin hood" to listOf("robin hood", "maid marian", "little john", "prince john", "friar tuck", "sir hiss"),
            "incredibles" to listOf("mr. incredible", "elastigirl", "violet", "dash", "jack-jack", "syndrome", "frozone", "edna"),
            "encanto" to listOf("mirabel", "luisa", "isabela", "bruno", "abuela"),
            "zootopia" to listOf("judy hopps", "nick wilde", "chief bogo", "flash", "bellwether", "gazelle"),
            "wreck" to listOf("wreck-it ralph", "ralph", "vanellope", "fix-it felix", "calhoun"),
            "ralph" to listOf("wreck-it ralph", "ralph", "vanellope", "fix-it felix", "calhoun"),
            "ratatouille" to listOf("remy", "linguini", "colette", "gusteau", "skinner"),
            "monsters" to listOf("sulley", "mike", "boo", "randall", "roz", "celia"),
            "toy story" to listOf("woody", "buzz lightyear", "jessie", "rex", "hamm", "slinky", "lotso", "bo peep"),
            "cars" to listOf("lightning mcqueen", "mater", "sally", "doc hudson"),
            "finding nemo" to listOf("nemo", "marlin", "dory", "gill", "crush", "bruce"),
            "nemo" to listOf("nemo", "marlin", "dory", "gill", "crush", "bruce"),
            "princess" to listOf("ariel", "belle", "cinderella", "aurora", "rapunzel", "moana", "jasmine", "mulan", "tiana", "snow white", "elsa", "anna", "pocahontas", "merida"),
            "villain" to listOf("maleficent", "ursula", "jafar", "scar", "hades", "cruella", "gaston", "evil queen", "captain hook", "yzma", "shan yu", "mother gothel", "hans", "dr. facilier", "lady tremaine"),
            "gargoyles" to listOf("goliath", "demona", "david xanatos", "elisa", "brooklyn", "broadway", "lexington", "hudson", "angela"),
            "atlantis" to listOf("milo", "kida", "rourke", "helga", "vinny", "audrey"),
            "big hero" to listOf("hiro", "baymax", "honey lemon", "gogo", "wasabi", "fred", "yokai"),
            "baymax" to listOf("hiro", "baymax", "honey lemon", "gogo", "wasabi", "fred", "yokai"),
        )

        private const val SYSTEM_PROMPT = """You are a Disney Lorcana TCG deck building expert. You help players create competitive and fun decks.

IMPORTANT RULES:
- A deck must contain exactly 60 cards
- Use only the ink colors specified in the request. The allowed number of ink colors is given per request — never exceed it.
- Maximum 4 copies of any card (by full name, e.g., "Elsa - Snow Queen"). Reprints in different sets share the limit, so list each card only once.
- Dual-ink cards (listed like "[Character, Cost 3, Inkable, Ruby-Steel]") count as BOTH inks and are only legal when the deck plays both.
- Only inkable cards can go into the inkwell. Each card in the list is marked Inkable or Uninkable.
- Most competitive decks run about 70-80% inkable cards (roughly 42-48 of 60). Never go below 60% inkable.
- Cost curve matters: most cards at cost 1-5, only a handful at 6+

DECK FORMATS:
- Casual: All sets are legal; up to 2 ink colors.
- Core Constructed: Rotating format — only the legal sets listed in the request may be used; up to 2 ink colors.
- Infinity Constructed: All sets are legal; up to 6 ink colors (the two-ink limit is removed).
- Triple Deck: Each deck uses 2 ink colors.

RESPONSE FORMAT:
You MUST respond in two parts:

PART 1 - Strategy overview (2-3 paragraphs explaining the deck strategy, key synergies, and how to play it)

PART 2 - Deck list in EXACTLY this format (one card per line):
[DECKLIST]
4x Card Full Name (Set Name)
3x Another Card - Subtitle (Set Name)
...
[/DECKLIST]

CRITICAL CARD NAME RULES:
- You will be given a list of AVAILABLE CARDS. You MUST copy card names EXACTLY, character-for-character, from that list.
- Do NOT paraphrase, shorten, reword, or invent card names. If a card is listed as "Elsa - Snow Queen" you must write exactly "Elsa - Snow Queen", not "Elsa - The Snow Queen" or "Elsa - Ice Queen".
- Do NOT combine a character's first name with a subtitle from a different card. Each "Name - Subtitle" pair is a unique card.
- If you are unsure whether a card exists, do NOT include it. Only use cards you can see in the provided list.
- When completing a partial deck, analyze what's already there and fill gaps in the strategy. Cards already in the deck count toward the 4-copy limit (a card with 3 copies can take at most 1 more).

CRITICAL 60-CARD REQUIREMENT:
- The deck list MUST add up to EXACTLY 60 cards total. Not 59, not 61 — exactly 60.
- After writing your decklist, add up all the quantities (the numbers before the "x"). The sum MUST equal 60.
- A typical 60-card deck has about 15 unique cards at 4 copies each (15 × 4 = 60). Adjust quantities to hit exactly 60.
- Double-check your math before finishing. Count the total: if it's not 60, adjust quantities until it is.

THEME & DESCRIPTION PRIORITY:
- The player's description is the MOST IMPORTANT input. Honor the theme above competitiveness.
- If the card list has a "★★★ PRIORITY CHARACTERS" section, use those for ALL character slots in the deck.
- Pick the best priority characters that fit the chosen ink colors. You do NOT need to use every single priority character — only include ones that match your chosen ink colors and make strategic sense.
- Use 3-4 copies of low/mid cost priority characters (cost 1-5), and 2-3 copies of expensive ones (cost 6+).
- Aim for about 25-30 characters total from the priority list.
- Fill the remaining 30-35 slots with the BEST non-character cards (Items, Actions, Songs, Locations) from the OTHER AVAILABLE CARDS list. Choose cards that are competitively strong and synergize with your characters.
- Build a real, competitive deck — the theme applies to characters, but support cards should be the strongest available options."""

        private const val STRATEGY_PROMPT = """You are a Disney Lorcana TCG strategy expert. You analyze decks and provide detailed play guides.

When given a deck list, provide a thorough strategy guide covering:
1. **Deck Overview** — What the deck is trying to do and its win condition
2. **Key Cards & Combos** — The most important cards and how they work together
3. **Mulligan Guide** — What to look for in your opening hand and what to send back
4. **Early Game (Turns 1-3)** — What to prioritize in the opening turns, which cards to ink
5. **Mid Game (Turns 4-6)** — How to transition and build your board
6. **Late Game (Turn 7+)** — How to close out the game
7. **Cards to Ink** — Which cards are best to put in the inkwell and which to always play
8. **Weaknesses & Tips** — What the deck struggles against and how to play around it

Use markdown formatting with bold headers. Be specific — reference actual card names from the deck."""
    }
}
