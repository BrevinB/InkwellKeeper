package co.brevinb.inkwellkeeper.transfer

import android.content.Context
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import java.net.URI
import java.util.Locale
import java.util.UUID

/**
 * Bulk import from Dreamborn, Collectr / Lorcana.gg header-mapped CSVs, text lists, Lorcana HQ,
 * the official Disney Lorcana app's backup, and this app's own JSON backup. A port of the iOS
 * `ImportService`, including its matching priorities.
 */
object ImportService {
    enum class Format(val description: String) {
        CSV("CSV File"),
        TEXT_LIST("Text List"),
        DREAMBORN("Dreamborn.ink"),
        LORCANA_HQ("Lorcana HQ"),
        COLLECTR("Collectr"),
        OFFICIAL_BACKUP("Official App Backup"),
        INKWELL_BACKUP("Inkwell Keeper Backup"),
    }

    data class ImportedCard(val card: LorcanaCard, val quantity: Int, val originalLine: String)
    data class FailedImport(val originalLine: String, val reason: String)
    data class Result(val successful: List<ImportedCard>, val failed: List<FailedImport>) {
        val totalCardsCount: Int get() = successful.sumOf { it.quantity }
        val uniqueCardsCount: Int get() = successful.map { "${it.card.id}_${it.card.variant.rawValue}" }.toSet().size
    }
    data class Progress(val progress: Double = 0.0, val totalCards: Int = 0, val uniqueCards: Int = 0, val normalCards: Int = 0, val foilCards: Int = 0, val failedCards: Int = 0)

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    /** Picks a format from the file's content, as the iOS import screen does. */
    fun detectFormat(text: String): Format {
        val trimmed = text.trim()
        if (InkwellBackup.looksLikeBackup(trimmed)) return Format.INKWELL_BACKUP
        if (isOfficialBackup(trimmed)) return Format.OFFICIAL_BACKUP
        val first = trimmed.lineSequence().firstOrNull()?.lowercase().orEmpty()
        if (first.contains("set number") && first.contains("variant")) return Format.DREAMBORN
        if (HeaderColumnMap.from(first) != null && first.contains(",")) return Format.COLLECTR
        val dreambornRow = trimmed.lineSequence().take(3).any { parseDreambornLine(it) != null }
        if (dreambornRow) return Format.DREAMBORN
        return if (trimmed.contains(",")) Format.CSV else Format.TEXT_LIST
    }

    fun isOfficialBackup(text: String): Boolean {
        val trimmed = text.trim()
        return trimmed.startsWith("{") && "\"OwnedCardQuantitiesV2\"" in trimmed
    }

    /** Accepts the official app's share link, the direct backup URL, or a bare id. */
    fun officialBackupDownloadUrl(shareLink: String): String? {
        val trimmed = shareLink.trim()
        runCatching { URI(trimmed) }.getOrNull()?.let { uri ->
            if (uri.host?.endsWith("sharing.lorcana.ravensburger.com") == true && uri.path?.startsWith("/backup/") == true) return trimmed
            val id = uri.rawQuery?.split("&")?.map { it.split("=", limit = 2) }?.firstOrNull { it.size == 2 && it[0] == "id" }?.get(1)
            if (id != null && runCatching { UUID.fromString(id) }.isSuccess) return "https://sharing.lorcana.ravensburger.com/backup/$id.json"
        }
        if (runCatching { UUID.fromString(trimmed) }.isSuccess) return "https://sharing.lorcana.ravensburger.com/backup/$trimmed.json"
        return null
    }

    suspend fun fetchOfficialBackup(shareLink: String): String = withContext(Dispatchers.IO) {
        val url = officialBackupDownloadUrl(shareLink)
            ?: error("That doesn't look like a Lorcana backup link. In the official app, use Collection backup → Backup now, then copy the link it creates.")
        val text = runCatching {
            OkHttpClient().newCall(Request.Builder().url(url).build()).execute().use { if (it.isSuccessful) it.body?.string() else null }
        }.getOrNull()
        if (text == null || !isOfficialBackup(text)) error("Couldn't download the backup. Check your connection, or create a fresh backup link in the official app and try again.")
        text
    }

    /** Column positions from a CSV header, mapped by name since order varies by exporter. */
    class HeaderColumnMap private constructor(
        val name: Int?, val set: Int?, val cardNumber: Int?, val variant: Int?, val quantity: Int?, val game: Int?,
        val normalCount: Int?, val foilCount: Int?,
    ) {
        companion object {
            fun from(headerLine: String): HeaderColumnMap? {
                val headers = parseCsvFields(headerLine).map { it.lowercase() }
                val names = listOf("product name", "card name", "name", "product", "card")
                val sets = listOf("set name", "set", "expansion", "series")
                val numbers = listOf("card number", "collector number", "card no", "card #", "number", "no.", "#")
                val variants = listOf("variance", "variant", "printing", "finish", "foil", "holofoil")
                val quantities = listOf("quantity", "count", "qty", "amount")
                val games = listOf("category", "game", "tcg", "product line")
                val dual = "normal" in headers && "foil" in headers
                var name: Int? = null; var set: Int? = null; var number: Int? = null; var variant: Int? = null
                var quantity: Int? = null; var game: Int? = null; var normal: Int? = null; var foil: Int? = null
                headers.forEachIndexed { i, h ->
                    when {
                        dual && h == "normal" -> normal = i
                        dual && h == "foil" -> foil = i
                        name == null && h in names -> name = i
                        set == null && h in sets -> set = i
                        number == null && h in numbers -> number = i
                        variant == null && h in variants -> variant = i
                        quantity == null && h in quantities -> quantity = i
                        game == null && h in games -> game = i
                    }
                }
                return if (name == null) null else HeaderColumnMap(name, set, number, variant, quantity, game, normal, foil)
            }
        }
    }

    private class CardIndex(cards: List<LorcanaCard>) {
        private val byName = HashMap<String, MutableList<LorcanaCard>>()
        private val bySetNumber = HashMap<String, MutableList<LorcanaCard>>()
        private val entries = ArrayList<Pair<String, LorcanaCard>>(cards.size)

        init {
            for (card in cards) {
                val n = normalizeName(card.name)
                byName.getOrPut(n) { mutableListOf() }.add(card)
                entries += n to card
                card.cardNumber?.let { bySetNumber.getOrPut("${normalizeSetName(card.setName)}|$it") { mutableListOf() }.add(card) }
            }
        }

        fun named(n: String): List<LorcanaCard> = byName[n].orEmpty()
        fun setNumber(normalizedSet: String, number: Int): List<LorcanaCard> = bySetNumber["$normalizedSet|$number"].orEmpty()
        fun fuzzy(n: String): List<LorcanaCard> = entries.filter { it.first.contains(n) || n.contains(it.first) }.map { it.second }
    }

    /**
     * Matches every line and reports each match through [onCardMatched] so the caller can add
     * it immediately. Waits for the catalog first (fresh-install imports race the load).
     */
    suspend fun importAndAdd(
        context: Context,
        text: String,
        format: Format,
        onCardMatched: (LorcanaCard, Int) -> Unit,
        onProgress: (Progress) -> Unit = {},
    ): Result {
        SetsDataManager.loaded.first { it }
        val index = withContext(Dispatchers.Default) { CardIndex(SetsDataManager.getAllCards()) }
        var stats = Progress()
        fun record(item: ImportedCard) {
            stats = stats.copy(
                totalCards = stats.totalCards + item.quantity,
                uniqueCards = stats.uniqueCards + 1,
                foilCards = stats.foilCards + if (item.card.variant == CardVariant.FOIL) item.quantity else 0,
                normalCards = stats.normalCards + if (item.card.variant == CardVariant.FOIL) 0 else item.quantity,
            )
            onCardMatched(item.card, item.quantity)
        }

        if (format == Format.OFFICIAL_BACKUP || format == Format.INKWELL_BACKUP) {
            val result = withContext(Dispatchers.Default) {
                if (format == Format.OFFICIAL_BACKUP) matchOfficialBackup(context, text, index) else matchInkwellBackup(text, index)
            }
            result.successful.forEach(::record)
            stats = stats.copy(failedCards = result.failed.size, progress = 1.0)
            onProgress(stats)
            return result
        }

        val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
        val columnMap = if (format == Format.COLLECTR) lines.firstOrNull()?.let { HeaderColumnMap.from(it) } else null
        val successful = mutableListOf<ImportedCard>()
        val failed = mutableListOf<FailedImport>()
        for ((i, line) in lines.withIndex()) {
            if (i == 0) {
                if (columnMap != null) continue
                val lower = line.lowercase()
                if (lower.contains("set number") && lower.contains("variant")) continue
                if (lower.contains("name") && (lower.contains("card") || lower.contains("normal") || lower.contains("rarity"))) continue
            }
            val (cards, failures) = matchLine(line, format, index, columnMap)
            cards.forEach { successful += it; record(it) }
            failures.forEach { failed += it }
            stats = stats.copy(failedCards = failed.size)
            if (i % 10 == 0 || i == lines.lastIndex) {
                stats = stats.copy(progress = (i + 1).toDouble() / lines.size)
                onProgress(stats)
            }
        }
        return Result(successful, failed)
    }

    private fun matchLine(line: String, format: Format, index: CardIndex, map: HeaderColumnMap?): Pair<List<ImportedCard>, List<FailedImport>> {
        val cards = mutableListOf<ImportedCard>()
        val failures = mutableListOf<FailedImport>()
        fun setInfo(set: String?) = set?.let { " from set '$it'" } ?: ""

        when (format) {
            Format.COLLECTR -> {
                map ?: return cards to failures
                for (row in parseHeaderMappedRows(line, map)) {
                    val bySetNumber = if (row.set != null && row.number != null) matchBySetAndNumber(row.set, row.number, row.variant, index) else null
                    val matched = bySetNumber
                        ?: (if (row.variant == CardVariant.FOIL) findCard(row.name, row.set, CardVariant.NORMAL, index)?.let { if (it.variant == CardVariant.NORMAL) foilVariant(it) else it } else null)
                        ?: findCard(row.name, row.set, row.variant, index)
                    if (matched != null) cards += ImportedCard(matched, row.quantity, line)
                    else failures += FailedImport(line, "Card not found: '${row.name}'${setInfo(row.set)}")
                }
            }
            Format.DREAMBORN -> {
                val parsed = parseDreambornLine(line) ?: return cards to failures
                if (parsed.set != null && parsed.number != null) {
                    matchBySetAndNumber(parsed.set, parsed.number, parsed.variant, index)?.let {
                        cards += ImportedCard(it, parsed.quantity, line)
                        return cards to failures
                    }
                }
                if (parsed.name.isEmpty()) {
                    failures += FailedImport(line, "Card not found by set and number: '$line'")
                    return cards to failures
                }
                if (parsed.variant == CardVariant.FOIL) {
                    val direct = findCard(parsed.name, parsed.set, CardVariant.FOIL, index)?.takeIf { it.variant == CardVariant.FOIL }
                    val matched = direct ?: findCard(parsed.name, parsed.set, CardVariant.NORMAL, index)?.let { if (it.variant == CardVariant.NORMAL) foilVariant(it) else it }
                    if (matched != null) cards += ImportedCard(matched, parsed.quantity, line)
                    else failures += FailedImport(line, "Foil card not found: '${parsed.name}'${setInfo(parsed.set)}")
                } else {
                    val matched = findCard(parsed.name, parsed.set, parsed.variant, index)
                    if (matched != null) cards += ImportedCard(matched, parsed.quantity, line)
                    else failures += FailedImport(line, "Card not found: '${parsed.name}'${setInfo(parsed.set)}")
                }
            }
            else -> {
                val parsed = when (format) {
                    Format.CSV -> parseCsvLine(line)
                    else -> parseTextListLine(line)
                } ?: return cards to failures
                val matched = findCard(parsed.name, parsed.set, parsed.variant, index)
                if (matched != null) cards += ImportedCard(matched, parsed.quantity, line)
                else failures += FailedImport(line, "Card not found: '${parsed.name}'${setInfo(parsed.set)} [${parsed.variant.displayName}]")
            }
        }
        return cards to failures
    }

    /** Set + number is unambiguous and the only way to match Epic/Enchanted/Iconic printings. */
    private fun matchBySetAndNumber(setName: String, number: Int, variant: CardVariant, index: CardIndex): LorcanaCard? {
        val candidates = index.setNumber(normalizeSetName(setName), number)
        if (candidates.isEmpty()) return null
        candidates.firstOrNull { it.variant == variant }?.let { return it }
        if (variant != CardVariant.NORMAL) {
            candidates.firstOrNull { it.variant != CardVariant.NORMAL }?.let { return it }
            if (variant == CardVariant.FOIL) return foilVariant(candidates.first())
        }
        return candidates.firstOrNull { it.variant == CardVariant.NORMAL } ?: candidates.first()
    }

    private fun findCard(name: String, setName: String?, variant: CardVariant, index: CardIndex): LorcanaCard? {
        val n = normalizeName(name)
        val candidates = index.named(n)
        val normalizedSet = setName?.let { normalizeSetName(it) }
        if (normalizedSet != null) candidates.firstOrNull { normalizeSetName(it.setName) == normalizedSet && it.variant == variant }?.let { return it }
        candidates.firstOrNull { it.variant == variant }?.let { return it }
        if (normalizedSet != null) candidates.firstOrNull { normalizeSetName(it.setName) == normalizedSet }?.let { return it }
        candidates.firstOrNull()?.let { return it }
        val fuzzy = index.fuzzy(n)
        return fuzzy.firstOrNull { it.variant == variant } ?: fuzzy.firstOrNull()
    }

    /** A foil copy of a catalog card, with an id distinct from the normal one. */
    fun foilVariant(card: LorcanaCard): LorcanaCard = card.copy(
        id = if ("_N_" in card.id) card.id.replace("_N_", "_F_") else card.id + "_Foil",
        variant = CardVariant.FOIL,
    )

    private data class Parsed(val name: String, val set: String?, val variant: CardVariant, val quantity: Int, val number: Int? = null)

    /** Dreamborn: `Set Number,Card Number,Variant,Count,Name,Color,Rarity` (or the nameless 4-column form). */
    private fun parseDreambornLine(line: String): Parsed? {
        val c = parseCsvFields(line)
        if (c.size < 4) return null
        val variantString = c[2].lowercase()
        val quantity = c[3].toIntOrNull() ?: 0
        val name = when {
            c.size == 4 -> if (variantString == "normal" || variantString == "foil") "" else return null
            // Unquoted names with commas spill across fields: name is everything before Color + Rarity.
            c.size > 7 -> c.subList(4, c.size - 2).joinToString(", ")
            else -> c[4]
        }
        if (quantity <= 0 || (c.size != 4 && name.isEmpty())) return null
        return Parsed(name, mapDreambornSetNumber(c[0]), if (variantString == "foil") CardVariant.FOIL else CardVariant.NORMAL, quantity, c[1].toIntOrNull())
    }

    private fun parseHeaderMappedRows(line: String, map: HeaderColumnMap): List<Parsed> {
        val fields = parseCsvFields(line)
        fun field(i: Int?): String? = i?.let { fields.getOrNull(it) }?.takeIf { it.isNotEmpty() }
        field(map.game)?.let { if (!it.contains("lorcana", ignoreCase = true)) return emptyList() }
        var name = field(map.name) ?: return emptyList()
        var variant = parseVariant(field(map.variant) ?: "")
        val tag = Regex("""\s*\((foil|holofoil|cold foil|enchanted|epic|iconic)\)\s*$""", RegexOption.IGNORE_CASE).find(name)
        if (tag != null) {
            if (variant == CardVariant.NORMAL) variant = parseVariant(tag.value)
            name = name.removeRange(tag.range)
        }
        var set = field(map.set)
        set?.let { s ->
            val colon = s.indexOf(':')
            if (colon > 0 && s.substring(0, colon).contains("lorcana", true)) set = s.substring(colon + 1).trim()
        }
        set?.let { s -> mapDreambornSetNumber(s)?.let { set = it } }
        val number = field(map.cardNumber)?.substringBefore("/")?.trim()?.toIntOrNull()
        if (map.normalCount != null || map.foilCount != null) {
            return buildList {
                field(map.normalCount)?.toIntOrNull()?.takeIf { it > 0 }?.let { add(Parsed(name, set, CardVariant.NORMAL, it, number)) }
                field(map.foilCount)?.toIntOrNull()?.takeIf { it > 0 }?.let { add(Parsed(name, set, CardVariant.FOIL, it, number)) }
            }
        }
        val quantity = field(map.quantity)?.toIntOrNull() ?: 1
        return if (quantity > 0) listOf(Parsed(name, set, variant, quantity, number)) else emptyList()
    }

    private fun parseCsvLine(line: String): Parsed? {
        val components = if ('"' in line) {
            Regex("\"([^\"]*)\"|([^,]+)").findAll(line).map { (it.groups[1]?.value ?: it.groups[2]?.value ?: "").trim() }.filter { it.isNotEmpty() }.toList()
        } else {
            line.split(",").map { it.trim() }
        }
        if (components.isEmpty()) return null
        val name = components[0]
        var set = components.getOrNull(1)
        var quantity = 1
        var variant = CardVariant.NORMAL
        val last = components.last().toIntOrNull()
        if (last != null) {
            quantity = last
            if (components.size == 4) {
                variant = parseVariant(components[2])
            } else if (components.size == 3) {
                val second = components[1].lowercase()
                if (second.contains("chapter") || second.contains("floodborn") || second.contains("inklands")) set = components[1]
                else { variant = parseVariant(components[1]); set = null }
            }
        } else if (components.size >= 2) {
            variant = parseVariant(components.last())
        }
        return Parsed(name, set, variant, quantity)
    }

    /** "2x Name", "Name x2", "2 Name", or just "Name"; "(Foil)"/"Enchanted" keywords set the variant. */
    private fun parseTextListLine(line: String): Parsed {
        var quantity = 1
        var name = line
        Regex("""^(\d+)\s*[x×]\s*(.+)$""").find(line)?.let { quantity = it.groupValues[1].toInt(); name = it.groupValues[2].trim() }
            ?: Regex("""^(.+?)\s*[x×]\s*(\d+)$""").find(line)?.let { name = it.groupValues[1].trim(); quantity = it.groupValues[2].toInt() }
            ?: Regex("""^(\d+)\s+(.+)$""").find(line)?.let { quantity = it.groupValues[1].toInt(); name = it.groupValues[2] }
        var variant = CardVariant.NORMAL
        val lower = name.lowercase()
        if ("foil" in lower) {
            variant = CardVariant.FOIL
            name = name.replace(Regex("\\(?foil\\)?", RegexOption.IGNORE_CASE), "").trim()
        } else if ("enchanted" in lower) {
            variant = CardVariant.ENCHANTED
            name = name.replace(Regex("\\(?enchanted\\)?", RegexOption.IGNORE_CASE), "").trim()
        }
        return Parsed(name, null, variant, quantity)
    }

    // MARK: - JSON backups

    @Serializable
    private data class OfficialBackup(@SerialName("OwnedCardQuantitiesV2") val owned: List<Entry> = emptyList()) {
        @Serializable
        data class Entry(@SerialName("Id") val id: Int, @SerialName("Type") val type: String = "", @SerialName("Quantity") val quantity: Int = 0)
    }

    @Serializable
    private data class OfficialRefs(val cards: List<Ref> = emptyList()) {
        @Serializable
        data class Ref(@SerialName("i") val officialId: Int, @SerialName("s") val setCode: String, @SerialName("n") val cardNumber: Int, @SerialName("m") val name: String)
    }

    private var officialRefs: Map<Int, OfficialRefs.Ref>? = null

    private fun refs(context: Context): Map<Int, OfficialRefs.Ref> = officialRefs ?: runCatching {
        val text = context.assets.open("official_card_ids.json").bufferedReader().use { it.readText() }
        json.decodeFromString(OfficialRefs.serializer(), text).cards.associateBy { it.officialId }
    }.getOrDefault(emptyMap()).also { officialRefs = it }

    private fun matchInkwellBackup(text: String, index: CardIndex): Result {
        val backup = InkwellBackup.decode(text) ?: return Result(emptyList(), listOf(FailedImport("Backup file", "Couldn't read the Inkwell Keeper backup file")))
        val ok = mutableListOf<ImportedCard>()
        val failed = mutableListOf<FailedImport>()
        for (entry in backup.cards) {
            if (entry.quantity <= 0) continue
            val variant = CardVariant.fromRawOrNormal(entry.variant)
            val label = "${entry.name} — ${entry.setName}"
            val matched = entry.cardNumber?.let { matchBySetAndNumber(entry.setName, it, variant, index) } ?: findCard(entry.name, entry.setName, variant, index)
            if (matched != null) ok += ImportedCard(matched, entry.quantity, label) else failed += FailedImport(label, "Card not found: '${entry.name}'")
        }
        return Result(ok, failed)
    }

    private fun matchOfficialBackup(context: Context, text: String, index: CardIndex): Result {
        val backup = runCatching { json.decodeFromString(OfficialBackup.serializer(), text) }.getOrNull()
            ?: return Result(emptyList(), listOf(FailedImport("Backup file", "Couldn't read the official app backup file")))
        val refs = refs(context)
        val ok = mutableListOf<ImportedCard>()
        val failed = mutableListOf<FailedImport>()
        for (entry in backup.owned) {
            if (entry.quantity <= 0) continue
            val variant = if (entry.type.lowercase() == "foiled") CardVariant.FOIL else CardVariant.NORMAL
            val ref = refs[entry.id]
            if (ref == null) {
                failed += FailedImport("Official card id ${entry.id}", "Unknown card id ${entry.id} — the app may need an update for the newest set")
                continue
            }
            val setName = mapDreambornSetNumber(ref.setCode)
            val label = "${ref.name} — official id ${entry.id}"
            val matched = setName?.let { matchBySetAndNumber(it, ref.cardNumber, variant, index) }
                ?: (if (variant == CardVariant.FOIL) findCard(ref.name, setName, CardVariant.NORMAL, index)?.let { if (it.variant == CardVariant.NORMAL) foilVariant(it) else it } else null)
                ?: findCard(ref.name, setName, variant, index)
            if (matched != null) ok += ImportedCard(matched, entry.quantity, label) else failed += FailedImport(label, "Card not found: '${ref.name}'")
        }
        return Result(ok, failed)
    }

    // MARK: - Helpers

    fun parseCsvFields(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        for (ch in line) {
            when {
                ch == '"' -> inQuotes = !inQuotes
                ch == ',' && !inQuotes -> { fields += current.toString().trim(); current.clear() }
                else -> current.append(ch)
            }
        }
        fields += current.toString().trim()
        return fields
    }

    fun mapDreambornSetNumber(code: String): String? = when (code) {
        "001", "1" -> "The First Chapter"
        "002", "2" -> "Rise of the Floodborn"
        "003", "3" -> "Into the Inklands"
        "004", "4" -> "Ursula's Return"
        "005", "5" -> "Shimmering Skies"
        "006", "6" -> "Azurite Sea"
        "007", "7" -> "Archazia's Island"
        "008", "8" -> "Reign of Jafar"
        "009", "9" -> "Fabled"
        "010", "10" -> "Whispers in the Well"
        "011", "11" -> "Winterspell"
        "012", "12" -> "Wilds Unknown"
        "013", "13" -> "Attack of the Vine!"
        "PD1" -> "Promo Set PD1"
        "014", "14" -> "Hyperia City"
        "P4" -> "Promo Set 4"
        "CC1" -> "Curator's Collection: Heroines Edition"
        "P1" -> "Promo Set 1"
        "P2" -> "Promo Set 2"
        "P3" -> "Promo Set 3"
        "C1", "CP" -> "Challenge Promo"
        "C2" -> "Lorcana Challenge Year 3"
        "D23" -> "D23 Collection"
        "DIS", "EFA" -> "EPCOT Festival of the Arts"
        else -> null
    }

    private fun normalizeName(name: String): String = name.lowercase().trim()
        .replace(" ", " ").replace("  ", " ")
        .replace("’", "'").replace("‘", "'").replace("ʼ", "'")
        .replace("“", "\"").replace("”", "\"").replace("„", "\"")
        .replace("…", "...").replace("......", "...").replace(".....", "...").replace("....", "...")
        .replace(" . . . ", " ... ").replace(" . . .", " ...").replace(". . .", "...")
        .replace(" .  . ", " ... ").replace(" .  .", " ...").replace(".  .", "...")
        .replace("–", "-").replace("—", "-")

    private val setAbbreviations = mapOf(
        "tfc" to "the first chapter", "rotf" to "rise of the floodborn", "iti" to "into the inklands",
        "urs" to "ursula's return", "ssk" to "shimmering skies", "as" to "azurite sea", "ari" to "archazia's island",
        "roj" to "reign of jafar", "fab" to "fabled", "wiw" to "whispers in the well", "win" to "winterspell",
    )

    private fun normalizeSetName(set: String): String {
        val n = set.lowercase().trim().replace("’", "'").replace("‘", "'")
        return setAbbreviations[n] ?: n
    }

    private fun parseVariant(value: String): CardVariant {
        val lower = value.lowercase(Locale.US).trim()
        return when {
            "foil" in lower -> CardVariant.FOIL
            "enchanted" in lower -> CardVariant.ENCHANTED
            "promo" in lower -> CardVariant.PROMO
            else -> CardVariant.NORMAL
        }
    }
}
