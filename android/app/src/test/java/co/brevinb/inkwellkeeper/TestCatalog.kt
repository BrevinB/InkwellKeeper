package co.brevinb.inkwellkeeper

import co.brevinb.inkwellkeeper.data.CardJsonParser
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.LorcanaSet
import java.io.File

/** The real bundled catalog, read straight from the iOS Data folder for JVM tests. */
object TestCatalog {
    private val dataDir: File by lazy {
        generateSequence(File("").absoluteFile) { it.parentFile }
            .map { File(it, "Inkwell Keeper/Data") }
            .first { File(it, "sets.json").exists() }
    }

    val sets: List<LorcanaSet> by lazy {
        CardJsonParser.parseSets(File(dataDir, "sets.json").readText())
            .sortedWith(compareBy({ it.setNumber?.toIntOrNull() ?: Int.MAX_VALUE }, { it.releaseDate ?: "" }))
    }

    val cards: List<LorcanaCard> by lazy {
        sets.flatMap { set -> File(dataDir, "${set.id}.json").takeIf { it.exists() }?.let { CardJsonParser.parseSetCards(it.readText()) }.orEmpty() }
    }

    private fun normalize(text: String) = text.lowercase().replace("'", "").replace("-", " ").replace("  ", " ").trim()

    /** Same contract as `SetsDataManager.searchCards`: substring hits, word-prefix exact matches first. */
    fun search(query: String): List<LorcanaCard> {
        if (query.isBlank()) return emptyList()
        val q = normalize(query)
        fun exact(name: String): Boolean {
            val words = normalize(name).split(" ").filter { it.isNotEmpty() }
            return q.split(" ").filter { it.isNotEmpty() }.all { w -> words.any { it.startsWith(w) || it.contains(w) } }
        }
        return cards.filter { c ->
            listOf(c.name, c.cardText, c.type, c.setName).joinToString(" ") { normalize(it) }.contains(q) || exact(c.name)
        }.sortedWith(compareBy<LorcanaCard> { !exact(it.name) }.thenBy { normalize(it.name) })
    }
}
