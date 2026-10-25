package co.brevinb.inkwellkeeper.ai

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.decks.DeckListTextCodec
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File
import java.time.LocalDate
import java.util.UUID

@Serializable
data class RulesMessage(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val isError: Boolean = false,
    val cardContext: String? = null,
    val attachedCards: List<AttachedCard>? = null,
) {
    @Serializable
    data class AttachedCard(val id: String, val name: String, val imageUrl: String = "")
}

@Serializable
data class SavedChat(
    val id: String,
    val title: String,
    val messages: List<RulesMessage>,
    val updatedAt: Long,
    val isPinned: Boolean = false,
)

/**
 * The AI Rules Assistant: same system prompt (bundled rules digest), model, temperature,
 * replay window, daily cap, and card-context format as iOS's RulesAssistantService.
 */
class RulesAssistant(private val context: Context) {
    val messages = mutableStateListOf<RulesMessage>()
    val savedChats = mutableStateListOf<SavedChat>()
    var streaming by mutableStateOf("")
        private set
    var isLoading by mutableStateOf(false)
        private set
    var lastSendFailed by mutableStateOf(false)
        private set
    var currentChatId: String? = null
        private set

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var job: Job? = null
    private val prefs = context.getSharedPreferences("rules_assistant", Context.MODE_PRIVATE)
    private val chatsFile = File(context.filesDir, "data/rules_chats.json")
    private val json = Json { ignoreUnknownKeys = true }
    private val systemInstructions by lazy { context.assets.open("rules_digest.txt").bufferedReader().use { it.readText() } }

    init {
        runCatching { savedChats.addAll(json.decodeFromString(ListSerializer(SavedChat.serializer()), chatsFile.readText())) }
        sortChats()
    }

    val remainingToday: Int
        get() {
            if (prefs.getString("day", null) != LocalDate.now().toString()) return DAILY_LIMIT
            return maxOf(0, DAILY_LIMIT - prefs.getInt("count", 0))
        }

    private fun consumeAllowance() {
        val today = LocalDate.now().toString()
        val count = if (prefs.getString("day", null) == today) prefs.getInt("count", 0) else 0
        prefs.edit().putString("day", today).putInt("count", count + 1).apply()
    }

    fun send(text: String, cards: List<LorcanaCard> = emptyList()) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || isLoading) return
        val attached = cards.ifEmpty { detectCards(trimmed) }
        messages += RulesMessage(
            content = trimmed,
            isUser = true,
            cardContext = attached.takeIf { it.isNotEmpty() }?.let(::buildCardContext),
            attachedCards = attached.map { RulesMessage.AttachedCard(it.id, it.name, it.imageUrl) }.ifEmpty { null },
        )
        startGeneration()
    }

    fun retryLast() {
        if (isLoading) return
        val lastUser = messages.indexOfLast { it.isUser }
        if (lastUser < 0) return
        while (messages.size > lastUser + 1) messages.removeAt(messages.size - 1)
        startGeneration()
    }

    fun stop() { job?.cancel() }

    private fun startGeneration() {
        if (remainingToday <= 0) {
            messages += RulesMessage(content = "You've reached today's limit of $DAILY_LIMIT questions. Please try again tomorrow.", isUser = false, isError = true)
            return
        }
        lastSendFailed = false
        isLoading = true
        streaming = ""
        job = scope.launch {
            val payload = listOf(ChatMessage("system", systemInstructions)) +
                messages.filter { !it.isError }.takeLast(MAX_REPLAYED).map { ChatMessage(if (it.isUser) "user" else "assistant", apiContent(it)) }
            var failure = "Sorry, I encountered an error. Please try again."
            try {
                OpenAIService.stream(payload, AIFeature.RULES).collect { streaming += it }
            } catch (_: kotlinx.coroutines.CancellationException) {
            } catch (e: OpenAIException) {
                if (e.userFacing) failure = e.message ?: failure
            } catch (_: Exception) {
            }
            if (streaming.isEmpty()) {
                if (job?.isCancelled != true) messages += RulesMessage(content = failure, isUser = false, isError = true)
                lastSendFailed = true
            } else {
                messages += RulesMessage(content = streaming, isUser = false)
                streaming = ""
                consumeAllowance()
                saveCurrentChat()
            }
            isLoading = false
        }
    }

    private fun apiContent(message: RulesMessage): String {
        val ctx = message.cardContext
        if (!message.isUser || ctx == null) return message.content
        return "$ctx\n\n[User's Question]\n${message.content}\n\nPlease answer using the exact card text provided above. Cite relevant rules sections."
    }

    // MARK: - Chats

    fun newChat() {
        if (messages.isNotEmpty()) saveCurrentChat()
        messages.clear()
        streaming = ""
        currentChatId = null
    }

    fun load(chat: SavedChat) {
        if (messages.isNotEmpty()) saveCurrentChat()
        messages.clear()
        messages.addAll(chat.messages)
        currentChatId = chat.id
    }

    fun delete(chat: SavedChat) {
        savedChats.removeAll { it.id == chat.id }
        if (currentChatId == chat.id) currentChatId = null
        persist()
    }

    fun togglePin(chat: SavedChat) {
        val i = savedChats.indexOfFirst { it.id == chat.id }
        if (i >= 0) savedChats[i] = chat.copy(isPinned = !chat.isPinned)
        sortChats(); persist()
    }

    private fun saveCurrentChat() {
        if (messages.isEmpty()) return
        val id = currentChatId ?: UUID.randomUUID().toString().also { currentChatId = it }
        val existing = savedChats.firstOrNull { it.id == id }
        val title = existing?.title ?: messages.firstOrNull { it.isUser }?.content?.let { if (it.length > 50) it.take(47) + "..." else it } ?: "New Chat"
        val chat = SavedChat(id, title, messages.toList(), System.currentTimeMillis(), existing?.isPinned ?: false)
        savedChats.removeAll { it.id == id }
        savedChats += chat
        sortChats(); persist()
    }

    private fun sortChats() {
        val sorted = savedChats.sortedWith(compareByDescending<SavedChat> { it.isPinned }.thenByDescending { it.updatedAt })
        savedChats.clear(); savedChats.addAll(sorted)
    }

    private fun persist() {
        val text = json.encodeToString(ListSerializer(SavedChat.serializer()), savedChats.toList())
        scope.launch(Dispatchers.IO) {
            chatsFile.parentFile?.mkdirs()
            val tmp = File(chatsFile.path + ".tmp")
            tmp.writeText(text)
            tmp.renameTo(chatsFile)
        }
    }

    companion object {
        const val DAILY_LIMIT = 50
        private const val MAX_REPLAYED = 16

        val suggestedQuestions = listOf(
            "When can I challenge an opponent's character?",
            "How does the Shift keyword work?",
            "What's the difference between Singer and Sing?",
            "How does Bodyguard work with multiple characters?",
            "When does 'drying' (summoning sickness) apply?",
            "How do triggered abilities resolve?",
        )

        private val keywordPrompts = listOf(
            "Shift" to "How does Shift timing work here?",
            "Singer" to "How does Singer interact with song costs?",
            "Sing Together" to "How does Sing Together add up?",
            "Bodyguard" to "How does Bodyguard affect challenges here?",
            "Ward" to "What can still affect this card through Ward?",
            "Evasive" to "Who can challenge this Evasive character?",
            "Challenger" to "When does the Challenger bonus apply?",
            "Resist" to "How does Resist reduce this damage?",
            "Rush" to "Can this character challenge the turn it's played?",
            "Reckless" to "What does Reckless force this character to do?",
            "Support" to "How does Support work when this character quests?",
            "Vanish" to "When exactly does Vanish trigger?",
        )

        /** Local follow-up chips (no API cost), keyed off keywords in the attached cards' text. */
        fun followUps(cards: List<RulesMessage.AttachedCard>): List<String> {
            val all = SetsDataManager.getAllCards()
            val text = cards.joinToString("\n") { a -> all.firstOrNull { it.id == a.id }?.cardText.orEmpty() }
            return keywordPrompts.filter { text.contains(it.first, ignoreCase = true) }.map { it.second }
                .ifEmpty { listOf("What are good combos with this card?", "How would an opponent play around it?") }.take(3)
        }

        fun cardDetails(card: LorcanaCard): String = buildList {
            add("Name: ${card.name}")
            add("Type: ${card.type}")
            add("Ink Cost: ${card.cost}")
            card.inkColor?.let { add("Ink Color: $it") }
            card.inkwell?.let { add("Inkable: ${if (it) "Yes" else "No"}") }
            card.strength?.let { add("Strength: $it") }
            card.willpower?.let { add("Willpower: $it") }
            card.lore?.let { add("Lore: $it") }
            if (card.cardText.isNotEmpty()) add("Card Text/Abilities: ${card.cardText}")
        }.joinToString("\n")

        fun buildCardContext(cards: List<LorcanaCard>): String {
            if (cards.size == 1) return "[Card Context - The user is asking about this specific card]\n${cardDetails(cards[0])}"
            val sections = cards.mapIndexed { i, c -> "[Card ${i + 1}]\n${cardDetails(c)}" }
            return "[Card Context - The user is asking about the following ${cards.size} cards and how they interact]\n${sections.joinToString("\n\n")}"
        }

        private fun matchable(text: String) = DeckListTextCodec.normalize(text).replace(" - ", " ")

        /** Full name + subtitle mentions only, to avoid false hits on "Belle" or "Stitch". */
        fun detectCards(text: String): List<LorcanaCard> {
            val haystack = matchable(text)
            val seen = HashSet<String>()
            val out = mutableListOf<LorcanaCard>()
            for (card in SetsDataManager.getAllCards()) {
                if (card.variant != CardVariant.NORMAL || !card.name.contains(" - ")) continue
                if (haystack.contains(matchable(card.name)) && seen.add(card.name)) {
                    out += card
                    if (out.size >= 4) break
                }
            }
            return out
        }

        /** Longest full-name mention, for the "Talking about…?" chip. */
        fun suggestion(text: String): LorcanaCard? {
            val haystack = matchable(text)
            if (haystack.isBlank()) return null
            return SetsDataManager.getAllCards().asSequence()
                .filter { it.variant == CardVariant.NORMAL && it.name.contains(" - ") }
                .map { it to matchable(it.name) }
                .filter { haystack.contains(it.second) }
                .maxByOrNull { it.second.length }?.first
        }
    }
}
