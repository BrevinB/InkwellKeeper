package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.data.SpoilerSettings
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.QuantityStepper
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.coroutines.delay

/**
 * Put cards into a binder or box, from Unsorted copies or the whole catalog (catalog picks
 * that aren't unsorted are added to the collection as they're put away).
 */
@Composable
fun AddToContainerSheet(container: StorageContainer, onDismiss: () -> Unit) {
    val app = LocalApp.current
    var fromCatalog by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    val picks = remember { mutableStateMapOf<String, Pair<LorcanaCard, Int>>() }
    var catalogResults by remember { mutableStateOf<List<LorcanaCard>>(emptyList()) }

    val unsorted = app.storage.unsortedQuantitiesByIdentity()
    val unsortedCards = remember(app.collection.revision, app.storage.revision) {
        app.collection.collectedCards.filter { (unsorted[it.identityKey] ?: 0) > 0 }.distinctBy { it.identityKey }
    }
    LaunchedEffect(query, fromCatalog) {
        if (fromCatalog) {
            delay(200)
            val base = if (query.isBlank()) container.linkedSetName?.let { SetsDataManager.getCardsForSet(it) } ?: emptyList() else SetsDataManager.searchCards(query)
            catalogResults = SpoilerSettings.visibleCards(base).flatMap { c ->
                if (c.variant == CardVariant.NORMAL) listOf(c, c.withVariant(CardVariant.FOIL)) else listOf(c)
            }.take(200)
        }
    }
    val candidates = if (fromCatalog) catalogResults
    else unsortedCards.filter { query.isBlank() || it.name.contains(query, true) }

    FullScreenSheet(title = "Add to ${container.name}", onDismiss = onDismiss) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SegmentedPicker(listOf(false, true), fromCatalog, { fromCatalog = it }, { if (it) "All Cards" else "Unsorted" })
                SearchBar(query, { query = it }, placeholder = if (fromCatalog) "Search all cards..." else "Search unsorted cards...")
                app.storage.freeSpace(container)?.let { Text("$it free", style = MaterialTheme.typography.labelMedium, color = Color.Gray) }
            }
            LazyColumn(Modifier.weight(1f)) {
                items(candidates, key = { it.variantAwareId }) { card ->
                    val key = card.identityKey
                    val have = unsorted[key] ?: 0
                    val refusal = app.storage.refusal(card, container)
                    val picked = picks[key]?.second ?: 0
                    val max = if (fromCatalog) 99 else have
                    Row(
                        Modifier.fillMaxWidth().alpha(if (refusal != null) 0.5f else 1f).padding(horizontal = 16.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        CardImage(card, Modifier.size(44.dp, 62.dp).clip(RoundedCornerShape(6.dp)))
                        Column(Modifier.weight(1f)) {
                            Text(card.name, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(
                                refusal ?: listOfNotNull(card.setName, card.variant.displayName.takeIf { card.variant != CardVariant.NORMAL }, if (have > 0) "$have unsorted" else null).joinToString(" · "),
                                style = MaterialTheme.typography.labelSmall,
                                color = if (refusal != null) LorcanaGold else Color.Gray,
                            )
                        }
                        if (refusal == null) {
                            QuantityStepper(
                                picked,
                                { if (picked <= 1) picks.remove(key) else picks[key] = card to picked - 1 },
                                { if (picked < max) picks[key] = card to picked + 1 },
                                buttonSize = 28.dp,
                            )
                        }
                    }
                    HorizontalDivider(color = Color.White.copy(alpha = 0.05f))
                }
            }
            val total = picks.values.sumOf { it.second }
            val toAdd = picks.values.sumOf { (card, q) -> maxOf(0, q - (unsorted[card.identityKey] ?: 0)) }
            Column(Modifier.background(LorcanaDark.copy(alpha = 0.95f)).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (toAdd > 0) Text("$toAdd card${if (toAdd == 1) "" else "s"} will also be added to your collection.", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                LorcanaPrimaryButton(
                    onClick = {
                        app.storage.storeAddingToCollection(picks.values.toList(), container)
                        onDismiss()
                    },
                    enabled = total > 0,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(if (total > 0) "Put Away $total" else "Choose cards") }
            }
        }
    }
}
