package co.brevinb.inkwellkeeper.ui.sets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Crop54
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.data.SpoilerSettings
import co.brevinb.inkwellkeeper.model.CardGroup
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.InkColorFilter
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.PriceFilter
import co.brevinb.inkwellkeeper.model.SetCardFilterEngine
import co.brevinb.inkwellkeeper.model.SetOwnershipFilter
import co.brevinb.inkwellkeeper.model.SetSortOption
import co.brevinb.inkwellkeeper.model.VariantFilter
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.search.AddCardGroupSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.launch

/** Browse one set: progress, filters, owned/missing, quick add, and bulk add. */
@Composable
fun SetDetailScreen(setName: String) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val set = SetsDataManager.getSet(setName)
    val cards = remember(setName, SetsDataManager.isDataLoaded) { SetsDataManager.getCardsForSet(setName) }
    var ownership by rememberSaveable { mutableStateOf(SetOwnershipFilter.ALL) }
    var ink by rememberSaveable { mutableStateOf(InkColorFilter.ALL) }
    var rarity by remember { mutableStateOf<CardRarity?>(null) }
    var variant by rememberSaveable { mutableStateOf(VariantFilter.ALL) }
    var price by rememberSaveable { mutableStateOf(PriceFilter.ALL) }
    var sort by rememberSaveable { mutableStateOf(SetSortOption.CARD_NUMBER) }
    var search by rememberSaveable { mutableStateOf("") }
    var prices by remember { mutableStateOf<Map<String, Double>>(emptyMap()) }
    var bulkMode by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf(setOf<String>()) }
    var confirmBulk by remember { mutableStateOf(false) }
    var adding by remember { mutableStateOf<CardGroup?>(null) }
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    LaunchedEffect(setName, cards.size) { prices = PricingService.fetchBulkPrices(cards) }

    app.collection.revision
    val isOwned: (LorcanaCard) -> Boolean = { app.collection.isOwned(it) }
    val total = if (cards.isNotEmpty()) cards.size else set?.cardCount ?: 0
    val progress = app.collection.getSetProgress(setName, total)
    val filtered = remember(cards, ownership, ink, rarity, variant, price, sort, search, prices, app.collection.revision) {
        SetCardFilterEngine.sort(SetCardFilterEngine.apply(cards, ownership, ink, rarity, variant, price, search, prices, isOwned), sort, prices)
    }
    val missing = cards.filter { !isOwned(it) }

    fun quickAdd(card: LorcanaCard, foil: Boolean) {
        val v = if (card.variant.isSpecialPrinting) card.variant else if (foil) CardVariant.FOIL else CardVariant.NORMAL
        app.collection.addCard(if (card.variant == v) card else card.withVariant(v), 1, source = "set")
        scope.launch { snackbar.showSnackbar("${card.name} (${v.displayName}) added!") }
    }

    fun groupFor(card: LorcanaCard): CardGroup {
        if (card.variant.isSpecialPrinting) return CardGroup(card.uniqueId ?: card.id, card.name, listOf(card))
        val reprints = SpoilerSettings.visibleCards(SetsDataManager.getAllCards()).filter { it.name == card.name && !it.variant.isSpecialPrinting }
        return CardGroup(card.name, card.name, reprints.ifEmpty { listOf(card) })
    }

    InkwellScaffold(
        title = setName,
        showBack = true,
        snackbarHostState = snackbar,
        actions = {
            if (bulkMode) {
                TextButton(onClick = { bulkMode = false; selected = emptySet() }) { Text("Cancel", color = LorcanaGold) }
            } else {
                TextButton(onClick = { bulkMode = true; selected = emptySet() }) {
                    Icon(Icons.Filled.Checklist, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                    Text(" Bulk Add", color = LorcanaGold, style = MaterialTheme.typography.labelMedium)
                }
            }
        },
        bottomBar = {
            if (bulkMode && selected.isNotEmpty()) {
                Row(
                    Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.95f)).navigationBarsPadding().padding(horizontal = 16.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("${selected.size} card${if (selected.size == 1) "" else "s"} selected", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = Color.White)
                        Text("Will be added as Normal variant", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                    Row(
                        Modifier.clip(RoundedCornerShape(10.dp)).background(LorcanaGold).clickable { confirmBulk = true }.padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Filled.AddCircle, null, tint = LorcanaDark)
                        Text(" Add All", fontWeight = FontWeight.SemiBold, color = LorcanaDark)
                    }
                }
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(Modifier.background(LorcanaDark.copy(alpha = 0.3f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(setName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, modifier = Modifier.weight(1f))
                    Text("${progress.percentage.toInt()}% Complete", style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                }
                Text("${progress.collected} of ${progress.total} cards collected", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
                SetFilterRow(ownership, { ownership = it }, ink, { ink = it }, rarity, { rarity = it }, variant, { variant = it }, price, { price = it }, sort, { sort = it })
                if (bulkMode) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        val all = selected.size == missing.size && missing.isNotEmpty()
                        Row(Modifier.clickable { selected = if (all) emptySet() else missing.map { it.id }.toSet() }, verticalAlignment = Alignment.CenterVertically) {
                            Icon(if (all) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                            Text(if (all) " Deselect All" else " Select All Missing", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                        }
                        Spacer(Modifier.weight(1f))
                        Text("${selected.size} selected", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
                SearchBar(search, { search = it })
                ProgressBar(progress.percentage / 100, 6)
            }
            when {
                cards.isEmpty() -> Text("This set's card data hasn't been added to the app yet.", color = Color.Gray, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(32.dp))
                filtered.isEmpty() -> Text(if (ownership == SetOwnershipFilter.MISSING) "All cards collected!" else "No cards found", color = Color.Gray, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(32.dp))
                else -> LazyVerticalGrid(
                    GridCells.Adaptive(110.dp),
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(filtered, key = { it.variantAwareId }) { card ->
                        app.collection.revision
                        val owned = isOwned(card)
                        SetCardCell(
                            card = card,
                            owned = owned,
                            normalQty = app.collection.getCollectedCardDataForVariant(card.withVariant(CardVariant.NORMAL))?.quantity ?: 0,
                            foilQty = if (card.variant.isSpecialPrinting) app.collection.getCollectedCardData(card)?.quantity ?: 0
                            else app.collection.getCollectedCardDataForVariant(card.withVariant(CardVariant.FOIL))?.quantity ?: 0,
                            bulkMode = bulkMode,
                            isSelected = card.id in selected,
                            onTap = {
                                when {
                                    bulkMode -> if (!owned) selected = if (card.id in selected) selected - card.id else selected + card.id
                                    owned -> nav.openCard(card, CardDetailMode.SET)
                                    else -> adding = groupFor(card)
                                }
                            },
                            onQuickAdd = { quickAdd(card, false) },
                            onQuickAddFoil = { quickAdd(card, true) },
                        )
                    }
                }
            }
        }
    }

    adding?.let { group ->
        AddCardGroupSheet(group, isWishlist = false, onDismiss = { adding = null }, onAdded = { scope.launch { snackbar.showSnackbar(it) } })
    }
    if (confirmBulk) {
        AlertDialog(
            onDismissRequest = { confirmBulk = false },
            title = { Text("Add ${selected.size} card${if (selected.size == 1) "" else "s"} to collection?") },
            text = { Text("Each card is added with its actual variant (Normal, Enchanted, Epic, Iconic, or Promo) at quantity 1.") },
            confirmButton = {
                TextButton(onClick = {
                    // Keep each card's real variant; forcing Normal corrupted special printings on iOS.
                    cards.filter { it.id in selected }.forEach { app.collection.addCard(it, 1, bulkImport = true, source = "setBulk") }
                    app.collection.finalizeBulkImport()
                    selected = emptySet()
                    bulkMode = false
                    confirmBulk = false
                }) { Text("Add to Collection") }
            },
            dismissButton = { TextButton(onClick = { confirmBulk = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun SetCardCell(
    card: LorcanaCard,
    owned: Boolean,
    normalQty: Int,
    foilQty: Int,
    bulkMode: Boolean,
    isSelected: Boolean,
    onTap: () -> Unit,
    onQuickAdd: () -> Unit,
    onQuickAddFoil: () -> Unit,
) {
    val hidden = SpoilerSettings.isHidden(card)
    Column(
        Modifier.alpha(if (owned || (bulkMode && isSelected)) 1f else 0.6f).clickable(onClick = onTap),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box {
            val borderColor = when {
                bulkMode && isSelected -> LorcanaGold
                owned -> card.rarity.color
                else -> Color.Gray.copy(alpha = 0.5f)
            }
            CardImage(card, Modifier.clip(RoundedCornerShape(8.dp)).border(if (bulkMode && isSelected) 3.dp else if (owned) 2.dp else 1.dp, borderColor, RoundedCornerShape(8.dp)))
            Box(Modifier.align(Alignment.TopEnd).padding(6.dp)) {
                when {
                    bulkMode && !owned -> Box(
                        Modifier.size(26.dp).clip(CircleShape).background(if (isSelected) LorcanaGold else Color.Black.copy(alpha = 0.5f)).border(2.dp, Color.White.copy(alpha = 0.7f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) { if (isSelected) Icon(Icons.Filled.Check, null, tint = LorcanaDark, modifier = Modifier.size(14.dp)) }
                    owned -> Column(verticalArrangement = Arrangement.spacedBy(3.dp), horizontalAlignment = Alignment.End) {
                        if (normalQty > 0) CountBadge(Icons.Filled.Crop54, normalQty, SystemColors.green, Color.White)
                        if (foilQty > 0) CountBadge(Icons.Filled.AutoAwesome, foilQty, LorcanaGold, LorcanaDark)
                    }
                    else -> Box(Modifier.size(24.dp).clip(CircleShape).background(SystemColors.red.copy(alpha = 0.8f)), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.Close, contentDescription = "Missing", tint = Color.White, modifier = Modifier.size(14.dp))
                    }
                }
            }
            if (!bulkMode && !hidden) {
                Column(Modifier.align(Alignment.BottomEnd).padding(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (!card.variant.isSpecialPrinting) {
                        Box(Modifier.size(28.dp).clip(CircleShape).background(LorcanaGold).clickable(onClick = onQuickAddFoil), contentAlignment = Alignment.Center) {
                            Icon(Icons.Filled.AutoAwesome, contentDescription = "Quick add foil", tint = LorcanaDark, modifier = Modifier.size(14.dp))
                        }
                    }
                    Box(Modifier.size(28.dp).clip(CircleShape).background(SystemColors.green).clickable(onClick = onQuickAdd), contentAlignment = Alignment.Center) {
                        Icon(Icons.Filled.Add, contentDescription = "Quick add", tint = Color.White, modifier = Modifier.size(16.dp))
                    }
                }
            }
            RarityBadge(card.rarity, Modifier.align(Alignment.BottomStart).padding(6.dp))
        }
        Text(
            if (hidden) "Spoiler" else card.name,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            color = if (owned) Color.White else Color.Gray,
            maxLines = 2,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun CountBadge(icon: androidx.compose.ui.graphics.vector.ImageVector, count: Int, background: Color, content: Color) {
    Row(Modifier.clip(RoundedCornerShape(50)).background(background).padding(horizontal = 5.dp, vertical = 2.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = content, modifier = Modifier.size(8.dp))
        Text(" $count", fontSize = 10.sp, fontWeight = FontWeight.Bold, color = content)
    }
}

@Composable
private fun SetFilterRow(
    ownership: SetOwnershipFilter, onOwnership: (SetOwnershipFilter) -> Unit,
    ink: InkColorFilter, onInk: (InkColorFilter) -> Unit,
    rarity: CardRarity?, onRarity: (CardRarity?) -> Unit,
    variant: VariantFilter, onVariant: (VariantFilter) -> Unit,
    price: PriceFilter, onPrice: (PriceFilter) -> Unit,
    sort: SetSortOption, onSort: (SetSortOption) -> Unit,
) {
    Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        MenuChip(ownership.displayName, ownership != SetOwnershipFilter.ALL, SetOwnershipFilter.entries, { it.displayName }, onOwnership)
        MenuChip(if (ink == InkColorFilter.ALL) "Ink" else ink.displayName, ink != InkColorFilter.ALL, InkColorFilter.entries, { it.displayName }, onInk)
        MenuChip(rarity?.displayName ?: "Rarity", rarity != null, listOf<CardRarity?>(null) + CardRarity.entries, { it?.displayName ?: "All Rarities" }, onRarity)
        MenuChip(if (variant == VariantFilter.ALL) "Variant" else variant.displayName, variant != VariantFilter.ALL, VariantFilter.entries, { it.displayName }, onVariant)
        MenuChip(if (price == PriceFilter.ALL) "Price" else price.displayName, price != PriceFilter.ALL, PriceFilter.entries, { it.displayName }, onPrice)
        MenuChip(sort.displayName, false, SetSortOption.entries, { it.displayName }, onSort)
    }
}

@Composable
private fun <T> MenuChip(label: String, active: Boolean, options: List<T>, optionLabel: (T) -> String, onSelect: (T) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = if (active) Color.Black else LorcanaGold,
            modifier = Modifier.clip(RoundedCornerShape(50)).background(if (active) LorcanaGold else Color.Transparent)
                .border(1.dp, LorcanaGold, RoundedCornerShape(50)).clickable { expanded = true }.padding(horizontal = 12.dp, vertical = 6.dp),
        )
        DropdownMenu(expanded, { expanded = false }) {
            options.forEach { option -> DropdownMenuItem(text = { Text(optionLabel(option)) }, onClick = { onSelect(option); expanded = false }) }
        }
    }
}
