package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddBox
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.MoveToInbox
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.storage.DeckPullPlan
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.storage.StorageCoverColor
import co.brevinb.inkwellkeeper.storage.StorageCoverStyle
import co.brevinb.inkwellkeeper.storage.StorageKind
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** Turns an idea deck into a built one: pick its deck box, then pull the cards. */
@Composable
fun BuildDeckSheet(deck: Deck, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val box = app.storage.deckBox(deck.id)
    FullScreenSheet(title = if (box == null) "Build Deck" else deck.name, onDismiss = onDismiss, dismissLabel = "Done") { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            if (box == null) DeckBoxChooser(deck) else DeckPullList(deck, box)
        }
    }
}

@Composable
private fun DeckBoxChooser(deck: Deck) {
    val app = LocalApp.current
    val color = deck.deckInkColors.firstOrNull()?.let { StorageCoverColor.fromRaw(it.rawValue.lowercase()) } ?: StorageCoverColor.MIDNIGHT
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        ContainerArtwork(StorageKind.DECK_BOX, color, StorageCoverStyle.CLASSIC, Modifier.height(110.dp))
        Text("Build ${deck.name}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
        Text(
            "Give the deck a box. You'll get a pull list showing where each card is — binder pages, boxes, or Unsorted — and check them off as you go.",
            style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center,
        )
    }
    FormSection(footer = "Deck boxes that hold a deck don't count toward your free binder and box limit.") {
        TextButton(onClick = {
            app.storage.createDeckBox(deck)
            Analytics.send("deck.buildStarted", mapOf("newBox" to "true"))
        }) {
            Icon(Icons.Filled.AddBox, null, tint = LorcanaGold)
            Text("  New Deck Box", color = LorcanaGold)
        }
    }
    val available = app.storage.availableDeckBoxes
    if (available.isNotEmpty()) {
        FormSection("Use an Empty Deck Box") {
            available.forEach { box ->
                Row(
                    Modifier.fillMaxWidth().clickable { app.storage.link(box, deck) }.padding(vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    ContainerArtwork(box.kind, box.coverColor, box.cover, Modifier.size(36.dp))
                    Column {
                        Text(box.name, color = Color.White)
                        Text("${box.cardCount} card${if (box.cardCount == 1) "" else "s"} inside", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
            }
        }
    }
}

/**
 * Every card still to pull, grouped by where it is. Checking a row moves those copies into
 * the deck box (remembering where they came from).
 */
@Composable
private fun DeckPullList(deck: Deck, box: StorageContainer) {
    val app = LocalApp.current
    var pulled by remember { mutableIntStateOf(0) }
    var wishlisted by remember { mutableStateOf(false) }
    val plan: DeckPullPlan = remember(app.storage.revision, app.decks.revision, app.collection.revision) { app.storage.pullPlan(deck, box) }

    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ContainerArtwork(StorageKind.DECK_BOX, box.coverColor, box.cover, Modifier.height(64.dp), lidLift = if (plan.isComplete) 1f else 0.3f)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(box.name, style = MaterialTheme.typography.titleMedium, color = Color.White)
            Text("${plan.inBox} of ${plan.total} cards in the box", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            LinearProgressIndicator(
                progress = { if (plan.total > 0) plan.inBox.toFloat() / plan.total else 0f },
                color = if (plan.isComplete) SystemColors.green else LorcanaGold,
                trackColor = Color.White.copy(alpha = 0.1f),
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
    if (plan.isComplete && plan.total > 0) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SystemColors.green.copy(alpha = 0.12f)).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Verified, null, tint = SystemColors.green)
            Text("  Every card is in the box. Deck built!", style = MaterialTheme.typography.titleSmall, color = SystemColors.green)
        }
    }
    if (plan.pulls.isNotEmpty()) {
        FormSection(footer = "Only do this if the cards are already in the box — otherwise check them off as you pull them.") {
            TextButton(onClick = {
                val moved = app.storage.pullAll(plan, box)
                pulled += moved
            }) {
                Icon(Icons.Filled.MoveToInbox, null, tint = LorcanaGold)
                Text("  Pull All ${plan.toPull} Cards", color = LorcanaGold)
            }
        }
    }
    plan.pullsBySource.forEach { group ->
        FormSection("${group.sourceName} · ${group.pulls.sumOf { it.quantity }}") {
            group.pulls.forEach { pull ->
                Row(
                    Modifier.fillMaxWidth().clickable { pulled += app.storage.pull(pull, box) }.padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Filled.CheckBoxOutlineBlank, contentDescription = "Mark pulled", tint = LorcanaGold)
                    CardImage(pull.card, Modifier.width(36.dp).clip(RoundedCornerShape(4.dp)))
                    Column(Modifier.weight(1f)) {
                        Text(pull.card.name, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                        val where = pull.pockets.takeIf { it.isNotEmpty() }?.let { pockets ->
                            pockets.joinToString { "p.${it.page} #${it.pocket}" }
                        }
                        Text(listOfNotNull(pull.card.variant.displayName.takeIf { pull.card.variant.name != "NORMAL" }, where).joinToString(" · "), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                    Text("×${pull.quantity}", color = Color.White)
                }
            }
        }
    }
    if (plan.missing.isNotEmpty()) {
        FormSection("You Don't Have These", footer = "Cards already in another built deck's box aren't pulled from it.") {
            plan.missing.forEach { shortfall ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    CardImage(shortfall.card, Modifier.width(40.dp).alpha(0.5f).clip(RoundedCornerShape(4.dp)))
                    Text(shortfall.card.name, color = Color.White, modifier = Modifier.weight(1f))
                    Text("×${shortfall.quantity}", color = SystemColors.orange)
                }
            }
            TextButton(enabled = !wishlisted, onClick = {
                plan.missing.forEach { app.collection.addToWishlist(it.card) }
                wishlisted = true
            }) {
                Icon(if (wishlisted) Icons.Filled.Check else Icons.Filled.Favorite, null, tint = LorcanaGold)
                Text(if (wishlisted) "  Added to Wishlist" else "  Add Missing to Wishlist", color = LorcanaGold)
            }
        }
    }
}
