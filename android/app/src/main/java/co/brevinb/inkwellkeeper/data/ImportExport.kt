package co.brevinb.inkwellkeeper.data

import co.brevinb.inkwellkeeper.model.Card
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.normalizedCardName
import co.brevinb.inkwellkeeper.model.Deck
import co.brevinb.inkwellkeeper.model.withVariant
import java.util.UUID

data class ImportReport(val imported: Int, val unmatched: List<String>)

object ImportExport {
    data class DeckImport(val deck: Deck?, val unmatched: List<String>)

    fun exportDreamborn(cards: List<Card>, quantities: Map<String, Int>): String {
        val body = cards.mapNotNull { card ->
            val count = quantities[card.id] ?: 0
            val number = card.cardNumber ?: return@mapNotNull null
            if (count <= 0) return@mapNotNull null
            val variant = if (card.variant in listOf(CardVariant.Foil, CardVariant.Enchanted, CardVariant.Epic, CardVariant.Iconic)) "foil" else "normal"
            "${card.setNumber ?: card.setCode},$number,$variant,$count,${csv(card.name)},${card.inkColor.orEmpty()},${csv(card.rarity)}"
        }.sortedWith(compareBy({ it.substringBefore(',') }, { it.substringAfter(',').substringBefore(',').toIntOrNull() ?: 0 }))
        return "Set Number,Card Number,Variant,Count,Name,Color,Rarity\n" + body.joinToString("\n") + if (body.isEmpty()) "" else "\n"
    }

    fun exportTextList(cards: List<Card>, quantities: Map<String, Int>): String = cards.mapNotNull { card ->
        val count = quantities[card.id] ?: 0
        if (count > 0) "$count ${card.name}" else null
    }.joinToString("\n")

    fun exportDeckText(deck: Deck, cards: List<Card>): String {
        val byId = cards.associateBy { it.id }
        val lines = mutableListOf("# Deck: ${deck.name}", "# Format: ${deck.format}")
        deck.cardQuantities.entries
            .mapNotNull { (id, quantity) -> byId[id]?.let { card -> quantity to card } }
            .sortedWith(compareBy({ it.second.cost }, { it.second.name }))
            .forEach { (quantity, card) -> lines += "$quantity ${card.name}" }
        return lines.joinToString("\n")
    }

    fun importDeck(text: String, cards: List<Card>): DeckImport {
        val name = text.lineSequence().firstOrNull { it.trim().startsWith("# Deck:", ignoreCase = true) }
            ?.substringAfter(":")?.trim().orEmpty().ifBlank { "Imported Deck" }
        val format = text.lineSequence().firstOrNull { it.trim().startsWith("# Format:", ignoreCase = true) }
            ?.substringAfter(":")?.trim().orEmpty().ifBlank { "Infinity Constructed" }
        val (quantities, report) = import(text, cards)
        return DeckImport(
            deck = if (quantities.isEmpty()) null else Deck(UUID.randomUUID().toString(), name, format, quantities),
            unmatched = report.unmatched
        )
    }

    fun import(text: String, cards: List<Card>): Pair<Map<String, Int>, ImportReport> {
        val normalCards = cards.filter { it.variant == CardVariant.Normal }
        val byName = normalCards.associateBy { it.name.normalizedCardName() }
        val byUniqueId = normalCards.mapNotNull { it.uniqueId?.uppercase()?.let { key -> key to it } }.toMap()
        val specialByName = cards.filter { it.variant != CardVariant.Normal }
            .associateBy { it.name.normalizedCardName() }
        val quantities = linkedMapOf<String, Int>()
        val unmatched = mutableListOf<String>()
        text.lines().forEachIndexed { index, raw ->
            val line = raw.trim()
            if (line.isBlank() || line.startsWith("#") || (index == 0 && line.lowercase().contains("card"))) return@forEachIndexed
            val csv = line.splitCsv()
            val parsed = if (csv.size >= 5 && csv[0].toIntOrNull() != null) {
                val count = csv[3].toIntOrNull() ?: 1
                val set = csv[0]; val number = csv[1].toIntOrNull()
                val id = if (number != null) "$set-${number.toString().padStart(3, '0')}" else ""
                val variant = csv.getOrNull(2)?.lowercase()
                val direct = byUniqueId[id.uppercase()]
                val named = if (variant == "foil") {
                    specialByName[csv[4].normalizedCardName()] ?: byName[csv[4].normalizedCardName()]?.withVariant(CardVariant.Foil)
                } else null
                Triple(count, csv[4], named ?: direct)
            } else {
                val match = Regex("^(\\d{1,3})\\s*[xX]?\\s+(.+)$").find(line)
                if (match == null) null else Triple(match.groupValues[1].toInt(), match.groupValues[2], null)
            } ?: run { unmatched += line; return@forEachIndexed }
            val card = parsed.third ?: byName[parsed.second.normalizedCardName()]
            if (card == null) unmatched += line else quantities[card.id] = (quantities[card.id] ?: 0) + parsed.first
        }
        return quantities to ImportReport(quantities.values.sum(), unmatched)
    }

    private fun csv(value: String) = if (value.contains(',') || value.contains('"')) "\"${value.replace("\"", "\"\"")}\"" else value

    private fun String.splitCsv(): List<String> {
        val result = mutableListOf<String>(); val current = StringBuilder(); var quoted = false
        for (char in this) when {
            char == '"' -> quoted = !quoted
            char == ',' && !quoted -> { result += current.toString().trim(); current.clear() }
            else -> current.append(char)
        }
        result += current.toString().trim(); return result
    }
}
