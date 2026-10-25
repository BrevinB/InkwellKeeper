package co.brevinb.inkwellkeeper.ui.navigation

import android.net.Uri
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.navigation.NavHostController
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.serialization.json.Json

/** How a card detail screen was opened, which decides its actions (iOS has three detail views). */
enum class CardDetailMode { COLLECTION, WISHLIST, CATALOG, SET }

object Routes {
    const val COLLECTION = "collection"
    const val SCAN = "scan"
    const val DECKS = "decks"
    const val STATS = "stats"
    const val MORE = "more"
    const val BOOKSHELF = "bookshelf"
    const val SETS = "sets"
    const val TRADES = "trades"
    const val PLAY = "play"
    const val WISHLIST = "wishlist"
    const val SETTINGS = "settings"
    const val SUPPORT = "support"
    const val RULES = "rules"
    const val SEARCH = "search?wishlist={wishlist}"
    const val CARD = "card?data={data}&mode={mode}"
    const val SET_DETAIL = "set/{name}"
    const val DECK = "deck/{id}"
    const val IMPORT = "import"
    const val EXPORT = "export"
    const val CONTAINER = "container/{id}"
    const val AI_DECK_BUILDER = "aiDeckBuilder"
    const val STARTER_DECKS = "starterDecks"
    const val IMPORT_DECK = "importDeck"
    const val WHATS_NEW = "whatsNew"
    const val GLOSSARY = "glossary"
    const val PRICING_INFO = "pricingInfo"
    const val PAYWALL = "paywall?source={source}"

    private val json = Json { ignoreUnknownKeys = true }

    fun search(wishlist: Boolean = false) = "search?wishlist=$wishlist"
    fun card(card: LorcanaCard, mode: CardDetailMode) =
        "card?data=${Uri.encode(json.encodeToString(LorcanaCard.serializer(), card))}&mode=${mode.name}"
    fun decodeCard(data: String?): LorcanaCard? =
        data?.let { runCatching { json.decodeFromString(LorcanaCard.serializer(), it) }.getOrNull() }
    fun set(name: String) = "set/${Uri.encode(name)}"
    fun deck(id: String) = "deck/$id"
    fun container(id: String) = "container/$id"
    /** [source] picks what the paywall leads with (see PaywallContext). */
    fun paywall(source: String) = "paywall?source=$source"
}

val LocalNav = staticCompositionLocalOf<NavHostController> { error("NavController not provided") }

fun NavHostController.openCard(card: LorcanaCard, mode: CardDetailMode) = navigate(Routes.card(card, mode))
