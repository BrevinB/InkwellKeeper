package co.brevinb.inkwellkeeper.decks

import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.CoconutLeaders
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.LorcanaCard
import java.text.Normalizer

/**
 * Reads and writes the community deck-list text format — "4 Elsa - Snow Queen" per line, as
 * Dreamborn, inkdecks, and Discord pastes use. Unmatched lines are reported, not dropped.
 */
object DeckListTextCodec {
    data class UnmatchedLine(val lineNumber: Int, val text: String)

    data class Entry(val card: LorcanaCard, val quantity: Int)

    data class ParseResult(
        val entries: List<Entry>,
        val unmatched: List<UnmatchedLine>,
        val coconutLeader: String?,
    ) {
        val totalMatchedCards: Int get() = entries.sumOf { it.quantity }
    }

    fun export(deck: Deck): String {
        val lines = mutableListOf<String>()
        deck.coconutLeaderInfo?.let { lines += "# Leader: ${it.name}" }
        lines += deck.cards.sortedWith(compareBy({ it.cost }, { it.name })).map { "${it.quantity} ${it.name}" }
        return lines.joinToString("\n")
    }

    fun looksLikeDeckList(text: String): Boolean = text.split("\n").any { parseLine(it) != null }

    fun parse(text: String, cards: List<LorcanaCard>): ParseResult {
        val normalCards = cards.filter { it.variant == CardVariant.NORMAL }
        val byName = LinkedHashMap<String, LorcanaCard>()
        val byUniqueId = HashMap<String, LorcanaCard>()
        for (card in normalCards) {
            byName.putIfAbsent(normalize(card.name), card)
            card.uniqueId?.let { byUniqueId[it.uppercase()] = card }
        }

        val quantities = LinkedHashMap<String, Int>()
        val order = LinkedHashMap<String, LorcanaCard>()
        val unmatched = mutableListOf<UnmatchedLine>()
        var leader: String? = null

        text.split("\n").forEachIndexed { index, rawLine ->
            val line = rawLine.trim()
            if (leader == null) {
                parseLeaderLine(line)?.let {
                    leader = it
                    return@forEachIndexed
                }
            }
            if (line.isEmpty() || isNonCardLine(line)) return@forEachIndexed
            val parsed = parseLine(line)
            val card = parsed?.let { resolve(it, byName, byUniqueId) }
            if (parsed == null || card == null) {
                unmatched += UnmatchedLine(index + 1, line)
                return@forEachIndexed
            }
            order.putIfAbsent(card.id, card)
            quantities.merge(card.id, parsed.quantity, Int::plus)
        }

        val entries = order.map { (id, card) -> Entry(card, quantities[id] ?: 0) }
        return ParseResult(entries, unmatched, leader)
    }

    private fun parseLeaderLine(line: String): String? {
        val lowered = line.lowercase()
        if (!lowered.startsWith("# leader:") && !lowered.startsWith("#leader:")) return null
        val name = line.substringAfter(":").trim()
        if (name.isEmpty()) return null
        val normalized = DeckFormat.normalizeCardName(name)
        return CoconutLeaders.all.firstOrNull { DeckFormat.normalizeCardName(it.name) == normalized }?.name
    }

    private data class ParsedLine(val quantity: Int, val name: String, val setCode: String?, val cardNumber: Int?)

    private val headerPrefixes = listOf("deck:", "format:", "colors:", "archetype:", "cards:", "exported from", "#", "//")

    private fun isNonCardLine(line: String): Boolean {
        val lowered = line.lowercase()
        return headerPrefixes.any { lowered.startsWith(it) }
    }

    private val lineRegex = Regex("""(\d{1,3})\s*[xX]?\s+(.+)""")
    private val suffixRegex = Regex("""\s*\(([A-Za-z0-9]{1,8})\)\s*(\d{1,4})?\s*$""")

    /** Accepts `4 Name`, `4x Name`, and an optional trailing `(SET) 42` / `(SET)` suffix. */
    private fun parseLine(line: String): ParsedLine? {
        val match = lineRegex.matchEntire(line.trim()) ?: return null
        val quantity = match.groupValues[1].toIntOrNull()?.takeIf { it > 0 } ?: return null
        var name = match.groupValues[2].trim()
        var setCode: String? = null
        var number: Int? = null
        suffixRegex.find(name)?.let { suffix ->
            setCode = suffix.groupValues[1]
            number = suffix.groupValues[2].toIntOrNull()
            name = name.removeRange(suffix.range).trim()
        }
        if (name.isEmpty()) return null
        return ParsedLine(quantity, name, setCode, number)
    }

    private fun resolve(line: ParsedLine, byName: Map<String, LorcanaCard>, byUniqueId: Map<String, LorcanaCard>): LorcanaCard? {
        val code = line.setCode
        val number = line.cardNumber
        if (code != null && number != null) {
            val padded = number.toString().padStart(3, '0')
            for (candidate in listOf("${code.uppercase()}-$padded", "${code.uppercase()}-$number")) {
                byUniqueId[candidate]?.let { return it }
            }
        }
        val normalized = normalize(line.name)
        byName[normalized]?.let { return it }

        val maxDistance = maxOf(1, minOf(3, normalized.length / 8))
        var best: Pair<LorcanaCard, Int>? = null
        for ((name, card) in byName) {
            if (kotlin.math.abs(name.length - normalized.length) > maxDistance) continue
            val distance = levenshtein(normalized, name)
            if (distance <= maxDistance && distance < (best?.second ?: Int.MAX_VALUE)) {
                best = Pair(card, distance)
                if (distance == 1) break
            }
        }
        return best?.first
    }

    /** Dash/apostrophe/diacritic/case-insensitive, whitespace-collapsed. */
    fun normalize(name: String): String {
        val folded = Normalizer.normalize(name.replace("’", "'").replace("‘", "'"), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
        return DeckFormat.normalizeCardName(folded)
    }

    private fun levenshtein(lhs: String, rhs: String): Int {
        if (lhs == rhs) return 0
        if (lhs.isEmpty()) return rhs.length
        if (rhs.isEmpty()) return lhs.length
        var previous = IntArray(rhs.length + 1) { it }
        var current = IntArray(rhs.length + 1)
        for (row in 1..lhs.length) {
            current[0] = row
            for (col in 1..rhs.length) {
                current[col] = if (lhs[row - 1] == rhs[col - 1]) previous[col - 1]
                else 1 + minOf(previous[col], current[col - 1], previous[col - 1])
            }
            val swap = previous
            previous = current
            current = swap
        }
        return previous[rhs.length]
    }
}
