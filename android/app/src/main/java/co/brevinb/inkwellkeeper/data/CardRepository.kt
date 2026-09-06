package co.brevinb.inkwellkeeper.data

import android.content.Context
import co.brevinb.inkwellkeeper.model.Card
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.CollectionEntry
import co.brevinb.inkwellkeeper.model.Deck
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader

class CardRepository(private val context: Context) {
    private val assetFiles = listOf(
        "the_first_chapter.json", "rise_of_the_floodborn.json", "into_the_inklands.json",
        "ursulas_return.json", "shimmering_skies.json", "azurite_sea.json",
        "archazias_island.json", "reign_of_jafar.json", "fabled.json",
        "whispers_in_the_well.json", "winterspell.json", "promo_set_1.json",
        "promo_set_2.json", "promo_set_3.json", "d23_collection.json",
        "challenge_promo.json", "epcot_festival_of_the_arts.json",
        "lorcana_challenge_year_3.json", "starter_decks.json", "wilds_unknown.json",
        "attack_of_the_vine.json"
    )

    private val setNumbers: Map<String, String> by lazy {
        runCatching {
            val root = context.assets.open("sets.json").use { input ->
                BufferedReader(InputStreamReader(input)).readText()
            }
            val sets = JSONObject(root).optJSONArray("sets") ?: JSONArray()
            buildMap {
                for (i in 0 until sets.length()) {
                    val set = sets.getJSONObject(i)
                    put(set.optString("setCode"), set.optString("setNumber"))
                }
            }
        }.getOrDefault(emptyMap())
    }

    fun loadCards(): List<Card> = assetFiles.flatMap { file ->
        runCatching {
            val text = context.assets.open(file).use { input ->
                BufferedReader(InputStreamReader(input)).readText()
            }
            val root = JSONObject(text)
            val setName = root.optString("setName")
            val setCode = root.optString("setCode")
            val cards = root.optJSONArray("cards") ?: JSONArray()
            (0 until cards.length()).mapNotNull { index -> parseCard(cards.getJSONObject(index), setName, setCode) }
        }.getOrDefault(emptyList())
    }.distinctBy { "${it.id}|${it.variant}" }

    private fun parseCard(json: JSONObject, fallbackSet: String, fallbackCode: String): Card? {
        val name = json.optString("name").takeIf { it.isNotBlank() } ?: return null
        val variant = runCatching { CardVariant.valueOf(json.optString("variant", "Normal").replace(" ", "")) }
            .getOrDefault(CardVariant.Normal)
        return Card(
            id = json.optString("id", "${fallbackCode}_${json.optInt("cardNumber")}_$name"),
            name = name,
            cost = json.optInt("cost"),
            type = json.optString("type"),
            rarity = json.optString("rarity", "Common"),
            setName = json.optString("setName", fallbackSet),
            setCode = fallbackCode,
            cardText = json.optString("cardText"),
            imageUrl = json.optString("imageUrl"),
            cardNumber = if (json.has("cardNumber") && !json.isNull("cardNumber")) json.optInt("cardNumber") else null,
            uniqueId = json.optString("uniqueId").takeIf { it.isNotBlank() },
            inkColor = json.optString("inkColor").takeIf { it.isNotBlank() },
            inkwell = json.optBoolean("inkwell", false),
            variant = variant,
            setNumber = setNumbers[fallbackCode]
        )
    }
}

class LocalStore(context: Context) {
    private val prefs = context.getSharedPreferences("inkwell_keeper", Context.MODE_PRIVATE)

    fun collections(): MutableMap<String, CollectionEntry> {
        val result = mutableMapOf<String, CollectionEntry>()
        val json = runCatching { JSONArray(prefs.getString("collection", "[]")) }.getOrNull() ?: JSONArray()
        for (i in 0 until json.length()) {
            val item = json.getJSONObject(i)
            val id = item.optString("cardId")
            if (id.isNotBlank()) result[id] = CollectionEntry(id, item.optInt("quantity", 1), item.optString("condition", "Near Mint"), item.optString("notes"), item.optBoolean("wishlisted"))
        }
        return result
    }

    fun saveCollections(entries: Map<String, CollectionEntry>) {
        val json = JSONArray()
        entries.values.filter { it.quantity > 0 || it.wishlisted }.forEach {
            json.put(JSONObject().apply {
                put("cardId", it.cardId); put("quantity", it.quantity); put("condition", it.condition)
                put("notes", it.notes); put("wishlisted", it.wishlisted)
            })
        }
        prefs.edit().putString("collection", json.toString()).apply()
    }

    fun decks(): MutableList<Deck> {
        val result = mutableListOf<Deck>()
        val json = runCatching { JSONArray(prefs.getString("decks", "[]")) }.getOrNull() ?: JSONArray()
        for (i in 0 until json.length()) {
            val item = json.getJSONObject(i)
            val quantities = mutableMapOf<String, Int>()
            val cards = item.optJSONObject("cards") ?: JSONObject()
            cards.keys().forEach { key -> quantities[key] = cards.optInt(key) }
            result += Deck(item.optString("id"), item.optString("name", "Untitled Deck"), item.optString("format", "Infinity Constructed"), quantities)
        }
        return result
    }

    fun saveDecks(decks: List<Deck>) {
        val json = JSONArray()
        decks.forEach { deck ->
            json.put(JSONObject().apply {
                put("id", deck.id); put("name", deck.name); put("format", deck.format)
                put("cards", JSONObject().apply { deck.cardQuantities.forEach { (id, quantity) -> put(id, quantity) } })
            })
        }
        prefs.edit().putString("decks", json.toString()).apply()
    }
}
