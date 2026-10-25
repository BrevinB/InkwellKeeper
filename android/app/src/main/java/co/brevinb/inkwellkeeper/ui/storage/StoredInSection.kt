package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MoveToInbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.StepperRow
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.delay

/** "Where is it?" on a card's detail: each container holding copies, unsorted copies, Put Away. */
@Composable
fun StoredInSection(card: LorcanaCard, modifier: Modifier = Modifier) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val locations = app.storage.locations(card)
    val unsorted = app.storage.unsortedQuantity(card)
    var showingPutAway by remember { mutableStateOf(false) }
    if (locations.isEmpty() && unsorted == 0) return

    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (card.variant == CardVariant.FOIL) "Stored In (Foil)" else "Stored In", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
            Spacer(Modifier.weight(1f))
            if (unsorted > 0) {
                TextButton(onClick = { showingPutAway = true }) {
                    Icon(Icons.Filled.MoveToInbox, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                    Text(" Put Away", color = LorcanaGold)
                }
            }
        }
        for (location in locations) {
            val container = app.storage.container(location.containerId) ?: continue
            val deckName = container.linkedDeckId?.let { app.storage.deckName(it) }
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).clickable { nav.navigate(Routes.container(container.id)) }.padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                ContainerArtwork(container.kind, container.coverColor, container.cover, Modifier.height(28.dp).width(28.dp))
                Column(Modifier.weight(1f)) {
                    Text(container.name, style = MaterialTheme.typography.bodyMedium, color = Color.White)
                    val detail = listOfNotNull(location.pocketSummary, deckName?.let { "Deck: $it" }).joinToString(" · ")
                    if (detail.isNotEmpty()) Text(detail, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
                Text("×${location.quantity}", style = MaterialTheme.typography.bodyMedium, color = Color.White)
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
            }
        }
        if (unsorted > 0) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Inventory2, null, tint = Color.Gray, modifier = Modifier.width(28.dp))
                Text("Unsorted", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, modifier = Modifier.weight(1f))
                Text("×$unsorted", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            }
        }
    }

    if (showingPutAway) PutAwaySheet(card, onDismiss = { showingPutAway = false })
}

/** Put unsorted copies of one card into a binder or box. */
@Composable
fun PutAwaySheet(card: LorcanaCard, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val unsorted = app.storage.unsortedQuantity(card)
    var quantity by remember { mutableIntStateOf(1) }
    var storedInto by remember { mutableStateOf<String?>(null) }
    var showingCreate by remember { mutableStateOf(false) }

    LaunchedEffect(storedInto) {
        if (storedInto != null) {
            delay(650)
            onDismiss()
        }
    }

    FullScreenSheet(title = "Put Away", onDismiss = onDismiss) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            FormSection {
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    CardImage(card, Modifier.width(56.dp).clip(RoundedCornerShape(6.dp)))
                    Column {
                        Text(card.name, style = MaterialTheme.typography.titleMedium, color = Color.White)
                        Text("$unsorted unsorted ${if (unsorted == 1) "copy" else "copies"}", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
                    }
                }
                if (unsorted > 1) StepperRow("Put away", quantity, 1..unsorted, onValueChange = { quantity = it })
            }
            FormSection("Put into") {
                for (container in app.storage.containers) {
                    val canUpgrade = app.storage.upgradeTarget(card, container) != null
                    val refusal = if (canUpgrade) null else app.storage.refusal(card, container)
                    PutAwayRow(
                        container = container,
                        chosen = storedInto == container.id,
                        freeSpace = app.storage.freeSpace(container),
                        refusal = if (storedInto == container.id) null else refusal,
                        note = if (canUpgrade && storedInto == null) "Upgrade to foil · the normal copy goes to Unsorted" else null,
                        enabled = storedInto == null && refusal == null,
                    ) {
                        if (canUpgrade) {
                            if (app.storage.upgradeToFoil(card, container)) storedInto = container.id
                        } else if (app.storage.store(card, quantity, container) > 0) {
                            storedInto = container.id
                        }
                    }
                }
                TextButton(onClick = { if (app.storage.canCreateContainer(AppSettings.isProUnlocked)) showingCreate = true }) {
                    Icon(Icons.Filled.Add, null, tint = LorcanaGold)
                    Text(" New Binder or Box", color = LorcanaGold)
                }
            }
        }
    }
    if (showingCreate) ContainerEditorSheet(null, onDismiss = { showingCreate = false })
}

@Composable
fun PutAwayRow(
    container: StorageContainer,
    chosen: Boolean,
    freeSpace: Int?,
    refusal: String?,
    note: String?,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp))
            .background(if (chosen) SystemColors.green.copy(alpha = 0.15f) else Color.Transparent)
            .clickable(enabled = enabled, onClick = onClick).padding(vertical = 6.dp, horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        ContainerArtwork(container.kind, container.coverColor, container.cover, Modifier.height(36.dp))
        Column(Modifier.weight(1f)) {
            Text(container.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = if (refusal != null) Color.Gray else Color.White)
            val detail = refusal ?: note ?: freeSpace?.let { "$it free" } ?: "${container.cardCount} cards"
            Text(detail, style = MaterialTheme.typography.labelSmall, color = if (note != null) LorcanaGold else Color.Gray)
        }
        if (chosen) Icon(Icons.Filled.CheckCircle, contentDescription = "Stored", tint = SystemColors.green)
    }
}
