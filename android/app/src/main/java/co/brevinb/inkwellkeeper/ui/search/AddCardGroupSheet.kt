package co.brevinb.inkwellkeeper.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Crop54
import androidx.compose.material.icons.filled.FilterNone
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.PhotoStore
import co.brevinb.inkwellkeeper.model.CardGroup
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.card.CardPhotosSection
import co.brevinb.inkwellkeeper.ui.card.FullscreenCardViewer
import co.brevinb.inkwellkeeper.ui.components.AsyncPriceView
import co.brevinb.inkwellkeeper.ui.components.BuyCardOptions
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.PriceHistoryCard
import co.brevinb.inkwellkeeper.ui.components.PriceStyle
import co.brevinb.inkwellkeeper.ui.components.QuantityStepper
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SectionCard
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/**
 * Add a card found in search: Normal and Foil quantities side by side, or a single quantity for
 * special printings. Quantities start at 0 so they can't be mistaken for owned copies.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun AddCardGroupSheet(group: CardGroup, isWishlist: Boolean, onDismiss: () -> Unit, onAdded: (String) -> Unit = {}) {
    val app = LocalApp.current
    val primary = group.primaryCard
    val supportsMulti = primary.availableVariants().let { CardVariant.NORMAL in it && CardVariant.FOIL in it }
    val displayCard = if (supportsMulti) primary.withVariant(CardVariant.NORMAL) else primary
    var normalQty by remember { mutableIntStateOf(0) }
    var foilQty by remember { mutableIntStateOf(0) }
    var specialQty by remember { mutableIntStateOf(0) }
    var photos by remember { mutableStateOf<List<String>>(emptyList()) }
    var expanded by remember { mutableStateOf(false) }
    val total = if (supportsMulti) normalQty + foilQty else specialQty
    val ownedTotal = CardVariant.entries.sumOf { app.collection.getCollectedQuantityByName(displayCard.name, displayCard.setName, it) }

    fun add(toWishlist: Boolean) {
        val picks = if (supportsMulti) {
            listOf(displayCard to normalQty, displayCard.withVariant(CardVariant.FOIL) to foilQty)
        } else {
            listOf(primary to specialQty)
        }.filter { it.second > 0 }
        for ((card, qty) in picks) {
            if (toWishlist || isWishlist) repeat(qty) { app.collection.addToWishlist(card) }
            else app.collection.addCard(card, qty, photoPaths = if (card == picks.first().first) photos else emptyList(), source = "search")
        }
        val names = picks.joinToString(" + ") { "${it.second} ${it.first.variant.displayName}" }
        onAdded("Added $names ${displayCard.name} to ${if (toWishlist || isWishlist) "Wishlist" else "Collection"}")
        onDismiss()
    }

    FullScreenSheet(title = if (isWishlist) "Add to Wishlist" else "Add Card", onDismiss = onDismiss) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            SectionCard(cornerRadius = 12.dp) {
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    CardImage(displayCard, Modifier.size(80.dp, 110.dp).clip(RoundedCornerShape(8.dp)).clickable { expanded = true })
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(displayCard.name, style = MaterialTheme.typography.titleMedium, color = Color.White)
                        Text(displayCard.setName, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                        RarityBadge(displayCard.rarity)
                        AsyncPriceView(displayCard, PriceStyle.INLINE)
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(
                    if (ownedTotal > 0) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                    null,
                    tint = if (ownedTotal > 0) SystemColors.green else Color.Gray,
                )
                Text(
                    if (ownedTotal > 0) "In your collection: $ownedTotal" else "Not in your collection yet",
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (ownedTotal > 0) Color.White else Color.Gray,
                )
            }
            if (group.isReprint) {
                SectionCard(background = LorcanaDark.copy(alpha = 0.6f), cornerRadius = 12.dp) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.FilterNone, null, tint = SystemColors.blue, modifier = Modifier.size(14.dp))
                        Text(" This card appears in multiple sets", style = MaterialTheme.typography.bodyMedium, color = Color.White)
                    }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        group.cards.forEach { card ->
                            Text(
                                card.setName + (card.uniqueId?.let { " ($it)" } ?: ""),
                                style = MaterialTheme.typography.labelMedium,
                                color = Color.White,
                                modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(SystemColors.blue.copy(alpha = 0.3f)).padding(horizontal = 8.dp, vertical = 4.dp),
                            )
                        }
                    }
                    Text("Adding this card will count toward all sets", style = MaterialTheme.typography.labelMedium, fontStyle = FontStyle.Italic, color = Color.Gray)
                }
            }
            if (supportsMulti) {
                SectionCard(background = LorcanaDark.copy(alpha = 0.6f), cornerRadius = 12.dp, title = "Add Cards") {
                    Text("Set quantities for each variant you want to add", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        VariantQuantity("Normal", Icons.Filled.Crop54, Color.White, normalQty, Modifier.weight(1f)) { normalQty = it }
                        VariantQuantity("Foil", Icons.Filled.AutoAwesome, LorcanaGold, foilQty, Modifier.weight(1f)) { foilQty = it }
                    }
                }
            } else {
                SectionCard(background = LorcanaDark.copy(alpha = 0.6f), cornerRadius = 12.dp, title = "Card Variant") {
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(LorcanaGold.copy(alpha = 0.3f))
                            .border(1.dp, LorcanaGold, RoundedCornerShape(8.dp)).padding(8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Text(primary.variant.shortName, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
                        Text(primary.variant.displayName, style = MaterialTheme.typography.labelSmall, color = Color.White)
                    }
                }
                SectionCard(background = LorcanaDark.copy(alpha = 0.6f), cornerRadius = 12.dp, title = "Quantity to Add") {
                    QuantityStepper(specialQty, { if (specialQty > 0) specialQty-- }, { specialQty++ })
                }
            }
            PriceHistoryCard(displayCard)
            if (!isWishlist) {
                CardPhotosSection(photos, onAdd = { photos = photos + it }, onRemove = { photos = photos - it; PhotoStore.delete(it) }, title = "Photos (optional)")
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Or Buy This Card", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                BuyCardOptions(displayCard)
            }
            LorcanaPrimaryButton(onClick = { add(false) }, enabled = total > 0, modifier = Modifier.fillMaxWidth()) {
                Text(
                    when {
                        total == 0 -> "Choose a quantity"
                        isWishlist -> "Add $total to Wishlist"
                        else -> "Add $total card${if (total > 1) "s" else ""} to Collection"
                    },
                )
            }
            if (!isWishlist) {
                OutlinedButton(onClick = { add(true) }, enabled = total > 0, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Star, null, tint = SystemColors.yellow)
                    Spacer(Modifier.width(6.dp))
                    Text("Add to Wishlist Instead", color = SystemColors.yellow)
                }
            }
        }
    }
    if (expanded) FullscreenCardViewer(displayCard) { expanded = false }
}

@Composable
private fun VariantQuantity(label: String, icon: ImageVector, tint: Color, value: Int, modifier: Modifier, onChange: (Int) -> Unit) {
    Column(
        modifier.clip(RoundedCornerShape(12.dp)).background(if (value > 0) tint.copy(alpha = 0.12f) else Color.Transparent)
            .border(1.dp, if (value > 0) tint.copy(alpha = 0.5f) else Color.Gray.copy(alpha = 0.3f), RoundedCornerShape(12.dp)).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp))
            Text(" $label", style = MaterialTheme.typography.bodyMedium, color = tint)
        }
        QuantityStepper(value, { if (value > 0) onChange(value - 1) }, { onChange(value + 1) }, buttonSize = 28.dp, label = "$label quantity")
    }
}
