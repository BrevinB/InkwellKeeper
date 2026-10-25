package co.brevinb.inkwellkeeper.stats

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.CollectedCard
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.pricing.PricingService.PortfolioPricePoint
import java.time.LocalDate
import kotlin.math.abs

data class PortfolioHolding(val cardKey: String, val quantity: Int, val name: String, val isFoil: Boolean, val fallbackPrice: Double?)
data class PortfolioPoint(val date: LocalDate, val value: Double)
data class PortfolioSummary(val currentValue: Double, val change: Double, val percentChange: Double?)
data class PortfolioMover(val cardKey: String, val name: String, val isFoil: Boolean, val quantity: Int, val change: Double, val currentValue: Double, val percentChange: Double?) {
    val isGain: Boolean get() = change > 0
}
data class PortfolioExtreme(val cardKey: String, val name: String, val isFoil: Boolean, val isHigh: Boolean, val price: Double, val windowHigh: Double, val windowLow: Double)
data class PortfolioVariantSplit(val foilValue: Double = 0.0, val normalValue: Double = 0.0, val foilCopies: Int = 0, val normalCopies: Int = 0)
data class CostBasisSummary(val costBasis: Double = 0.0, val marketValue: Double = 0.0, val recordedCopies: Int = 0, val unrecordedCopies: Int = 0) {
    val gain: Double get() = marketValue - costBasis
    val percentGain: Double? get() = if (costBasis > 0) gain / costBasis * 100 else null
    val hasRecordedCost: Boolean get() = recordedCopies > 0
    val isPartial: Boolean get() = unrecordedCopies > 0
}
data class CostBasisEntry(val cardKey: String, val name: String, val isFoil: Boolean, val quantity: Int, val costBasis: Double, val marketValue: Double) {
    val gain: Double get() = marketValue - costBasis
}

/** Pure portfolio math, ported from the iOS builders. */
object PortfolioMath {
    const val MAX_OBSERVATION_GAP_DAYS = 14

    fun dailyValues(holdings: List<PortfolioHolding>, series: Map<String, List<PortfolioPricePoint>>): List<PortfolioPoint> {
        val priced = holdings.filter { it.quantity > 0 && !series[it.cardKey].isNullOrEmpty() }
        if (priced.isEmpty()) return emptyList()
        val unseriesed = holdings.sumOf { h ->
            if (series[h.cardKey].isNullOrEmpty() && (h.fallbackPrice ?: 0.0) > 0) h.fallbackPrice!! * h.quantity else 0.0
        }
        val allDays = priced.flatMap { h -> series[h.cardKey].orEmpty().map { it.day } }
        val first = windowStart(allDays) ?: return emptyList()
        val last = allDays.maxOrNull() ?: return emptyList()
        val cursors = IntArray(priced.size)
        return (first..last).map { day ->
            var total = unseriesed
            priced.forEachIndexed { index, h ->
                val s = series[h.cardKey].orEmpty()
                var c = cursors[index]
                while (c + 1 < s.size && s[c + 1].day <= day) c++
                cursors[index] = c
                total += s[c].price * h.quantity
            }
            PortfolioPoint(LocalDate.ofEpochDay(day.toLong()), total)
        }
    }

    /** Starts the chart after the last long gap in observations so it doesn't draw flat fiction. */
    fun windowStart(days: List<Int>, maxGap: Int = MAX_OBSERVATION_GAP_DAYS): Int? {
        val sorted = days.toSortedSet().toList()
        var start = sorted.firstOrNull() ?: return null
        for (i in 0 until sorted.size - 1) if (sorted[i + 1] - sorted[i] > maxGap) start = sorted[i + 1]
        return start
    }

    fun summary(points: List<PortfolioPoint>): PortfolioSummary? {
        val first = points.firstOrNull() ?: return null
        val last = points.last()
        val change = last.value - first.value
        return PortfolioSummary(last.value, change, if (first.value > 0) change / first.value * 100 else null)
    }

    fun change(points: List<PortfolioPoint>, trailing: Int): Double? {
        if (points.size < 2) return null
        return points.last().value - points[maxOf(0, points.size - 1 - trailing)].value
    }

    private fun price(series: List<PortfolioPricePoint>, onOrBefore: Int): Double? {
        val first = series.firstOrNull() ?: return null
        if (onOrBefore < first.day) return first.price
        var result = first.price
        for (p in series) {
            if (p.day > onOrBefore) break
            result = p.price
        }
        return result
    }

    fun movers(holdings: List<PortfolioHolding>, series: Map<String, List<PortfolioPricePoint>>, trailing: Int): List<PortfolioMover> {
        val lastDay = series.values.mapNotNull { it.lastOrNull()?.day }.maxOrNull() ?: return emptyList()
        return holdings.mapNotNull { h ->
            val s = series[h.cardKey] ?: return@mapNotNull null
            if (h.quantity <= 0) return@mapNotNull null
            val current = price(s, lastDay) ?: return@mapNotNull null
            val opening = price(s, lastDay - trailing) ?: return@mapNotNull null
            if (current == opening) return@mapNotNull null
            PortfolioMover(h.cardKey, h.name, h.isFoil, h.quantity, (current - opening) * h.quantity, current * h.quantity, if (opening > 0) (current - opening) / opening * 100 else null)
        }.sortedByDescending { abs(it.change) }
    }

    fun extremes(holdings: List<PortfolioHolding>, series: Map<String, List<PortfolioPricePoint>>): List<PortfolioExtreme> =
        holdings.mapNotNull { h ->
            val s = series[h.cardKey] ?: return@mapNotNull null
            if (h.quantity <= 0 || s.size < 8) return@mapNotNull null
            val current = s.last().price
            if (current < 0.25) return@mapNotNull null
            val high = s.maxOf { it.price }
            val low = s.minOf { it.price }
            if (low <= 0 || high < low * 1.15) return@mapNotNull null
            val isHigh = when {
                current >= high - 0.005 -> true
                current <= low + 0.005 -> false
                else -> return@mapNotNull null
            }
            PortfolioExtreme(h.cardKey, h.name, h.isFoil, isHigh, current, high, low)
        }.sortedByDescending { it.price }

    fun variantSplit(holdings: List<PortfolioHolding>, series: Map<String, List<PortfolioPricePoint>>): PortfolioVariantSplit {
        var split = PortfolioVariantSplit()
        for (h in holdings) {
            if (h.quantity <= 0) continue
            val current = series[h.cardKey]?.lastOrNull()?.price ?: continue
            split = if (h.isFoil) split.copy(foilValue = split.foilValue + current * h.quantity, foilCopies = split.foilCopies + h.quantity)
            else split.copy(normalValue = split.normalValue + current * h.quantity, normalCopies = split.normalCopies + h.quantity)
        }
        return split
    }

    /** Copies without a purchase price are counted separately, never assumed free. */
    fun costBasis(cards: List<CollectedCard>, price: (String, Double?) -> Double?): Pair<CostBasisSummary, List<CostBasisEntry>> {
        var summary = CostBasisSummary()
        val merged = LinkedHashMap<String, CostBasisEntry>()
        for (card in cards) {
            val quantity = maxOf(0, card.quantity)
            if (quantity == 0) continue
            val lorcana = card.toLorcanaCard()
            val key = lorcana.variantAwareId
            val paid = card.purchasePrice
            if (paid == null) {
                summary = summary.copy(unrecordedCopies = summary.unrecordedCopies + quantity)
                continue
            }
            val current = price(key, card.price) ?: paid
            summary = summary.copy(
                costBasis = summary.costBasis + paid * quantity,
                marketValue = summary.marketValue + current * quantity,
                recordedCopies = summary.recordedCopies + quantity,
            )
            val existing = merged[key]
            merged[key] = CostBasisEntry(key, lorcana.name, lorcana.variant != CardVariant.NORMAL, (existing?.quantity ?: 0) + quantity,
                (existing?.costBasis ?: 0.0) + paid * quantity, (existing?.marketValue ?: 0.0) + current * quantity)
        }
        return summary to merged.values.sortedByDescending { abs(it.gain) }
    }
}

/** Loads the collection's price history once per visit and derives every portfolio card. */
class PortfolioHistoryModel {
    var points by mutableStateOf<List<PortfolioPoint>>(emptyList())
        private set
    var summary by mutableStateOf<PortfolioSummary?>(null)
        private set
    var movers by mutableStateOf<List<PortfolioMover>>(emptyList())
        private set
    var extremes by mutableStateOf<List<PortfolioExtreme>>(emptyList())
        private set
    var variantSplit by mutableStateOf(PortfolioVariantSplit())
        private set
    var costBasis by mutableStateOf(CostBasisSummary())
        private set
    var costBasisEntries by mutableStateOf<List<CostBasisEntry>>(emptyList())
        private set
    var livePrices by mutableStateOf<Map<String, Double>>(emptyMap())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var hasLoadedOnce by mutableStateOf(false)
        private set
    private var lastSignature: Int? = null

    val weeklyChange: Double? get() = PortfolioMath.change(points, MOVER_DAYS)

    suspend fun load(cards: List<CollectedCard>, force: Boolean = false) {
        if (isLoading) return
        val historyInUsd = AppSettings.preferredCurrency == "USD"
        val grouped = cards.groupBy { it.toLorcanaCard().variantAwareId }
        val holdings = grouped.map { (key, rows) ->
            val first = rows.first().toLorcanaCard()
            PortfolioHolding(key, rows.sumOf { maxOf(1, it.quantity) }, first.name, first.variant != CardVariant.NORMAL,
                if (historyInUsd) rows.firstNotNullOfOrNull { r -> r.price?.takeIf { it > 0 } } else null)
        }
        val signature = holdings.sortedBy { it.cardKey }.map { it.cardKey to it.quantity }.hashCode()
        if (!force && signature == lastSignature && hasLoadedOnce) return
        isLoading = true
        val printings = grouped.values.map { it.first().toLorcanaCard() }
        val series = PricingService.fetchBulkHistory(printings, WINDOW_DAYS)
        points = PortfolioMath.dailyValues(holdings, series)
        summary = PortfolioMath.summary(points)
        movers = PortfolioMath.movers(holdings, series, MOVER_DAYS)
        extremes = PortfolioMath.extremes(holdings, series)
        variantSplit = PortfolioMath.variantSplit(holdings, series)
        livePrices = if (historyInUsd) series.mapNotNull { (k, v) -> v.lastOrNull()?.let { k to it.price } }.toMap() else emptyMap()
        val (basis, entries) = PortfolioMath.costBasis(cards) { key, stored -> series[key]?.lastOrNull()?.price ?: stored }
        costBasis = basis
        costBasisEntries = entries
        if (series.isNotEmpty()) lastSignature = signature
        hasLoadedOnce = true
        isLoading = false
    }

    companion object {
        const val WINDOW_DAYS = 180
        const val MOVER_DAYS = 7
    }
}
