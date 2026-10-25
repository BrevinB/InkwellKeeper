package co.brevinb.inkwellkeeper.scan

import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.LorcanaSet

/**
 * Turns OCR text from a card photo into a catalog card. A port of the iOS `CameraManager`
 * matching logic; pure so it can be unit tested against the real catalog.
 */
class CardRecognizer(
    private val allCards: List<LorcanaCard>,
    private val sets: List<LorcanaSet>,
    private val search: (String) -> List<LorcanaCard>,
) {
    sealed interface Resolution {
        data class Found(val card: LorcanaCard) : Resolution
        /** A reprint whose set couldn't be read: the collector picks. */
        data class ChooseSet(val choices: List<LorcanaCard>) : Resolution
    }

    data class CardNumberInfo(val cardNumber: Int, val setTotal: Int, val setNumber: String?)

    /** Recognizes and resolves set/variant in one step; null when nothing matched. */
    fun recognize(texts: List<String>): Resolution? {
        if (texts.isEmpty()) return null
        val card = searchForCard(texts) ?: return null
        return resolveCardSet(card, texts)
    }

    fun searchForCard(texts: List<String>): LorcanaCard? {
        val byNumber = findCardByNumber(texts)
        // Trust the number outright only when the name corroborates it: one misread digit
        // in the tiny collector line otherwise returns a confidently wrong card.
        if (byNumber != null && cardNameMatchesDetectedText(byNumber, texts)) return byNumber
        for (name in extractCardNames(texts)) {
            val results = search(name)
            if (results.isNotEmpty()) findBestMatch(name, results, texts)?.let { return it }
        }
        val combined = texts.filter { it.length > 2 }.joinToString(" ")
        if (combined.isNotEmpty()) {
            search(combined).firstOrNull { cardNameMatchesDetectedText(it, texts) }?.let { return it }
        }
        return byNumber
    }

    fun parseCardNumber(texts: List<String>): CardNumberInfo? {
        val full = Regex("""(\d{1,4})\s*/\s*(\d{2,4})\s*[·.\-\s]+\s*EN\s*[·.\-\s]+\s*([A-Z0-9]+)""", RegexOption.IGNORE_CASE)
        for (text in texts) {
            val m = full.find(text) ?: continue
            val number = m.groupValues[1].toIntOrNull() ?: continue
            val total = m.groupValues[2].toIntOrNull() ?: continue
            if (number > 0 && total > 0) return CardNumberInfo(number, total, m.groupValues[3])
        }
        val simple = Regex("""(\d{1,4})\s*/\s*(\d{2,4})""")
        for (text in texts) {
            val m = simple.find(text) ?: continue
            val number = m.groupValues[1].toIntOrNull() ?: continue
            val total = m.groupValues[2].toIntOrNull() ?: continue
            if (number > 0 && total > 0) return CardNumberInfo(number, total, null)
        }
        return null
    }

    private fun setByNumber(code: String): LorcanaSet? = sets.firstOrNull { it.setNumber == code }

    private fun setsByCount(total: Int): List<LorcanaSet> =
        sets.filter { it.cardCount == total }.ifEmpty { sets.filter { kotlin.math.abs(it.cardCount - total) <= 2 } }

    private fun setByCount(total: Int): LorcanaSet? = setsByCount(total).singleOrNull()

    fun findCardByNumber(texts: List<String>): LorcanaCard? {
        val info = parseCardNumber(texts) ?: return null
        info.setNumber?.let { setByNumber(it) }?.let { set ->
            allCards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber }?.let { return it }
        }
        setByCount(info.setTotal)?.let { set ->
            allCards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber }?.let { return it }
        }
        val possible = setsByCount(info.setTotal)
        if (possible.size > 1) {
            val names = possible.map { it.name }.toSet()
            allCards.filter { it.cardNumber == info.cardNumber && it.setName in names }.singleOrNull()?.let { return it }
        }
        return null
    }

    private fun narrowBySetInfo(cards: List<LorcanaCard>, texts: List<String>): LorcanaCard? {
        val info = parseCardNumber(texts) ?: return null
        info.setNumber?.let { setByNumber(it) }?.let { set ->
            (cards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber } ?: cards.firstOrNull { it.setName == set.name })?.let { return it }
        }
        setByCount(info.setTotal)?.let { set ->
            (cards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber } ?: cards.firstOrNull { it.setName == set.name })?.let { return it }
        }
        return cards.filter { it.cardNumber == info.cardNumber }.singleOrNull()
    }

    fun resolveCardSet(card: LorcanaCard, texts: List<String>): Resolution {
        resolveVariant(card, texts)?.let { return Resolution.Found(it) }
        val promoCodes = sets.mapNotNull { s -> s.setNumber?.takeIf { it.toIntOrNull() == null }?.let { it.uppercase() to s.name } }.toMap()
        promoPrinting(card, texts, promoCodes)?.let { return Resolution.Found(it) }
        val versions = allCards.filter { it.name == card.name && it.variant == CardVariant.NORMAL }
        if (versions.size <= 1) return Resolution.Found(versions.firstOrNull() ?: card)
        narrowBySetInfo(versions, texts)?.let { return Resolution.Found(it) }
        return Resolution.ChooseSet(versions)
    }

    private val specials = listOf(CardVariant.ENCHANTED, CardVariant.EPIC, CardVariant.ICONIC)

    /** Numbers beyond the set total (e.g. 205/204) are Enchanted / Epic / Iconic printings. */
    private fun resolveVariant(card: LorcanaCard, texts: List<String>): LorcanaCard? {
        val info = parseCardNumber(texts) ?: return null
        if (info.cardNumber <= info.setTotal) return null
        val main = mainName(card.name)
        fun mainMatches(c: LorcanaCard) = c.name.lowercase().startsWith(main) || mainName(c.name) == main
        info.setNumber?.let { setByNumber(it) }?.let { set ->
            for (v in specials) allCards.firstOrNull { it.name == card.name && it.setName == set.name && it.variant == v && it.cardNumber == info.cardNumber }?.let { return it }
            allCards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber && it.variant in specials && mainMatches(it) }?.let { return it }
            for (v in specials) allCards.firstOrNull { it.name == card.name && it.setName == set.name && it.variant == v }?.let { return it }
        }
        val candidates = setsByCount(info.setTotal)
        for (set in candidates) for (v in specials) {
            allCards.firstOrNull { it.name == card.name && it.setName == set.name && it.variant == v && it.cardNumber == info.cardNumber }?.let { return it }
        }
        for (set in candidates) {
            allCards.firstOrNull { it.setName == set.name && it.cardNumber == info.cardNumber && it.variant in specials && mainMatches(it) }?.let { return it }
        }
        return null
    }

    /** "12/P2": a lettered set code in the collector line is the only proof of a promo. */
    private fun promoPrinting(card: LorcanaCard, texts: List<String>, codes: Map<String, String>): LorcanaCard? {
        if (codes.isEmpty()) return null
        val regex = Regex("""(\d{1,3})\s*/\s*([A-Z]+\d*)""", RegexOption.IGNORE_CASE)
        for (text in texts) for (m in regex.findAll(text)) {
            val number = m.groupValues[1].toIntOrNull() ?: continue
            val setName = codes[m.groupValues[2].uppercase()] ?: continue
            val inSet = allCards.filter { it.setName == setName && it.name == card.name }
            (inSet.firstOrNull { it.cardNumber == number } ?: inSet.firstOrNull())?.let { return it }
        }
        return null
    }

    companion object {
        private val connectorWords = setOf("of", "the", "and", "in", "on", "to", "a", "an", "for", "from", "with", "at", "by")
        private val brandWords = setOf("disney", "lorcana", "tm", "en")

        fun mainName(name: String): String = name.split(" - ").first().lowercase().trim()

        /** Search queries from OCR lines: "MAIN - Subtitle" combos, then main names, subtitles, other words. */
        fun extractCardNames(texts: List<String>): List<String> {
            val mains = mutableListOf<String>()
            val subs = mutableListOf<String>()
            val others = mutableListOf<String>()
            for (raw in texts) {
                val text = raw.trim()
                if (text.length < 2 || text.all { !it.isLetter() }) continue
                val lower = text.lowercase()
                if (lower in listOf("characters get", "at the start", "while here", "/204", "© while here") ||
                    listOf("get +", "+1 ©", " turn").any { lower.contains(it) }
                ) continue
                val words = lower.split(Regex("[^a-z0-9]+")).filter { it.isNotEmpty() }
                if (words.isNotEmpty() && words.all { it in brandWords }) continue
                if (text.length >= 3 && text == text.uppercase()) {
                    mains += text
                    continue
                }
                if (' ' in text && text.length > 5) {
                    val parts = text.split(" ").filter { it.isNotEmpty() }
                    val nameLike = parts.first().first().isUpperCase() &&
                        parts.all { it.first().isUpperCase() || it.lowercase() in connectorWords }
                    if (nameLike) {
                        if (!lower.contains("ground") && !lower.contains("haven")) subs += text
                        continue
                    }
                }
                if (text.length > 3 && text.first().isUpperCase() && ' ' !in text) others += text
            }
            return mains.flatMap { m -> subs.map { s -> "$m - $s" } } + mains + subs + others
        }

        fun findBestMatch(term: String, cards: List<LorcanaCard>, texts: List<String>): LorcanaCard? {
            val lower = term.lowercase()
            cards.filter { it.name.lowercase() == lower }.takeIf { it.isNotEmpty() }?.let { exact ->
                return exact.firstOrNull { it.variant == CardVariant.NORMAL } ?: exact.first()
            }
            if (term.split(" ").size > 1) {
                val parts = term.split(" - ")
                val (main, sub) = if (parts.size == 2) parts[0].lowercase().trim() to parts[1].lowercase().trim()
                else term.split(" ").let { it[0].lowercase() to it.drop(1).joinToString(" ").lowercase() }
                fun split(c: LorcanaCard) = c.name.split(" - ").takeIf { it.size == 2 }?.let { it[0].lowercase().trim() to it[1].lowercase().trim() }
                cards.firstOrNull { split(it)?.let { (m, s) -> m == main && s == sub } == true }?.let { return it }
                cards.firstOrNull { split(it)?.let { (m, s) -> m.contains(main) && s.contains(sub) } == true }?.let { return it }
                cards.firstOrNull { split(it)?.let { (_, s) -> s == sub || s.contains(sub) } == true }?.let { return it }
            }
            val mainMatches = cards.filter { mainName(it.name) == lower }
            if (mainMatches.size == 1) return mainMatches.first()
            if (mainMatches.size > 1) {
                val haystack = texts.joinToString(" ").lowercase()
                // Score distinctive subtitle words so a shared word ("snowman") can't decide.
                val scored = mainMatches.map { c ->
                    c to c.name.split(" - ").getOrElse(1) { "" }.lowercase().split(" ").filter { it.length > 3 }.count { haystack.contains(it) }
                }
                val best = scored.maxOf { it.second }
                if (best > 0) scored.filter { it.second == best }.singleOrNull()?.let { return it.first }
                return mainMatches.maxByOrNull { it.setName }
            }
            cards.firstOrNull { it.name.lowercase().startsWith(lower) }?.let { return it }
            return cards.filter { it.name.lowercase().contains(lower) }.firstOrNull { cardNameMatchesDetectedText(it, texts) }
        }

        /** The longest token (4+ letters) of the main name must appear in the OCR text. */
        fun cardNameMatchesDetectedText(card: LorcanaCard, texts: List<String>): Boolean {
            val haystack = texts.joinToString(" ").lowercase()
            if (haystack.isEmpty()) return false
            val main = card.name.split(" - ").first()
            val tokens = main.lowercase().split(Regex("[^a-z0-9]+")).filter { it.length >= 4 }
            val distinctive = tokens.maxByOrNull { it.length } ?: return haystack.contains(main.lowercase())
            return haystack.contains(distinctive)
        }
    }
}
