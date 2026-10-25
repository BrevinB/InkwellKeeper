package co.brevinb.inkwellkeeper.ui.card

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Crop54
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.CollectedCard
import co.brevinb.inkwellkeeper.data.PhotoStore
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.storage.StorageAllocation
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.AsyncPriceView
import co.brevinb.inkwellkeeper.ui.components.BorderedButton
import co.brevinb.inkwellkeeper.ui.components.BuyCardOptions
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.CardTextView
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.PriceHistoryCard
import co.brevinb.inkwellkeeper.ui.components.PriceStyle
import co.brevinb.inkwellkeeper.ui.components.QuantityStepper
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SectionCard
import co.brevinb.inkwellkeeper.ui.components.VariantBadge
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.rules.AskAIRulesButton
import co.brevinb.inkwellkeeper.ui.share.CardShareSheet
import co.brevinb.inkwellkeeper.ui.storage.StoredInSection
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import java.text.DateFormat
import java.util.Date
import java.util.Locale

/**
 * Card details. Mirrors the iOS `CollectionCardDetailView` (collection / set browsing, where
 * SET mode edits Normal and Foil counts side by side) and `WishlistCardDetailView`.
 */
@Composable
fun CardDetailScreen(card: LorcanaCard, mode: CardDetailMode) {
    val app = LocalApp.current
    val nav = LocalNav.current
    // Catalog snapshots stored in decks/binders lack rules text; fill it from the catalog.
    val fullCard = remember(card) {
        if (card.cardText.isEmpty()) SetsDataManager.catalogCard(card)?.let { catalog ->
            card.copy(cardText = catalog.cardText, inkwell = catalog.inkwell, strength = catalog.strength, willpower = catalog.willpower, lore = catalog.lore)
        } ?: card else card
    }
    val showFoilSection = (mode == CardDetailMode.SET || mode == CardDetailMode.CATALOG) &&
        (card.variant == CardVariant.NORMAL || card.variant == CardVariant.FOIL)
    val normalCard = if (showFoilSection) fullCard.withVariant(CardVariant.NORMAL) else fullCard
    val foilCard = fullCard.withVariant(CardVariant.FOIL)

    val collected: CollectedCard? = if (mode == CardDetailMode.WISHLIST) null else app.collection.collectedRow(normalCard)
    val foilCollected: CollectedCard? = if (showFoilSection) app.collection.getCollectedCardDataForVariant(foilCard) else null
    val quantity = collected?.quantity ?: 0
    val foilQuantity = foilCollected?.quantity ?: 0
    val owned = collected != null || foilCollected != null

    var showFoilArt by remember { mutableStateOf(false) }
    var showingFullscreen by remember { mutableStateOf(false) }
    var showingRemove by remember { mutableStateOf(false) }
    var showingMove by remember { mutableStateOf(false) }
    var showingShare by remember { mutableStateOf(false) }
    var pendingRemoval by remember { mutableStateOf<Pair<LorcanaCard, List<StorageAllocation>>?>(null) }
    val displayCard = if (showFoilArt) foilCard else fullCard

    fun setQuantity(target: LorcanaCard, row: CollectedCard?, value: Int) {
        when {
            value > 0 && row != null -> app.collection.updateCardQuantity(target, value)
            value > 0 -> app.collection.addCard(target, value)
            row != null -> app.collection.removeCard(target)
        }
    }

    fun applyDecrement(foil: Boolean) {
        if (foil) setQuantity(foilCard, foilCollected, foilQuantity - 1) else setQuantity(normalCard, collected, quantity - 1)
        val remainingNormal = if (foil) quantity else quantity - 1
        val remainingFoil = if (foil) foilQuantity - 1 else foilQuantity
        if (remainingNormal <= 0 && (!showFoilSection || remainingFoil <= 0)) nav.popBackStack()
    }

    /** When every copy is put away, removing one means taking it out of storage too: ask which. */
    fun requestDecrement(foil: Boolean) {
        val target = if (foil) foilCard else normalCard
        val locations = app.storage.locations(target)
        if (locations.isNotEmpty() && app.storage.unsortedQuantity(target) == 0) pendingRemoval = target to locations
        else applyDecrement(foil)
    }

    InkwellScaffold(
        title = if (mode == CardDetailMode.WISHLIST) "Wishlist Card" else "Card Details",
        showBack = true,
        actions = {
            IconButton(onClick = { showingShare = true }) { Icon(Icons.Filled.IosShare, contentDescription = "Share") }
        },
    ) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            CardImage(
                displayCard,
                animatedFoil = true,
                modifier = Modifier.padding(top = 16.dp).width(250.dp).height(350.dp).clip(RoundedCornerShape(12.dp)).clickable { showingFullscreen = true },
            )
            if (showFoilSection && foilQuantity > 0) {
                Row(
                    Modifier.clip(RoundedCornerShape(50)).background(if (showFoilArt) LorcanaGold else LorcanaGold.copy(alpha = 0.15f))
                        .border(1.dp, LorcanaGold.copy(alpha = 0.5f), RoundedCornerShape(50))
                        .clickable { showFoilArt = !showFoilArt }.padding(horizontal = 14.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    val tint = if (showFoilArt) LorcanaDark else LorcanaGold
                    Icon(if (showFoilArt) Icons.Filled.AutoAwesome else Icons.Filled.Crop54, null, tint = tint, modifier = Modifier.size(14.dp))
                    Text(if (showFoilArt) " Viewing Foil" else " View Foil", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold, color = tint)
                }
            }

            Column(Modifier.widthIn(max = 640.dp).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                SectionCard(spacing = 16.dp) {
                    Text(fullCard.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = Color.White)
                    Text(fullCard.setName + (fullCard.uniqueId?.let { " · $it" } ?: ""), style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        RarityBadge(fullCard.rarity)
                        VariantBadge(fullCard.variant, short = false)
                    }
                    CardStatsRow(fullCard)

                    if (owned) {
                        if (showFoilSection) {
                            Text("Quantity", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                                VariantQuantityBox("Normal", Icons.Filled.Crop54, Color.White, quantity, Modifier.weight(1f),
                                    onDecrement = { requestDecrement(false) }, onIncrement = { setQuantity(normalCard, collected, quantity + 1) })
                                VariantQuantityBox("Foil", Icons.Filled.AutoAwesome, LorcanaGold, foilQuantity, Modifier.weight(1f),
                                    onDecrement = { requestDecrement(true) }, onIncrement = { setQuantity(foilCard, foilCollected, foilQuantity + 1) }, foil = true)
                            }
                        } else {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text("Quantity:", style = MaterialTheme.typography.titleMedium, color = LorcanaGold, modifier = Modifier.weight(1f))
                                QuantityStepper(quantity, { requestDecrement(false) }, { setQuantity(normalCard, collected, quantity + 1) })
                            }
                        }
                        collected?.let { row ->
                            DetailLine("Date Added:", DateFormat.getDateInstance(DateFormat.MEDIUM).format(Date(row.dateAdded)))
                            ConditionRow(row) { app.collection.saveContext() }
                            PurchasePriceRow(row) { app.collection.saveContext() }
                        }
                        StoredInSection(normalCard)
                        if (showFoilSection && foilQuantity > 0) StoredInSection(foilCard)
                        val allocations = app.deckAllocations(fullCard)
                        if (allocations.isNotEmpty()) {
                            Text("In built decks: " + allocations.joinToString { "${it.deckName} (${it.quantity})" }, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                        }
                    }

                    if (fullCard.cardText.isNotEmpty()) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Card Text:", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
                            CardTextView(fullCard.cardText, style = MaterialTheme.typography.bodyLarge, color = Color.White)
                        }
                    }
                    AsyncPriceView(displayCard, PriceStyle.DETAILED)
                }

                AskAIRulesButton(fullCard, source = if (mode == CardDetailMode.WISHLIST) "wishlistDetail" else "collectionDetail")
                PriceHistoryCard(displayCard)

                if (owned) {
                    val photoRow = collected ?: foilCollected
                    if (photoRow != null) {
                        CardPhotosSection(
                            photos = photoRow.photoPaths,
                            onAdd = { paths ->
                                photoRow.photoPaths = photoRow.photoPaths + paths
                                app.collection.saveContext()
                            },
                            onRemove = { path ->
                                photoRow.photoPaths = photoRow.photoPaths - path
                                PhotoStore.delete(path)
                                app.collection.saveContext()
                            },
                        )
                    }
                }

                BuyCardOptions(fullCard)

                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    when {
                        mode == CardDetailMode.WISHLIST -> {
                            LorcanaPrimaryButton(onClick = { showingMove = true }, modifier = Modifier.fillMaxWidth()) { Text("Move to Collection") }
                            BorderedButton(onClick = {
                                app.collection.removeFromWishlist(card)
                                nav.popBackStack()
                            }, modifier = Modifier.fillMaxWidth()) { Text("Remove from Wishlist") }
                        }
                        owned -> BorderedButton(onClick = { showingRemove = true }, modifier = Modifier.fillMaxWidth()) { Text("Remove All from Collection") }
                        else -> {
                            LorcanaPrimaryButton(onClick = { app.collection.addCard(fullCard.withVariant(CardVariant.NORMAL).let { if (fullCard.variant.isSpecialPrinting) fullCard else it }, 1) }, modifier = Modifier.fillMaxWidth()) {
                                Text("Add to Collection")
                            }
                            BorderedButton(onClick = {
                                app.collection.addToWishlist(fullCard)
                                nav.popBackStack()
                            }, tint = LorcanaGold, modifier = Modifier.fillMaxWidth()) { Text("Add to Wishlist") }
                        }
                    }
                }
            }
        }
    }

    if (showingFullscreen) FullscreenCardViewer(displayCard) { showingFullscreen = false }
    if (showingShare) {
        CardShareSheet(card = displayCard, ownedQuantity = maxOf(1, if (showFoilArt) foilQuantity else quantity), photoPath = (collected ?: foilCollected)?.photoPaths?.firstOrNull(), onDismiss = { showingShare = false })
    }
    if (showingRemove) {
        AlertDialog(
            onDismissRequest = { showingRemove = false },
            title = { Text("Remove Card") },
            text = {
                Text(
                    if (showFoilSection) "Are you sure you want to remove all copies of ${card.name} (Normal and Foil) from your collection?"
                    else "Are you sure you want to remove ${card.name} from your collection?",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    if (showFoilSection) {
                        app.collection.removeCard(normalCard)
                        app.collection.removeCard(foilCard)
                    } else {
                        app.collection.removeCard(card)
                    }
                    showingRemove = false
                    nav.popBackStack()
                }) { Text("Remove", color = SystemColors.red) }
            },
            dismissButton = { TextButton(onClick = { showingRemove = false }) { Text("Cancel") } },
        )
    }
    if (showingMove) {
        AlertDialog(
            onDismissRequest = { showingMove = false },
            title = { Text("Move to Collection") },
            text = { Text("Move ${card.name} from your wishlist to your collection?") },
            confirmButton = {
                TextButton(onClick = {
                    app.collection.addCard(card, 1)
                    app.collection.removeFromWishlist(card)
                    showingMove = false
                    nav.popBackStack()
                }) { Text("Move") }
            },
            dismissButton = { TextButton(onClick = { showingMove = false }) { Text("Cancel") } },
        )
    }
    pendingRemoval?.let { (target, locations) ->
        AlertDialog(
            onDismissRequest = { pendingRemoval = null },
            title = { Text("Which copy did you take out?") },
            text = {
                Column {
                    Text("All your copies are put away, so one comes out of storage too.")
                    locations.forEach { location ->
                        TextButton(onClick = {
                            app.storage.container(location.containerId)?.let { app.storage.unstore(target, 1, it) }
                            pendingRemoval = null
                            applyDecrement(target.variant == CardVariant.FOIL)
                        }) { Text("From ${location.containerName}", color = LorcanaGold) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { pendingRemoval = null }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun CardStatsRow(card: LorcanaCard) {
    val parts = buildList {
        add("Cost ${card.cost}")
        card.inkColor?.takeIf { it.isNotEmpty() }?.let { add(it) }
        add(card.type)
        if (card.inkwell == true) add("Inkable")
        card.strength?.let { add("$it STR") }
        card.willpower?.let { add("$it WIL") }
        card.lore?.let { add("$it Lore") }
    }
    Text(parts.joinToString(" · "), style = MaterialTheme.typography.labelMedium, color = Color.Gray)
}

@Composable
private fun DetailLine(label: String, value: String) {
    Row {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = Color.Gray, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, color = Color.White)
    }
}

@Composable
private fun VariantQuantityBox(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    tint: Color,
    value: Int,
    modifier: Modifier,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
    foil: Boolean = false,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        modifier.clip(shape)
            .background(if (value > 0) (if (foil) LorcanaGold.copy(alpha = 0.15f) else Color.White.copy(alpha = 0.1f)) else Color.Transparent)
            .border(1.dp, if (value > 0) (if (foil) LorcanaGold.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.3f)) else Color.Gray.copy(alpha = 0.3f), shape)
            .padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(14.dp))
            Text(" $label", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = tint)
        }
        QuantityStepper(
            value, onDecrement, onIncrement,
            buttonSize = 28.dp,
            plusColor = if (foil) LorcanaGold else SystemColors.green.copy(alpha = 0.8f),
            plusContent = if (foil) LorcanaDark else Color.White,
            label = "$label quantity",
        )
    }
}

private val conditions = PricingService.CardCondition.entries.map { it.rawValue }

@Composable
private fun ConditionRow(row: CollectedCard, onChange: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Condition:", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, modifier = Modifier.weight(1f))
        Column {
            Text(row.condition, style = MaterialTheme.typography.bodyMedium, color = Color.White, modifier = Modifier.clickable { expanded = true })
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                conditions.forEach { condition ->
                    DropdownMenuItem(text = { Text(condition) }, onClick = {
                        row.condition = condition
                        expanded = false
                        onChange()
                    })
                }
            }
        }
    }
}

/** Records what a copy cost, which turns market value into gain or loss. */
@Composable
private fun PurchasePriceRow(row: CollectedCard, onChange: () -> Unit) {
    var editing by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("Paid:", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, modifier = Modifier.weight(1f))
        if (editing) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text("0.00") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.width(120.dp),
            )
            TextButton(onClick = {
                val cleaned = draft.trim().replace(",", ".")
                row.purchasePrice = if (cleaned.isEmpty()) null else cleaned.toDoubleOrNull()?.takeIf { it >= 0 } ?: row.purchasePrice
                editing = false
                onChange()
            }) { Text("Save", color = LorcanaGold) }
        } else {
            Text(
                row.purchasePrice?.let { PricingService.formatPrice(it) } ?: "Add",
                style = MaterialTheme.typography.bodyMedium,
                color = if (row.purchasePrice != null) Color.White else LorcanaGold,
                modifier = Modifier.clickable {
                    draft = row.purchasePrice?.let { String.format(Locale.US, "%.2f", it) } ?: ""
                    editing = true
                },
            )
        }
    }
}
