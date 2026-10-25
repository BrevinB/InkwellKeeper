package co.brevinb.inkwellkeeper.transfer

import co.brevinb.inkwellkeeper.BuildConfig
import co.brevinb.inkwellkeeper.data.AppContainer
import co.brevinb.inkwellkeeper.data.CollectedCard
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.storage.StorageAllocation
import java.text.DateFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Collection exports: custom CSV, Dreamborn CSV, Lorcana HQ text, and JSON backup. */
object ExportService {
    enum class Format(val label: String, val description: String, val extension: String) {
        CUSTOM_CSV("Custom CSV", "Choose exactly which fields to export", "csv"),
        DREAMBORN("Dreamborn", "Set Number, Card Number, Variant, Count", "csv"),
        LORCANA_HQ("Lorcana HQ", "Quantity x Card Name - Subtitle (Set)", "csv"),
        JSON_BACKUP("JSON Backup", "Full data backup - can be restored later", "json"),
    }

    enum class Field(val label: String, val defaultOn: Boolean = false) {
        CARD_NAME("Card Name", true),
        SET_NAME("Set Name", true),
        CARD_NUMBER("Card Number", true),
        VARIANT("Variant", true),
        QUANTITY("Quantity", true),
        RARITY("Rarity"),
        INK_COLOR("Ink Color"),
        CARD_TYPE("Card Type"),
        COST("Cost"),
        STRENGTH("Strength"),
        WILLPOWER("Willpower"),
        LORE("Lore"),
        INKWELL("Inkable"),
        FRANCHISE("Franchise"),
        PRICE("Price"),
        UNIQUE_ID("Unique ID"),
        PURCHASE_PRICE("Purchase Price"),
        TOTAL_VALUE("Total Value"),
        GAIN_LOSS("Gain/Loss"),
        CONDITION("Condition"),
        NOTES("Notes"),
        DATE_ADDED("Date Added"),
        LOCATION("Location"),
    }

    private data class Entry(val card: LorcanaCard, val quantity: Int, val row: CollectedCard?)

    /** Groups rows by printing, enriching each with catalog stats the collection doesn't store. */
    private fun entries(rows: List<CollectedCard>): List<Entry> =
        rows.groupBy { "${it.name}|${it.setName}|${it.variant ?: "Normal"}" }.values.map { group ->
            val row = group.first()
            val snapshot = row.toLorcanaCard()
            val catalog = SetsDataManager.catalogCard(snapshot)
            val card = if (catalog != null) snapshot.copy(
                strength = catalog.strength, willpower = catalog.willpower, lore = catalog.lore,
                inkwell = catalog.inkwell, franchise = catalog.franchise, cardText = catalog.cardText,
            ) else snapshot
            Entry(card, group.sumOf { it.quantity }, row)
        }

    fun generate(format: Format, rows: List<CollectedCard>, fields: Set<Field>, app: AppContainer): String = when (format) {
        Format.CUSTOM_CSV -> customCsv(entries(rows), fields, app)
        Format.DREAMBORN -> dreambornCsv(entries(rows).map { it.card to it.quantity })
        Format.LORCANA_HQ -> lorcanaHq(entries(rows))
        Format.JSON_BACKUP -> jsonBackup(entries(rows), app)
    }

    private fun q(value: String) = "\"${value.replace("\"", "\"\"")}\""
    private fun money(value: Double) = String.format(Locale.US, "%.2f", value)

    private fun customCsv(entries: List<Entry>, fields: Set<Field>, app: AppContainer): String {
        val ordered = Field.entries.filter { it in fields }
        val sb = StringBuilder(ordered.joinToString(",") { it.label }).append('\n')
        val sorted = entries.sortedWith(compareBy<Entry>({ it.card.setName }, { it.card.cardNumber ?: Int.MAX_VALUE }, { it.card.name }))
        for (e in sorted) {
            sb.append(ordered.joinToString(",") { field -> value(field, e, app) }).append('\n')
        }
        return sb.toString()
    }

    private fun value(field: Field, e: Entry, app: AppContainer): String {
        val card = e.card
        return when (field) {
            Field.CARD_NAME -> q(card.name)
            Field.SET_NAME -> q(card.setName)
            Field.CARD_NUMBER -> card.cardNumber?.toString() ?: card.uniqueId?.split("-")?.getOrNull(1)?.toIntOrNull()?.toString() ?: ""
            Field.VARIANT -> q(card.variant.displayName)
            Field.QUANTITY -> "${e.quantity}"
            Field.RARITY -> q(card.rarity.rawValue)
            Field.INK_COLOR -> q(card.inkColor ?: "")
            Field.CARD_TYPE -> q(card.type)
            Field.COST -> "${card.cost}"
            Field.STRENGTH -> card.strength?.toString() ?: ""
            Field.WILLPOWER -> card.willpower?.toString() ?: ""
            Field.LORE -> card.lore?.toString() ?: ""
            Field.INKWELL -> card.inkwell?.let { if (it) "Yes" else "No" } ?: ""
            Field.FRANCHISE -> q(card.franchise ?: "")
            Field.PRICE -> card.price?.let(::money) ?: ""
            Field.UNIQUE_ID -> q(card.uniqueId ?: "")
            Field.PURCHASE_PRICE -> e.row?.purchasePrice?.let(::money) ?: ""
            Field.TOTAL_VALUE -> card.price?.let { money(it * e.quantity) } ?: ""
            // Blank, not zero, when either side is unknown.
            Field.GAIN_LOSS -> {
                val paid = e.row?.purchasePrice
                val price = card.price
                if (paid != null && price != null) money((price - paid) * e.quantity) else ""
            }
            Field.CONDITION -> q(e.row?.condition ?: "")
            Field.NOTES -> q(e.row?.notes ?: "")
            Field.DATE_ADDED -> e.row?.let { q(DateFormat.getDateInstance(DateFormat.SHORT).format(Date(it.dateAdded))) } ?: ""
            Field.LOCATION -> q(describeLocations(app.storage.locations(card), e.quantity))
        }
    }

    /** "Main Binder p.3, pocket 5; Unsorted ×1". */
    fun describeLocations(locations: List<StorageAllocation>, owned: Int): String {
        val parts = locations.map { loc -> loc.containerName + (loc.pocketSummary?.let { " $it" } ?: if (loc.quantity > 1) " ×${loc.quantity}" else "") }
        val unsorted = owned - locations.sumOf { it.quantity }
        return (parts + if (unsorted > 0) listOf("Unsorted ×$unsorted") else emptyList()).joinToString("; ")
    }

    /**
     * Canonical 7-column Dreamborn CSV. Special printings are `foil` rows at their own numbers;
     * cards without a set number or card number are skipped.
     */
    fun dreambornCsv(entries: List<Pair<LorcanaCard, Int>>): String {
        val setNumbers = SetsDataManager.sets.mapNotNull { set ->
            set.setNumber?.takeIf { it.isNotEmpty() }?.let { n -> set.name to (n.toIntOrNull()?.let { String.format(Locale.US, "%03d", it) } ?: n) }
        }.toMap()
        val seen = mutableSetOf<String>()
        val rows = entries.mapNotNull { (card, quantity) ->
            if (quantity <= 0) return@mapNotNull null
            val setNumber = setNumbers[card.setName] ?: return@mapNotNull null
            val number = card.cardNumber ?: return@mapNotNull null
            if (!seen.add("${card.setName}|$number|${card.variant.rawValue}")) return@mapNotNull null
            val variant = when (card.variant) {
                CardVariant.FOIL, CardVariant.ENCHANTED, CardVariant.EPIC, CardVariant.ICONIC -> "foil"
                else -> "normal"
            }
            Triple(setNumber, number, "$setNumber,$number,$variant,$quantity,${card.name},${card.inkColor ?: ""},${card.rarity.rawValue}")
        }.sortedWith(compareBy({ it.first }, { it.second }))
        return "Set Number,Card Number,Variant,Count,Name,Color,Rarity\n" + rows.joinToString("\n") { it.third } + if (rows.isEmpty()) "" else "\n"
    }

    private fun lorcanaHq(entries: List<Entry>): String =
        entries.sortedWith(compareBy({ it.card.setName }, { it.card.name })).joinToString("\n") { e ->
            val variant = if (e.card.variant != CardVariant.NORMAL) " [${e.card.variant.displayName}]" else ""
            "${e.quantity}x ${e.card.name} (${e.card.setName})$variant"
        }

    private fun jsonBackup(entries: List<Entry>, app: AppContainer): String {
        val iso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssZ", Locale.US)
        val cards = entries.map { e ->
            val c = e.card
            InkwellBackup.Card(
                id = c.id, name = c.name, setName = c.setName, cardNumber = c.cardNumber, uniqueId = c.uniqueId,
                variant = c.variant.rawValue, quantity = e.quantity, rarity = c.rarity.rawValue, inkColor = c.inkColor,
                cardType = c.type, cost = c.cost, strength = c.strength, willpower = c.willpower, lore = c.lore,
                inkwell = c.inkwell, franchise = c.franchise, price = c.price, condition = e.row?.condition,
                notes = e.row?.notes, dateAdded = e.row?.let { iso.format(Date(it.dateAdded)) }, imageUrl = c.imageUrl,
            )
        }.sortedWith(compareBy({ it.setName }, { it.name }))
        val backup = InkwellBackup(
            exportDate = iso.format(Date()),
            appVersion = BuildConfig.VERSION_NAME,
            totalCards = cards.size,
            totalQuantity = cards.sumOf { it.quantity },
            cards = cards,
            // Binders and boxes always go in whole so a restore can put every card back.
            storage = app.storage.containers.map { InkwellBackup.Container.from(it) },
        )
        return InkwellBackup.encode(backup)
    }
}
