package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

@Composable
fun DecksScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    var showingCreate by remember { mutableStateOf(false) }
    var showingImport by remember { mutableStateOf(false) }
    val decks = app.decks.decks

    InkwellScaffold(
        title = "Decks",
        large = true,
        actions = {
            TextButton(onClick = { nav.navigate(Routes.STARTER_DECKS) }) {
                Icon(Icons.Filled.Layers, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                Text(" Starter", color = LorcanaGold, style = MaterialTheme.typography.labelMedium)
            }
            IconButton(onClick = { showingImport = true }) { Icon(Icons.Filled.Download, contentDescription = "Import deck") }
            IconButton(onClick = { nav.navigate(Routes.AI_DECK_BUILDER) }) { Icon(Icons.Filled.AutoAwesome, contentDescription = "AI deck builder") }
            IconButton(onClick = { showingCreate = true }) { Icon(Icons.Filled.Add, contentDescription = "Create deck") }
        },
    ) { padding ->
        if (decks.isEmpty()) {
            EmptyDecks(
                Modifier.padding(padding),
                onCreate = { showingCreate = true },
                onAi = { nav.navigate(Routes.AI_DECK_BUILDER) },
                onStarter = { nav.navigate(Routes.STARTER_DECKS) },
            )
        } else {
            LazyVerticalGrid(
                columns = GridCells.Adaptive(340.dp),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier.padding(padding).fillMaxSize(),
            ) {
                if (!AppSettings.hasSeenDeckIdeasNotice) {
                    item(span = { GridItemSpan(maxLineSpan) }) { DeckIdeasNotice { AppSettings.markDeckIdeasNoticeSeen() } }
                }
                items(decks, key = { it.id }) { deck -> DeckRow(deck) { nav.navigate(Routes.deck(deck.id)) } }
            }
        }
    }

    if (showingCreate) NewDeckSheet(onDismiss = { showingCreate = false }, onCreated = { nav.navigate(Routes.deck(it.id)) })
    if (showingImport) ImportDeckSheet(onDismiss = { showingImport = false }, onImported = { nav.navigate(Routes.deck(it.id)) })
}

@Composable
private fun EmptyDecks(modifier: Modifier, onCreate: () -> Unit, onAi: () -> Unit, onStarter: () -> Unit) {
    Column(
        modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterVertically),
    ) {
        Icon(Icons.Filled.ViewCarousel, null, tint = LorcanaGold.copy(alpha = 0.5f), modifier = Modifier.size(72.dp))
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Build Your First Deck", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
            Text("Create competitive decks and track\nwhich cards you need to complete them", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center)
        }
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            LorcanaPrimaryButton(onClick = onCreate, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.AddCircle, null)
                Spacer(Modifier.width(8.dp))
                Text("Create Deck")
            }
            LorcanaPrimaryButton(onClick = onAi, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.AutoAwesome, null)
                Spacer(Modifier.width(8.dp))
                Text("AI Deck Builder")
            }
            LorcanaSecondaryButton(onClick = onStarter, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.Layers, null)
                Spacer(Modifier.width(8.dp))
                Text("Import Starter Deck")
            }
        }
    }
}

@Composable
fun DeckIdeasNotice(onDismiss: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(LorcanaDark.copy(alpha = 0.9f))
            .border(1.dp, LorcanaGold.copy(alpha = 0.4f), RoundedCornerShape(14.dp)).padding(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.Inventory2, null, tint = LorcanaGold)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Decks are ideas until you build them", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = Color.White)
            Text(
                "Experiment freely — idea decks don't tie up your cards. When you sleeve one up, tap Build to give it a deck box and get a pull list of where every card is.",
                style = MaterialTheme.typography.labelMedium, color = Color.Gray,
            )
        }
        IconButton(onClick = onDismiss, modifier = Modifier.size(24.dp)) { Icon(Icons.Filled.Close, "Dismiss", tint = Color.Gray) }
    }
}

@Composable
private fun DeckRow(deck: Deck, onClick: () -> Unit) {
    val app = LocalApp.current
    app.decks.revision
    val stats = app.decks.statistics(deck, app.collection)
    val validation = app.decks.validateDeck(deck)
    val box = app.storage.deckBox(deck.id)
    val shape = RoundedCornerShape(12.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape).background(LorcanaDark.copy(alpha = 0.8f))
            .border(if (validation.isValid) 1.dp else 2.dp, if (validation.isValid) LorcanaGold.copy(alpha = 0.3f) else SystemColors.orange.copy(alpha = 0.5f), shape)
            .clickable(onClick = onClick).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(deck.name, style = MaterialTheme.typography.titleMedium, color = Color.White)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(deck.deckFormat.rawValue, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    if (box != null) {
                        Row(
                            Modifier.clip(RoundedCornerShape(50)).background(box.coverColor.highlight).padding(horizontal = 6.dp, vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(Icons.Filled.Inventory2, null, tint = LorcanaDark, modifier = Modifier.size(10.dp))
                            Text(" Built", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = LorcanaDark)
                        }
                    }
                }
            }
            when {
                !validation.isValid -> Icon(Icons.Filled.Warning, "Invalid deck", tint = SystemColors.orange)
                validation.warnings.isNotEmpty() -> Icon(Icons.Filled.Error, "Deck has warnings", tint = SystemColors.yellow)
                else -> Icon(Icons.Filled.CheckCircle, "Valid deck", tint = SystemColors.green)
            }
        }
        if (deck.deckInkColors.isNotEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                deck.deckInkColors.forEach { InkChip(it) }
                deck.deckArchetype?.let {
                    Text(
                        it.rawValue, style = MaterialTheme.typography.labelSmall, color = LorcanaGold,
                        modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(LorcanaGold.copy(alpha = 0.2f)).padding(horizontal = 8.dp, vertical = 4.dp),
                    )
                }
            }
        }
        HorizontalDivider(color = Color.Gray.copy(alpha = 0.3f))
        Row(horizontalArrangement = Arrangement.spacedBy(20.dp), verticalAlignment = Alignment.CenterVertically) {
            MiniStat("Cards", "${stats.totalCards}", if (stats.totalCards >= 60) Color.White else SystemColors.orange)
            MiniStat("Complete", "${stats.completionPercentage.toInt()}%", if (stats.completionPercentage >= 100) SystemColors.green else LorcanaGold)
            if (stats.missingCards > 0) MiniStat("Missing", "${stats.missingCards}", SystemColors.orange)
            Spacer(Modifier.weight(1f))
            if (stats.costToComplete > 0) MiniStat("Cost", PricingService.formatPrice(stats.costToComplete), LorcanaGold, end = true)
        }
    }
}

@Composable
private fun MiniStat(label: String, value: String, color: Color, end: Boolean = false) {
    Column(horizontalAlignment = if (end) Alignment.End else Alignment.Start, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        Text(value, style = MaterialTheme.typography.titleMedium, color = color)
    }
}
