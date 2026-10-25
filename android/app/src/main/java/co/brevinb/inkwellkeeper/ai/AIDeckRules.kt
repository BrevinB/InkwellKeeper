package co.brevinb.inkwellkeeper.ai

import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.decks.FormatLegality
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.LorcanaCard
import java.util.UUID

/** One AI-suggested card line; [matchedCard] is null when the name didn't resolve. */
data class AIDeckSuggestion(
    val id: String = UUID.randomUUID().toString(),
    val cardName: String,
    val quantity: Int,
    val matchedCard: LorcanaCard? = null,
) {
    fun withQuantity(q: Int) = copy(quantity = q)
}

/** One suggested improvement to a full deck: cut copies of one card, add another. */
data class AIDeckSwap(
    val id: String = UUID.randomUUID().toString(),
    val removeName: String,
    val removeQuantity: Int,
    val add: AIDeckSuggestion,
    val isAccepted: Boolean = true,
)

data class AIDeckRuleReport(val violations: List<String>, val warnings: List<String>, val totalCards: Int, val inkableCards: Int) {
    val isLegal: Boolean get() = violations.isEmpty()
}

enum class AIDeckFeedbackReason(val title: String, val retryGuidance: String) {
    BROKE_RULES("Broke deck rules", "It broke deck-building rules. Re-check every rule: 60 cards total, at most 4 copies of each card name, only the allowed inks (dual-ink cards need both) and legal sets."),
    OFF_THEME("Didn't match my idea", "It didn't match what the player asked for. Follow the player's description and theme much more closely."),
    WEAK_CARDS("Weak card choices", "The card choices were weak. Use stronger, proven competitive cards and tighter synergies."),
    BAD_CURVE("Bad cost curve", "The cost curve was bad. Put most cards at cost 1-5 with a solid 2-3 cost core, only a few 6+ cards, and keep at least 70% inkable."),
    OTHER("Something else", "The player wasn't happy with it. Try a noticeably different approach."),
}

/**
 * Deterministic deck-construction checks for AI output (port of iOS AIDeckRules): the model is
 * prompted to follow the rules, but these decide which cards may enter a list and audit it.
 */
object AIDeckRules {
    data class Entry(val name: String, val quantity: Int, val setName: String, val inkColor: String?, val isInkable: Boolean) {
        constructor(card: LorcanaCard, quantity: Int) : this(card.name, quantity, card.setName, card.inkColor, card.inkwell ?: false)
        constructor(deckCard: DeckCard) : this(deckCard.name, deckCard.quantity, deckCard.setName, deckCard.inkColor, deckCard.inkwell)
    }

    private const val MIN_INKABLE_RATIO = 0.6

    fun inks(inkColor: String?): Set<String> {
        if (inkColor == null) return emptySet()
        return inkColor.split('-', ',', '/').mapNotNull { InkColor.fromString(it.trim())?.rawValue }.toSet()
    }

    fun fits(inkColor: String?, allowed: Set<String>): Boolean {
        val card = inks(inkColor)
        return card.isNotEmpty() && allowed.containsAll(card)
    }

    fun declaredInks(response: String, limit: Int): Set<String>? {
        val start = response.indexOf("[INKS]")
        if (start < 0) return null
        val line = response.substring(start + 6).substringBefore('\n')
        val inks = line.split(Regex("[^A-Za-z]+")).mapNotNull { InkColor.fromString(it)?.rawValue }.toSet()
        return inks.takeIf { it.isNotEmpty() && it.size <= limit }
    }

    fun mergeDuplicates(suggestions: List<AIDeckSuggestion>): List<AIDeckSuggestion> {
        val result = mutableListOf<AIDeckSuggestion>()
        val indexByName = HashMap<String, Int>()
        for (s in suggestions) {
            val card = s.matchedCard
            if (card == null) { result += s; continue }
            val key = DeckFormat.normalizeCardName(card.name)
            val i = indexByName[key]
            if (i != null) result[i] = result[i].withQuantity(result[i].quantity + s.quantity)
            else { indexByName[key] = result.size; result += s }
        }
        return result
    }

    fun audit(entries: List<Entry>, format: DeckFormat, allowed: Set<String>?, targetTotal: Int): AIDeckRuleReport {
        val violations = mutableListOf<String>()
        val warnings = mutableListOf<String>()
        val total = entries.sumOf { it.quantity }
        if (total < format.minimumCards) violations += "$total of ${format.minimumCards} cards — add ${format.minimumCards - total} more."
        else if (total > targetTotal) warnings += "$total cards — most decks run exactly $targetTotal."

        val copies = LinkedHashMap<String, Pair<String, Int>>()
        for (e in entries) {
            val key = DeckFormat.normalizeCardName(e.name)
            val prev = copies[key]
            copies[key] = (prev?.first ?: e.name) to ((prev?.second ?: 0) + e.quantity)
        }
        copies.toSortedMap().values.filter { it.second > format.maxCopiesPerCard }.forEach {
            violations += "${it.first}: ${it.second} copies (max ${format.maxCopiesPerCard})."
        }
        format.legalSets?.let { legal ->
            val illegal = FormatLegality.illegalSets(entries.map { it.name to it.setName }, legal)
            if (illegal.isNotEmpty()) violations += "Cards from sets not legal in ${format.rawValue}: ${illegal.sorted().joinToString(", ")}."
        }
        val banned = entries.map { it.name }.filter { format.isBanned(it) }.toSet()
        if (banned.isNotEmpty()) violations += "Banned in ${format.rawValue}: ${banned.sorted().joinToString(", ")}."

        val deckInks = entries.flatMap { inks(it.inkColor) }.toSet()
        if (deckInks.size > format.maxInkColors) {
            violations += "Uses ${deckInks.size} inks (${deckInks.sorted().joinToString(", ")}) — ${format.rawValue} allows ${format.maxInkColors}."
        } else if (allowed != null) {
            val off = entries.filter { !fits(it.inkColor, allowed) }.map { it.name }.toSet()
            if (off.isNotEmpty()) violations += "Outside your inks: ${off.sorted().joinToString(", ")}."
        }
        val inkable = entries.filter { it.isInkable }.sumOf { it.quantity }
        if (total > 0 && inkable.toDouble() / total < MIN_INKABLE_RATIO) warnings += "Only $inkable of $total cards are inkable — most decks run 70%+."
        return AIDeckRuleReport(violations, warnings, total, inkable)
    }

    // MARK: - Parsing

    private val cardLine = Regex("""^(\d+)x\s+(.+?)(?:\s+\((.+?)\))?\s*$""")

    fun parseCardLine(line: String): AIDeckSuggestion? {
        val m = cardLine.find(line) ?: return null
        val qty = m.groupValues[1].toIntOrNull() ?: 0
        val name = m.groupValues[2].trim()
        return if (qty > 0 && name.isNotEmpty()) AIDeckSuggestion(cardName = name, quantity = qty) else null
    }

    fun parseSuggestions(response: String): List<AIDeckSuggestion> {
        val s = response.indexOf("[DECKLIST]")
        val e = response.indexOf("[/DECKLIST]")
        val content = if (s >= 0 && e > s) response.substring(s + 10, e) else response
        return content.lines().mapNotNull { parseCardLine(it.trim()) }
    }

    data class ParsedSwap(val outName: String, val outQuantity: Int, val inName: String, val inQuantity: Int)

    fun parseSwaps(response: String): List<ParsedSwap> {
        val s = response.indexOf("[SWAPS]")
        val e = response.indexOf("[/SWAPS]")
        val content = if (s >= 0 && e > s) response.substring(s + 7, e) else response
        val out = mutableListOf<ParsedSwap>()
        var pending: AIDeckSuggestion? = null
        fun parse(line: String, prefix: String) = if (line.uppercase().startsWith(prefix)) parseCardLine(line.substring(prefix.length).trim()) else null
        for (raw in content.lines()) {
            val line = raw.trim()
            val o = parse(line, "OUT:")
            if (o != null) { pending = o; continue }
            val i = parse(line, "IN:")
            val p = pending
            if (i != null && p != null) { out += ParsedSwap(p.cardName, p.quantity, i.cardName, i.quantity); pending = null }
        }
        return out
    }

    // MARK: - Matching

    fun normalizeName(name: String): String = name.replace('–', '-').replace('—', '-')
        .replace('‘', '\'').replace('’', '\'').replace("'", "").lowercase().trim()

    fun levenshtein(a: String, b: String): Int {
        if (a == b) return 0
        if (a.isEmpty()) return b.length
        if (b.isEmpty()) return a.length
        var prev = IntArray(b.length + 1) { it }
        var cur = IntArray(b.length + 1)
        for (i in 1..a.length) {
            cur[0] = i
            for (j in 1..b.length) cur[j] = if (a[i - 1] == b[j - 1]) prev[j - 1] else 1 + minOf(prev[j], cur[j - 1], prev[j - 1])
            val t = prev; prev = cur; cur = t
        }
        return prev[b.length]
    }

    private fun words(s: String) = s.split(Regex("[^\\p{L}\\p{N}]+")).filter { it.isNotEmpty() }.toSet()

    /** Increasingly fuzzy tiers, matching the iOS matcher order exactly. */
    fun matchSuggestions(input: List<AIDeckSuggestion>, cards: List<LorcanaCard>): List<AIDeckSuggestion> {
        val normalized = cards.map { it to normalizeName(it.name) }
        val lookup = HashMap<String, LorcanaCard>()
        normalized.forEach { (c, n) -> lookup.putIfAbsent(n, c) }
        return input.map { s ->
            val name = normalizeName(s.cardName)
            lookup[name]?.let { return@map s.copy(matchedCard = it) }
            normalized.firstOrNull { (_, n) -> n.contains(name) || name.contains(n) }?.let { return@map s.copy(matchedCard = it.first) }
            val parts = name.split(" - ")
            if (parts.size >= 2) {
                val first = parts[0].trim()
                val sub = parts.drop(1).joinToString(" - ").trim()
                normalized.firstOrNull { (_, n) -> n.contains(first) && n.contains(sub) }?.let { return@map s.copy(matchedCard = it.first) }
                normalized.firstOrNull { (_, n) ->
                    val cp = n.split(" - ")
                    cp.size >= 2 && levenshtein(first, cp[0].trim()) <= maxOf(1, minOf(2, first.length / 4)) && cp.drop(1).joinToString(" - ").trim() == sub
                }?.let { return@map s.copy(matchedCard = it.first) }
                normalized.firstOrNull { (_, n) ->
                    val cp = n.split(" - ")
                    cp.size >= 2 && cp[0].trim() == first && levenshtein(sub, cp.drop(1).joinToString(" - ").trim()) <= maxOf(1, minOf(2, sub.length / 3))
                }?.let { return@map s.copy(matchedCard = it.first) }
            }
            val sw = words(name)
            if (sw.size >= 2) {
                var best: LorcanaCard? = null
                var bestOverlap = 0.0
                for ((c, n) in normalized) {
                    val cw = words(n)
                    val overlap = sw.intersect(cw).size.toDouble() / maxOf(sw.size, cw.size)
                    if (overlap > bestOverlap) { bestOverlap = overlap; best = c }
                }
                if (bestOverlap >= 0.6 && best != null) return@map s.copy(matchedCard = best)
            }
            var bestCard: LorcanaCard? = null
            var bestDist = Int.MAX_VALUE
            for ((c, n) in normalized) {
                val d = levenshtein(name, n)
                if (d < bestDist) { bestDist = d; bestCard = c }
                if (d == 0) break
            }
            if (bestDist <= maxOf(3, name.length / 4) && bestCard != null) s.copy(matchedCard = bestCard) else s
        }
    }
}
