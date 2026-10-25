package co.brevinb.inkwellkeeper.ui.decks

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class StarterDeck(
    val id: String,
    val name: String,
    val setName: String,
    val inkColors: List<String> = emptyList(),
    val description: String = "",
    val format: String = "Infinity Constructed",
    val cards: List<Entry> = emptyList(),
) {
    @Serializable
    data class Entry(val name: String, val quantity: Int)

    val totalCards: Int get() = cards.sumOf { it.quantity }
}

@Serializable
private data class StarterDecksData(val starterDecks: List<StarterDeck> = emptyList())

private fun loadStarterDecks(context: Context): List<StarterDeck> = runCatching {
    val text = context.assets.open("starter_decks.json").bufferedReader().use { it.readText() }
    Json { ignoreUnknownKeys = true }.decodeFromString(StarterDecksData.serializer(), text).starterDecks
}.getOrDefault(emptyList())

/** Import an official starter deck as a deck, into the collection, or both. */
@Composable
fun StarterDecksScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val context = LocalContext.current
    val decks = remember { loadStarterDecks(context) }
    var importing by remember { mutableStateOf<StarterDeck?>(null) }
    var result by remember { mutableStateOf<String?>(null) }

    fun import(deck: StarterDeck, asDeck: Boolean, toCollection: Boolean) {
        val unmatched = mutableListOf<String>()
        val created = if (asDeck) app.decks.createDeck(deck.name, deck.description, DeckFormat.fromRaw(deck.format) ?: DeckFormat.INFINITY_CONSTRUCTED, deck.inkColors.mapNotNull { InkColor.fromString(it) }) else null
        var added = 0
        for (entry in deck.cards) {
            val card = SetsDataManager.searchCards(entry.name).firstOrNull { it.name == entry.name }
            if (card == null) { unmatched += entry.name; continue }
            created?.let { app.decks.addCard(card, it, entry.quantity) }
            if (toCollection) {
                app.collection.addCard(card, entry.quantity, bulkImport = true, source = "starterDeck")
                added += entry.quantity
            }
        }
        if (toCollection) app.collection.finalizeBulkImport()
        Analytics.send("starterDeck.imported", mapOf("name" to deck.name))
        result = buildString {
            if (created != null) append("\"${deck.name}\" has been added to your decks.\n")
            if (added > 0) append("$added cards added to your collection.\n")
            if (unmatched.isNotEmpty()) append("\nSome cards weren't found and were skipped:\n" + unmatched.joinToString("\n") { "• $it" })
        }
    }

    InkwellScaffold("Starter Decks", showBack = true) { padding ->
        LazyColumn(Modifier.padding(padding).fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text("Import official starter decks into your collection", color = Color.Gray) }
            items(decks, key = { it.id }) { deck ->
                Column(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f))
                        .border(1.dp, LorcanaGold.copy(alpha = 0.3f), RoundedCornerShape(12.dp)).clickable { importing = deck }.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(deck.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = Color.White)
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        deck.inkColors.mapNotNull { InkColor.fromString(it) }.forEach { InkChip(it) }
                        Text("${deck.totalCards} cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                    Text(deck.description, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                    Text("Import", style = MaterialTheme.typography.labelLarge, color = LorcanaGold)
                }
            }
        }
    }

    importing?.let { deck ->
        AlertDialog(
            onDismissRequest = { importing = null },
            title = { Text("Import \"${deck.name}\"") },
            text = {
                Column {
                    Text("${deck.totalCards} cards")
                    listOf(Triple("Deck Only", true, false), Triple("Collection Only", false, true), Triple("Both", true, true)).forEach { (label, asDeck, toCollection) ->
                        TextButton(onClick = { importing = null; import(deck, asDeck, toCollection) }, Modifier.fillMaxWidth()) { Text(label, Modifier.fillMaxWidth(), color = LorcanaGold) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { importing = null }) { Text("Cancel") } },
        )
    }
    result?.let {
        AlertDialog(
            onDismissRequest = { result = null },
            title = { Text("Imported") },
            text = { Text(it) },
            confirmButton = { TextButton(onClick = { result = null; nav.navigate(Routes.DECKS) { popUpTo(Routes.DECKS) } }) { Text("Done") } },
        )
    }
}
