package co.brevinb.inkwellkeeper.ui.scan

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.scan.ScanSession
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.QuantityStepper
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.share.HaulShareSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.delay

/** Review the tray, fix mis-scans, then add everything (optionally straight into a binder or box). */
@Composable
fun ScanReviewSheet(session: ScanSession, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val nav = LocalNav.current
    var addedCount by remember { mutableStateOf<Int?>(null) }
    var putAway by remember { mutableStateOf<Triple<String, Int, Int>?>(null) }
    var correctingIndex by remember { mutableStateOf<Int?>(null) }
    var sharing by remember { mutableStateOf(false) }
    val isPro = AppSettings.isProUnlocked
    val chosen: StorageContainer? = if (isPro) app.storage.container(AppSettings.scanDestinationContainerId) else null
    val destination = chosen?.takeIf { !app.storage.isFull(it) }

    fun finish() {
        session.clear()
        onDismiss()
    }

    FullScreenSheet(
        title = "Scanned Cards",
        onDismiss = { if (addedCount != null) finish() else onDismiss() },
        dismissLabel = "Back",
        trailingActions = {
            if (session.scannedCards.isNotEmpty() && addedCount == null) TextButton(onClick = { session.clear() }) { Text("Clear All", color = LorcanaGold) }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            if (session.scannedCards.isEmpty() && addedCount == null) {
                EmptyState(Icons.Filled.Layers, "No Cards Scanned Yet", "Go back and scan some cards!")
                return@Column
            }
            LazyColumn(Modifier.weight(1f), contentPadding = PaddingValues(vertical = 8.dp)) {
                itemsIndexed(session.scannedCards, key = { _, e -> e.id }) { index, entry ->
                    Row(
                        Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.05f)).padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CardImage(entry.card, Modifier.size(50.dp, 70.dp).clip(RoundedCornerShape(6.dp)))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(entry.card.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(entry.card.setName + (entry.card.cardNumber?.let { " · #$it" } ?: ""), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                            if (addedCount == null) {
                                if (!entry.card.variant.isSpecialPrinting || entry.variant == CardVariant.FOIL) {
                                    SegmentedPicker(listOf(CardVariant.NORMAL, CardVariant.FOIL), entry.variant, { session.setVariant(index, it) }, { it.displayName }, Modifier.width(160.dp))
                                } else {
                                    RarityBadge(entry.card.rarity)
                                }
                                Row(Modifier.clickable { correctingIndex = index }, verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Filled.SwapHoriz, null, tint = LorcanaGold, modifier = Modifier.size(14.dp))
                                    Text(" Wrong card?", style = MaterialTheme.typography.labelSmall, color = LorcanaGold)
                                }
                            }
                        }
                        if (addedCount == null) {
                            Column(horizontalAlignment = Alignment.End) {
                                QuantityStepper(entry.quantity, { session.setQuantity(index, entry.quantity - 1) }, { session.setQuantity(index, entry.quantity + 1) }, buttonSize = 28.dp)
                                IconButton(onClick = { session.remove(index) }) { Icon(Icons.Filled.Delete, "Remove ${entry.card.name}", tint = SystemColors.red) }
                            }
                        } else {
                            Text("×${entry.quantity}", color = Color.White)
                        }
                    }
                    HorizontalDivider(color = Color.White.copy(alpha = 0.05f))
                }
            }
            Column(Modifier.background(LorcanaDark.copy(alpha = 0.95f)).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (addedCount == null) {
                    Row {
                        Text("${session.scannedCards.size} unique cards", color = Color.Gray, modifier = Modifier.weight(1f))
                        Text("${session.totalCount} total", color = Color.Gray)
                    }
                    if (app.storage.containers.isNotEmpty()) {
                        if (isPro) {
                            MenuPickerRow(
                                "Put into",
                                listOf<String?>(null) + app.storage.containers.map { it.id },
                                chosen?.id,
                                { AppSettings.updateScanDestination(it ?: "") },
                                { id -> id?.let { app.storage.container(it) }?.let { c -> c.name + if (app.storage.isFull(c)) " (Full)" else "" } ?: "Unsorted" },
                            )
                        } else {
                            Text("Pro: scan straight into a binder or box", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                        }
                    }
                    LorcanaPrimaryButton(
                        onClick = {
                            val count = session.totalCount
                            for (entry in session.scannedCards) app.collection.addCard(entry.card, entry.quantity, bulkImport = true, source = "scan")
                            app.collection.finalizeBulkImport()
                            if (destination != null) {
                                val stored = session.scannedCards.sumOf { app.storage.store(it.card, it.quantity, destination, source = "scan") }
                                putAway = Triple(destination.name, stored, maxOf(0, count - stored))
                            }
                            Analytics.send("scan.multiConfirmed", mapOf("count" to "${session.scannedCards.size}"))
                            addedCount = count
                        },
                        enabled = session.scannedCards.isNotEmpty(),
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(destination?.let { "Add & Put Into ${it.name}" } ?: "Add All to Collection") }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, null, tint = SystemColors.green)
                        Text("  $addedCount cards added to your collection!", color = Color.White, fontWeight = FontWeight.SemiBold)
                    }
                    putAway?.let { (name, stored, left) ->
                        Text("$stored put into $name" + if (left > 0) " · $left left in Unsorted (no room)" else "", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                    }
                    Text("Would you like to export these cards?", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        LorcanaSecondaryButton(onClick = { finish() }, modifier = Modifier.weight(1f)) { Text("Done") }
                        LorcanaPrimaryButton(onClick = { finish(); nav.navigate(Routes.EXPORT) }, modifier = Modifier.weight(1f)) { Text("Export") }
                    }
                    TextButton(onClick = { sharing = true }, modifier = Modifier.align(Alignment.CenterHorizontally)) {
                        Icon(Icons.Filled.IosShare, null, tint = LorcanaGold)
                        Text("  Share Your Haul", color = LorcanaGold)
                    }
                }
            }
        }
    }

    correctingIndex?.let { index ->
        CardPickerSheet("Correct Card", onDismiss = { correctingIndex = null }) {
            session.replace(index, it)
            correctingIndex = null
        }
    }
    if (sharing) HaulShareSheet(session.scannedCards.toList()) { sharing = false }
}

/** Search the catalog and pick one printing (scan corrections, trade pickers). */
@Composable
fun CardPickerSheet(title: String, onDismiss: () -> Unit, onSelect: (LorcanaCard) -> Unit) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<LorcanaCard>>(emptyList()) }
    LaunchedEffect(query) {
        delay(200)
        results = SetsDataManager.searchCards(query).take(100)
    }
    FullScreenSheet(title = title, onDismiss = onDismiss) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            SearchBar(query, { query = it }, Modifier.padding(16.dp), placeholder = "Search for the correct card")
            LazyColumn {
                items(results, key = { it.variantAwareId }) { card ->
                    Row(
                        Modifier.fillMaxWidth().clickable { onSelect(card) }.padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CardImage(card, Modifier.size(44.dp, 62.dp).clip(RoundedCornerShape(6.dp)))
                        Column(Modifier.weight(1f)) {
                            Text(card.name, color = Color.White, maxLines = 2)
                            Text("${card.setName}${card.cardNumber?.let { " · #$it" } ?: ""} · ${card.variant.displayName}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                        }
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
                    }
                }
            }
        }
    }
}

/** A reprint whose set the scanner couldn't read: the collector picks the printing. */
@Composable
fun SetPickerSheet(cards: List<LorcanaCard>, onSelect: (LorcanaCard) -> Unit, onCancel: () -> Unit) {
    val first = cards.first()
    AlertDialog(
        onDismissRequest = onCancel,
        title = { Text(first.name) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("This card appears in multiple sets. Which set is this copy from?", style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.size(4.dp))
                cards.forEach { card ->
                    Row(Modifier.fillMaxWidth().clickable { onSelect(card) }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                        CardImage(card, Modifier.size(32.dp, 45.dp).clip(RoundedCornerShape(4.dp)))
                        Column(Modifier.padding(start = 10.dp).weight(1f)) {
                            Text(card.setName)
                            card.cardNumber?.let { Text("Card #$it", style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onCancel) { Text("Cancel") } },
    )
}
