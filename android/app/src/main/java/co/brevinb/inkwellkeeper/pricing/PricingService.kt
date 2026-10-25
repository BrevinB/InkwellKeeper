package co.brevinb.inkwellkeeper.pricing

import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

/**
 * Real market prices from the Inkwell Keeper pricing backend (the same AWS API the iOS app
 * uses). Never substitutes an estimate: null always means "price unavailable".
 */
object PricingService {
    private const val BASE_URL = "https://29kwvipys3.execute-api.us-east-2.amazonaws.com"
    private const val CACHE_MILLIS = 60 * 60 * 1000L

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val jsonMedia = "application/json".toMediaType()

    enum class CardCondition(val rawValue: String, val shortName: String) {
        NEAR_MINT("Near Mint", "NM"),
        LIGHTLY_PLAYED("Lightly Played", "LP"),
        MODERATELY_PLAYED("Moderately Played", "MP"),
        HEAVILY_PLAYED("Heavily Played", "HP"),
        DAMAGED("Damaged", "DMG"),
        GRADED("Graded", "GRADED");

        companion object {
            fun fromRaw(raw: String?): CardCondition? = entries.firstOrNull { it.rawValue == raw }
        }
    }

    enum class PriceConfidence(val label: String, val description: String) {
        HIGH("High", "Based on multiple recent sales"),
        MEDIUM("Medium", "Based on marketplace data"),
        LOW("Low", "Based on limited sales data"),
    }

    data class PriceData(
        val price: Double,
        val condition: CardCondition,
        val currency: String,
        val marketplace: String,
        val confidence: Double?,
    )

    data class CardPricing(val cardName: String, val prices: List<PriceData>, val lastUpdated: Long)

    data class PricePoint(val date: LocalDate, val price: Double)

    /** One daily value for a printing; `day` counts days since 1970-01-01 UTC. */
    @Serializable
    data class PortfolioPricePoint(val day: Int, val price: Double)

    private data class Cached(val pricing: CardPricing, val cachedAt: Long)

    private val pricingCache = ConcurrentHashMap<String, Cached>()

    val preferredCurrency: String get() = AppSettings.preferredCurrency

    fun formatPrice(value: Double): String {
        val symbol = if (preferredCurrency == "EUR") "€" else "$"
        return symbol + String.format(Locale.US, "%.2f", value)
    }

    // MARK: - Row selection

    /**
     * Rows that price this card's printing. The backend returns separate normal and foil rows
     * under one unique id; averaging across both misprices every card with a foil market.
     */
    fun pricesMatching(variant: CardVariant, prices: List<PriceData>): List<PriceData> {
        val foilRows = prices.filter { it.marketplace.contains("foil", ignoreCase = true) }
        return if (variant == CardVariant.NORMAL) {
            val normalRows = prices.filter { !it.marketplace.contains("foil", ignoreCase = true) }
            normalRows.ifEmpty { prices }
        } else {
            // Foils and special printings (which only exist foiled) prefer the foil market.
            foilRows.ifEmpty { prices }
        }
    }

    /** Market rows for this printing, excluding lowest-listing rows that drag averages down. */
    fun marketRows(variant: CardVariant, prices: List<PriceData>): List<PriceData> {
        val rows = pricesMatching(variant, prices).filter { !it.marketplace.contains("low", ignoreCase = true) }
        return rows.ifEmpty { pricesMatching(variant, prices) }
    }

    fun lowestListing(variant: CardVariant, prices: List<PriceData>): Double? =
        pricesMatching(variant, prices).filter { it.marketplace.contains("low", ignoreCase = true) }.minOfOrNull { it.price }

    private fun relevantPrices(card: LorcanaCard, pricing: CardPricing, condition: CardCondition): List<PriceData> {
        val variantPrices = marketRows(card.variant, pricing.prices)
        val preferred = preferredCurrency
        val preferredCondition = variantPrices.filter { it.currency == preferred && it.condition == condition }
        if (preferredCondition.isNotEmpty()) return preferredCondition
        val conditionPrices = variantPrices.filter { it.condition == condition }
        if (conditionPrices.isNotEmpty()) return conditionPrices
        val preferredAll = variantPrices.filter { it.currency == preferred }
        return preferredAll.ifEmpty { variantPrices }
    }

    // MARK: - Single card

    suspend fun getPricing(card: LorcanaCard, condition: CardCondition = CardCondition.NEAR_MINT): CardPricing? {
        val cacheKey = "${card.id}_${condition.rawValue}"
        pricingCache[cacheKey]?.let { cached ->
            if (System.currentTimeMillis() - cached.cachedAt < CACHE_MILLIS) return cached.pricing
        }
        val pricing = runCatching { fetchInkwellPricing(card, condition) }.getOrNull() ?: return null
        pricingCache[cacheKey] = Cached(pricing, System.currentTimeMillis())
        return pricing
    }

    suspend fun getMarketPrice(card: LorcanaCard, condition: CardCondition = CardCondition.NEAR_MINT): Double? {
        val pricing = getPricing(card, condition) ?: return null
        if (pricing.prices.isEmpty()) return null
        val relevant = relevantPrices(card, pricing, condition)
        if (relevant.isEmpty()) return null
        return relevant.sumOf { it.price } / relevant.size
    }

    suspend fun getPriceWithConfidence(
        card: LorcanaCard,
        condition: CardCondition = CardCondition.NEAR_MINT,
    ): Pair<Double, PriceConfidence>? {
        val price = getMarketPrice(card, condition) ?: return null
        return Pair(price, PriceConfidence.HIGH)
    }

    suspend fun getLowPrice(card: LorcanaCard, condition: CardCondition = CardCondition.NEAR_MINT): Double? {
        val pricing = getPricing(card, condition) ?: return null
        return lowestListing(card.variant, pricing.prices)
    }

    private suspend fun fetchInkwellPricing(card: LorcanaCard, condition: CardCondition): CardPricing? =
        withContext(Dispatchers.IO) {
            val uniqueId = buildUniqueId(card)
            val request = Request.Builder().url("$BASE_URL/prices/$uniqueId").get().build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@withContext null
                val body = response.body?.string() ?: return@withContext null
                val decoded = json.decodeFromString(InkwellPriceResponse.serializer(), body)
                val prices = decoded.prices.flatMap { row ->
                    val rowCondition = CardCondition.fromRaw(row.condition) ?: condition
                    buildList {
                        row.priceUsd?.let { add(PriceData(it, rowCondition, "USD", row.marketplace, row.confidence)) }
                        row.priceEur?.let { add(PriceData(it, rowCondition, "EUR", row.marketplace, row.confidence)) }
                    }
                }
                if (prices.isEmpty()) null else CardPricing(card.name, prices, System.currentTimeMillis())
            }
        }

    // MARK: - History

    /**
     * Daily price points for this card's printing. Rows for the other printing are filtered
     * out and same-day rows collapse to the latest.
     */
    suspend fun fetchPriceHistory(card: LorcanaCard, days: Int = 90): List<PricePoint> = withContext(Dispatchers.IO) {
        runCatching {
            val request = Request.Builder().url("$BASE_URL/prices/${buildUniqueId(card)}/history?days=$days").build()
            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) return@use emptyList()
                val decoded = json.decodeFromString(HistoryResponse.serializer(), response.body?.string().orEmpty())
                val wantFoil = card.variant != CardVariant.NORMAL
                val marketPoints = decoded.points.filter { !it.marketplace.contains("low", ignoreCase = true) }
                val rows = marketPoints.filter { wantFoil == it.marketplace.contains("foil", ignoreCase = true) }
                    .ifEmpty { marketPoints }
                val byDay = sortedMapOf<LocalDate, PricePoint>()
                for (point in rows) {
                    val price = point.priceUsd ?: continue
                    val instant = runCatching { Instant.parse(point.recordedAt) }.getOrNull() ?: continue
                    val day = instant.atZone(ZoneId.systemDefault()).toLocalDate()
                    byDay[day] = PricePoint(day, price)
                }
                byDay.values.toList()
            }
        }.getOrDefault(emptyList())
    }

    /**
     * Daily value series for many printings at once, keyed by each card's `variantAwareId`.
     * The backend compresses each printing to one point per changed day.
     */
    suspend fun fetchBulkHistory(cards: List<LorcanaCard>, days: Int = 180): Map<String, List<PortfolioPricePoint>> {
        if (cards.isEmpty()) return emptyMap()
        val printings = cards.associateBy { it.variantAwareId }.values.toList()
        return coroutineScope {
            printings.chunked(200).map { chunk -> async(Dispatchers.IO) { fetchHistoryChunk(chunk, days) } }
                .awaitAll()
                .fold(mutableMapOf()) { acc, map -> map.forEach { (k, v) -> acc.putIfAbsent(k, v) }; acc }
        }
    }

    /** Current market price per printing (last point of a short history), keyed by `variantAwareId`. */
    suspend fun fetchBulkMarketPrices(cards: List<LorcanaCard>): Map<String, Double> =
        fetchBulkHistory(cards, days = 7).mapNotNull { (key, points) -> points.lastOrNull()?.let { key to it.price } }.toMap()

    private fun fetchHistoryChunk(cards: List<LorcanaCard>, days: Int): Map<String, List<PortfolioPricePoint>> = runCatching {
        val keyByResponseKey = mutableMapOf<String, String>()
        val body = buildJsonObject {
            put("days", days)
            put("cards", buildJsonArray {
                for (card in cards) {
                    val uniqueId = buildUniqueId(card)
                    val foil = card.variant != CardVariant.NORMAL
                    keyByResponseKey[if (foil) "$uniqueId|foil" else uniqueId] = card.variantAwareId
                    add(buildJsonObject { put("unique_id", uniqueId); put("foil", foil) })
                }
            })
        }
        val request = Request.Builder()
            .url("$BASE_URL/prices/history/bulk")
            .post(body.toString().toRequestBody(jsonMedia))
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) return@use emptyMap()
            val root = json.parseToJsonElement(response.body?.string().orEmpty()).jsonObject
            val series = root["series"] as? JsonObject ?: return@use emptyMap()
            buildMap {
                for ((responseKey, raw) in series) {
                    val cardKey = keyByResponseKey[responseKey] ?: continue
                    val points = (raw as? JsonArray)?.mapNotNull { pair ->
                        val values = pair.jsonArray
                        if (values.size != 2) return@mapNotNull null
                        val day = values[0].jsonPrimitive.doubleOrNull?.toInt() ?: return@mapNotNull null
                        val price = values[1].jsonPrimitive.doubleOrNull ?: return@mapNotNull null
                        PortfolioPricePoint(day, price)
                    }.orEmpty()
                    if (points.isNotEmpty()) put(cardKey, points.sortedBy { it.day })
                }
            }
        }
    }.getOrDefault(emptyMap())

    /** Backend `best_price_usd` for many cards, keyed by card id. Good for filters, not valuations. */
    suspend fun fetchBulkPrices(cards: List<LorcanaCard>): Map<String, Double> = withContext(Dispatchers.IO) {
        if (cards.isEmpty()) return@withContext emptyMap()
        val pairs = cards.map { it.id to buildUniqueId(it) }
        val priceByUniqueId = mutableMapOf<String, Double>()
        for (chunk in pairs.map { it.second }.distinct().chunked(400)) {
            runCatching {
                val body = buildJsonObject { put("unique_ids", JsonArray(chunk.map { kotlinx.serialization.json.JsonPrimitive(it) })) }
                val request = Request.Builder().url("$BASE_URL/prices/bulk")
                    .post(body.toString().toRequestBody(jsonMedia)).build()
                client.newCall(request).execute().use { response ->
                    if (!response.isSuccessful) return@use
                    val decoded = json.decodeFromString(BulkPriceResponse.serializer(), response.body?.string().orEmpty())
                    decoded.prices.forEach { item -> item.bestPriceUsd?.let { priceByUniqueId[item.uniqueId] = it } }
                }
            }
        }
        pairs.mapNotNull { (cardId, uniqueId) -> priceByUniqueId[uniqueId]?.let { cardId to it } }.toMap()
    }

    fun clearCache() = pricingCache.clear()

    // MARK: - Ids

    private val setCodeMap = mapOf(
        "The First Chapter" to "TFC",
        "Rise of the Floodborn" to "ROF",
        "Into the Inklands" to "ITI",
        "Ursula's Return" to "URR",
        "Shimmering Skies" to "SSK",
        "Azurite Sea" to "AZS",
        "Archazia's Island" to "ARI",
        "Reign of Jafar" to "ROJ",
        "Fabled" to "FAB",
        "Whispers in the Well" to "WIW",
        "Winterspell" to "WIN",
        "Promo Set 1" to "P1",
        "Promo Set 2" to "P2",
        "Promo Set 3" to "P3",
        "Challenge Promo" to "CP",
        "D23 Collection" to "D23",
        "EPCOT Festival of the Arts" to "EFA",
        "Lorcana Challenge Year 3" to "C2",
        "Wilds Unknown" to "WU",
        "Promo Set PD1" to "PD1",
        "Hyperia City" to "HYC",
        "Promo Set 4" to "P4",
        "Curator's Collection: Heroines Edition" to "CC1",
        "Attack of the Vine!" to "AOV",
    )

    private fun setCode(setName: String): String = setCodeMap[setName] ?: setName.take(3).uppercase()

    /** Backend id format, e.g. "TFC-1". */
    fun buildUniqueId(card: LorcanaCard): String {
        val code = setCode(card.setName)
        card.cardNumber?.let { return "$code-$it" }
        val existing = card.uniqueId
        if (!existing.isNullOrEmpty()) {
            val parts = existing.split("-", limit = 2)
            val number = parts.getOrNull(1)?.toIntOrNull()
            return if (parts.size == 2 && number != null) "${parts[0]}-$number" else existing
        }
        val idParts = card.id.split("_")
        idParts.getOrNull(1)?.toIntOrNull()?.let { return "$code-$it" }
        return "$code-${card.id}"
    }

    @Serializable
    private data class InkwellPriceResponse(
        @SerialName("unique_id") val uniqueId: String = "",
        @SerialName("card_name") val cardName: String = "",
        @SerialName("best_price_usd") val bestPriceUsd: Double? = null,
        val prices: List<InkwellPrice> = emptyList(),
    )

    @Serializable
    private data class InkwellPrice(
        val source: String = "",
        @SerialName("price_usd") val priceUsd: Double? = null,
        @SerialName("price_eur") val priceEur: Double? = null,
        val marketplace: String = "",
        val condition: String = "",
        val confidence: Double? = null,
    )

    @Serializable
    private data class HistoryResponse(val points: List<Point> = emptyList()) {
        @Serializable
        data class Point(
            @SerialName("recorded_at") val recordedAt: String,
            @SerialName("price_usd") val priceUsd: Double? = null,
            val marketplace: String = "",
        )
    }

    @Serializable
    private data class BulkPriceResponse(val prices: List<Item> = emptyList()) {
        @Serializable
        data class Item(
            @SerialName("unique_id") val uniqueId: String,
            @SerialName("best_price_usd") val bestPriceUsd: Double? = null,
        )
    }
}
