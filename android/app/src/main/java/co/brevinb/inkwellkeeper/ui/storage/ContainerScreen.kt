package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FormatAlignLeft
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.NoteAdd
import androidx.compose.material.icons.filled.OpenWith
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.storage.BinderSortOrder
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.storage.StoredCard
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.launch

/** Binders open as books of pages; everything else as a box. */
@Composable
fun ContainerScreen(containerId: String) {
    val app = LocalApp.current
    val container = app.storage.container(containerId)
    if (container == null) {
        InkwellScaffold("Storage", showBack = true) { }
        return
    }
    if (container.kind.usesSlots) BinderScreen(container) else BoxScreen(container)
}

@Composable
private fun ContainerMenu(container: StorageContainer, extra: @Composable (dismiss: () -> Unit) -> Unit, onEdit: () -> Unit, onDelete: () -> Unit) {
    var open by remember { mutableStateOf(false) }
    IconButton(onClick = { open = true }) { Icon(Icons.Filled.MoreVert, contentDescription = "More") }
    DropdownMenu(open, { open = false }) {
        extra { open = false }
        DropdownMenuItem(text = { Text("Edit ${container.kind.displayName}") }, leadingIcon = { Icon(Icons.Filled.Edit, null) }, onClick = { open = false; onEdit() })
        DropdownMenuItem(text = { Text("Delete ${container.kind.displayName}") }, leadingIcon = { Icon(Icons.Filled.Delete, null) }, onClick = { open = false; onDelete() })
    }
}

@Composable
private fun DeleteContainerDialog(container: StorageContainer, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val nav = LocalNav.current
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Delete ${container.name}?") },
        text = { Text("Its cards stay in your collection and move back to Unsorted.") },
        confirmButton = {
            TextButton(onClick = {
                app.storage.delete(container)
                onDismiss()
                nav.popBackStack()
            }) { Text("Delete ${container.kind.displayName}", color = SystemColors.red) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

// MARK: - Binder

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BinderScreen(binder: StorageContainer) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    app.storage.revision
    val layout = binder.binderLayout
    val pager = rememberPagerState { layout.pageCount }
    var dialog by remember { mutableStateOf<String?>(null) }
    var pickedUp by remember { mutableStateOf<String?>(null) }
    var fillSlot by remember { mutableStateOf<Int?>(null) }
    var menuFor by remember { mutableStateOf<StoredCard?>(null) }
    val bySlot = binder.items.filter { it.slotIndex != null }.associateBy { it.slotIndex!! }
    val ghosts = remember(binder.id, binder.linkedSetName, binder.hasFoilPockets, layout) { app.storage.checklistGhosts(binder) }

    InkwellScaffold(
        title = binder.name,
        showBack = true,
        actions = {
            ContainerMenu(
                binder,
                extra = { dismiss ->
                    DropdownMenuItem(text = { Text("Auto-Fill…") }, leadingIcon = { Icon(Icons.Filled.AutoFixHigh, null) }, onClick = { dismiss(); dialog = "autofill" })
                    DropdownMenuItem(text = { Text("Add Cards…") }, leadingIcon = { Icon(Icons.Filled.Add, null) }, onClick = { dismiss(); dialog = "add" })
                    DropdownMenuItem(text = { Text("Close Gaps") }, leadingIcon = { Icon(Icons.Filled.FormatAlignLeft, null) }, enabled = binder.linkedSetName == null, onClick = { dismiss(); app.storage.compact(binder) })
                    DropdownMenuItem(text = { Text("Add 5 Sheets") }, leadingIcon = { Icon(Icons.Filled.NoteAdd, null) }, onClick = { dismiss(); app.storage.addSheets(5, binder) })
                    HorizontalDivider()
                },
                onEdit = { dialog = "edit" },
                onDelete = { dialog = "delete" },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize().navigationBarsPadding()) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                BinderCoverArtwork(binder.coverColor, binder.cover, Modifier.height(56.dp))
                Column(Modifier.weight(1f)) {
                    Text("${binder.cardCount} of ${layout.totalSlots} pockets filled", style = MaterialTheme.typography.bodyMedium, color = Color.White)
                    binder.linkedSetName?.let { set ->
                        val filled = ghosts.keys.count { bySlot[it] != null }
                        Text("$set checklist · $filled/${ghosts.size}" + if (binder.hasFoilPockets) " (master set)" else "", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                        LinearProgressIndicator(progress = { if (ghosts.isEmpty()) 0f else filled.toFloat() / ghosts.size }, color = LorcanaGold, trackColor = Color.White.copy(alpha = 0.1f), modifier = Modifier.fillMaxWidth().padding(top = 4.dp))
                    }
                }
            }
            if (pickedUp != null) {
                Row(Modifier.fillMaxWidth().background(LorcanaGold.copy(alpha = 0.2f)).padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.OpenWith, null, tint = LorcanaGold)
                    Text("  Tap a pocket to move the card there", color = Color.White, modifier = Modifier.weight(1f))
                    TextButton(onClick = { pickedUp = null }) { Text("Cancel", color = LorcanaGold) }
                }
            }
            HorizontalPager(pager, Modifier.weight(1f), contentPadding = PaddingValues(horizontal = 16.dp), pageSpacing = 12.dp) { page ->
                BinderPage(
                    columns = layout.columns,
                    slots = layout.slotsOnPage(page).toList(),
                    bySlot = bySlot,
                    ghosts = ghosts,
                    pickedUp = pickedUp,
                    onTap = { slot, occupant ->
                        val moving = pickedUp?.let { id -> binder.items.firstOrNull { it.id == id } }
                        when {
                            moving != null -> {
                                app.storage.moveItem(moving, slot)
                                pickedUp = null
                            }
                            occupant != null -> menuFor = occupant
                            else -> fillSlot = slot
                        }
                    },
                    onLongPress = { occupant -> pickedUp = occupant.id },
                )
            }
            Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                Text("Page ${pager.currentPage + 1} of ${layout.pageCount}", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.align(Alignment.CenterHorizontally))
                if (layout.pageCount > 1) {
                    Slider(
                        value = pager.currentPage.toFloat(),
                        onValueChange = { scope.launch { pager.scrollToPage(it.toInt()) } },
                        valueRange = 0f..(layout.pageCount - 1).toFloat(),
                        colors = SliderDefaults.colors(thumbColor = LorcanaGold, activeTrackColor = LorcanaGold),
                    )
                }
            }
        }
    }

    menuFor?.let { item ->
        val foil = item.toLorcanaCard().withVariant(CardVariant.FOIL)
        val canUpgrade = item.cardVariant == CardVariant.NORMAL && app.storage.upgradeTarget(foil, binder) != null
        AlertDialog(
            onDismissRequest = { menuFor = null },
            title = { Text(item.name) },
            text = {
                Column {
                    val (page, pocket) = layout.position(item.slotIndex ?: 0)
                    Text("Page ${page + 1}, pocket ${pocket + 1}", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                    TextButton(onClick = { menuFor = null; nav.openCard(item.toLorcanaCard(), CardDetailMode.COLLECTION) }) { Text("Card Details") }
                    TextButton(onClick = { menuFor = null; pickedUp = item.id }) { Text("Move to Another Pocket") }
                    if (canUpgrade) TextButton(onClick = { menuFor = null; app.storage.upgradeToFoil(foil, binder) }) { Text("Upgrade to Foil") }
                    TextButton(onClick = { menuFor = null; app.storage.remove(item) }) { Text("Remove from Pocket", color = SystemColors.red) }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { menuFor = null }) { Text("Close") } },
        )
    }
    fillSlot?.let { slot -> FillPocketSheet(binder, slot, ghosts[slot]) { fillSlot = null } }
    when (dialog) {
        "add" -> AddToContainerSheet(binder) { dialog = null }
        "autofill" -> BinderAutoFillSheet(binder) { dialog = null }
        "edit" -> ContainerEditorSheet(binder, onDismiss = { dialog = null })
        "delete" -> DeleteContainerDialog(binder) { dialog = null }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BinderPage(
    columns: Int,
    slots: List<Int>,
    bySlot: Map<Int, StoredCard>,
    ghosts: Map<Int, co.brevinb.inkwellkeeper.model.LorcanaCard>,
    pickedUp: String?,
    onTap: (Int, StoredCard?) -> Unit,
    onLongPress: (StoredCard) -> Unit,
) {
    Column(
        Modifier.fillMaxSize().clip(RoundedCornerShape(12.dp)).background(Color(0xFF1E1D2A)).border(1.dp, Color.White.copy(alpha = 0.08f), RoundedCornerShape(12.dp))
            .verticalScroll(rememberScrollState()).padding(10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        slots.chunked(columns).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { slot ->
                    val item = bySlot[slot]
                    val ghost = ghosts[slot]
                    Box(
                        Modifier.weight(1f).aspectRatio(0.716f).clip(RoundedCornerShape(6.dp))
                            .background(Color.White.copy(alpha = 0.05f))
                            .border(if (item?.id == pickedUp && item != null) 3.dp else 1.dp, if (item?.id == pickedUp && item != null) LorcanaGold else Color.White.copy(alpha = 0.12f), RoundedCornerShape(6.dp))
                            .combinedClickable(onClick = { onTap(slot, item) }, onLongClick = { item?.let(onLongPress) }),
                        contentAlignment = Alignment.Center,
                    ) {
                        when {
                            item != null -> CardImage(item.toLorcanaCard(), Modifier.fillMaxSize())
                            ghost != null -> {
                                CardImage(ghost, Modifier.fillMaxSize().alpha(0.22f))
                                Text("#${ghost.cardNumber ?: ""}" + if (ghost.variant == CardVariant.FOIL) " ✦" else "", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
                            }
                            else -> Icon(Icons.Filled.Add, contentDescription = "Empty pocket", tint = Color.White.copy(alpha = 0.2f))
                        }
                    }
                }
                repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

/** Fill one empty pocket: the checklist card for set binders, else any unsorted card. */
@Composable
private fun FillPocketSheet(binder: StorageContainer, slot: Int, ghost: co.brevinb.inkwellkeeper.model.LorcanaCard?, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val unsorted = app.storage.unsortedQuantitiesByIdentity()
    val candidates = if (ghost != null) listOf(ghost) else app.collection.collectedCards.filter { (unsorted[it.identityKey] ?: 0) > 0 }.distinctBy { it.identityKey }
    val (page, pocket) = binder.binderLayout.position(slot)
    FullScreenSheet(title = "Page ${page + 1}, Pocket ${pocket + 1}", onDismiss = onDismiss) { padding ->
        if (candidates.isEmpty()) {
            EmptyState(Icons.Filled.Inventory2, "No Unsorted Cards", "Every card you own is already put away. Use Add Cards to pick from the whole catalog.", Modifier.padding(padding))
            return@FullScreenSheet
        }
        LazyVerticalGrid(GridCells.Adaptive(100.dp), Modifier.padding(padding), contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(candidates, key = { it.variantAwareId }) { card ->
                Column(Modifier.clickable {
                    app.storage.placeAddingToCollection(card, slot, binder)
                    onDismiss()
                }, horizontalAlignment = Alignment.CenterHorizontally) {
                    CardImage(card, Modifier.clip(RoundedCornerShape(6.dp)))
                    Text(card.name, style = MaterialTheme.typography.labelSmall, color = Color.White, maxLines = 2, textAlign = TextAlign.Center)
                    if (ghost != null && (unsorted[card.identityKey] ?: 0) == 0) Text("Adds to collection", style = MaterialTheme.typography.labelSmall, color = LorcanaGold)
                }
            }
        }
    }
}

/** Fill free pockets with unsorted cards in a chosen order. */
@Composable
private fun BinderAutoFillSheet(binder: StorageContainer, onDismiss: () -> Unit) {
    val app = LocalApp.current
    var setFilter by remember { mutableStateOf(binder.linkedSetName) }
    var order by remember { mutableStateOf(BinderSortOrder.SET_NUMBER) }
    var growToFit by remember { mutableStateOf(false) }
    val unsorted = app.storage.unsortedQuantitiesByIdentity()
    val cards = app.collection.collectedCards.filter { (unsorted[it.identityKey] ?: 0) > 0 && (setFilter == null || it.setName == setFilter) }.distinctBy { it.identityKey }
    val copies = cards.sumOf { unsorted[it.identityKey] ?: 0 }
    val free = app.storage.freeSpace(binder) ?: 0
    FullScreenSheet(
        title = "Auto-Fill",
        onDismiss = onDismiss,
        confirmLabel = "Fill",
        confirmEnabled = copies > 0,
        onConfirm = {
            if (growToFit && copies > free && binder.linkedSetName == null) {
                val needed = binder.binderLayout.sheetsNeeded(binder.cardCount + copies)
                app.storage.addSheets(maxOf(0, needed - binder.sheetCount), binder)
            }
            app.storage.autoFill(binder, cards, order)
            onDismiss()
        },
    ) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            FormSection("Cards", footer = binder.linkedSetName?.let { "This is a $it checklist, so each card goes in its own numbered pocket. Extra copies and cards from other sets stay unsorted." }) {
                if (binder.linkedSetName == null) {
                    MenuPickerRow("From", listOf<String?>(null) + app.collection.collectedCards.map { it.setName }.distinct().sortedBy { s -> SetsDataManager.setOrder()[s] ?: Int.MAX_VALUE }, setFilter, { setFilter = it }, { it ?: "All unsorted cards" })
                }
                Text("$copies unsorted copies · $free free pockets", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
            FormSection("Arrange by") {
                MenuPickerRow("Arrange by", BinderSortOrder.entries, order, { order = it }, { it.displayName })
            }
            if (binder.linkedSetName == null && copies > free) {
                FormSection(footer = if (growToFit) null else "${copies - free} cards won't fit and will stay unsorted.") {
                    ToggleRow("Add sheets so everything fits", growToFit, { growToFit = it })
                }
            }
        }
    }
}

// MARK: - Box

@Composable
private fun BoxScreen(box: StorageContainer) {
    val app = LocalApp.current
    val nav = LocalNav.current
    app.storage.revision
    var dialog by remember { mutableStateOf<String?>(null) }
    var menuFor by remember { mutableStateOf<StoredCard?>(null) }
    val deckName = box.linkedDeckId?.let { app.storage.deckName(it) }
    val items = box.items.sortedWith(compareBy({ SetsDataManager.setOrder()[it.setName] ?: Int.MAX_VALUE }, { it.cardNumber ?: Int.MAX_VALUE }))

    InkwellScaffold(
        title = box.name,
        showBack = true,
        actions = {
            IconButton(onClick = { dialog = "add" }) { Icon(Icons.Filled.Add, contentDescription = "Add Cards") }
            ContainerMenu(box, extra = {}, onEdit = { dialog = "edit" }, onDelete = { dialog = "delete" })
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ContainerArtwork(box.kind, box.coverColor, box.cover, Modifier.height(72.dp), lidLift = if (items.isEmpty()) 0f else 0.6f)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(box.capacity?.let { "${box.cardCount} / $it cards" } ?: "${box.cardCount} cards", style = MaterialTheme.typography.titleMedium, color = Color.White)
                    box.capacity?.let { cap ->
                        LinearProgressIndicator(progress = { (box.cardCount.toFloat() / cap).coerceIn(0f, 1f) }, color = if (app.storage.isFull(box)) SystemColors.orange else LorcanaGold, trackColor = Color.White.copy(alpha = 0.1f), modifier = Modifier.fillMaxWidth())
                    }
                    Text("Worth ${co.brevinb.inkwellkeeper.pricing.PricingService.formatPrice(app.storage.value(box))}", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                    if (deckName != null) {
                        Text("Holds deck: $deckName", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.clickable { box.linkedDeckId?.let { nav.navigate(Routes.deck(it)) } })
                    }
                }
            }
            if (items.isEmpty()) {
                EmptyState(Icons.Filled.Inventory2, "Nothing Inside Yet", "Put unsorted cards in this ${box.kind.displayName.lowercase()} to find them later.") {
                    LorcanaPrimaryButton(onClick = { dialog = "add" }) { Text("Add Cards") }
                }
            } else {
                LazyVerticalGrid(GridCells.Adaptive(100.dp), contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.navigationBarsPadding()) {
                    items(items, key = { it.id }) { item ->
                        Column(Modifier.clickable { menuFor = item }, horizontalAlignment = Alignment.CenterHorizontally) {
                            Box {
                                CardImage(item.toLorcanaCard(), Modifier.clip(RoundedCornerShape(6.dp)))
                                if (item.quantity > 1) {
                                    Text("×${item.quantity}", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.Black,
                                        modifier = Modifier.align(Alignment.TopEnd).padding(4.dp).clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 6.dp, vertical = 1.dp))
                                }
                                if (item.cardVariant == CardVariant.FOIL) Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.align(Alignment.BottomStart).padding(4.dp).size(14.dp))
                            }
                            Text(item.name, style = MaterialTheme.typography.labelSmall, color = Color.White, maxLines = 2, textAlign = TextAlign.Center)
                        }
                    }
                }
            }
        }
    }

    menuFor?.let { item ->
        val others = app.storage.containers.filter { it.id != box.id && it.linkedDeckId == null }
        AlertDialog(
            onDismissRequest = { menuFor = null },
            title = { Text(item.name) },
            text = {
                Column {
                    TextButton(onClick = { menuFor = null; nav.openCard(item.toLorcanaCard(), CardDetailMode.COLLECTION) }) { Text("Card Details") }
                    if (item.quantity > 1) TextButton(onClick = { menuFor = null; app.storage.unstore(item.toLorcanaCard(), 1, box) }) { Text("Take Out One") }
                    TextButton(onClick = { menuFor = null; app.storage.unstore(item.toLorcanaCard(), item.quantity, box) }) { Text("Take Out All", color = SystemColors.red) }
                    if (others.isNotEmpty()) {
                        Text("Move to", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.padding(top = 8.dp))
                        others.forEach { dest ->
                            TextButton(onClick = { menuFor = null; app.storage.moveItems(listOf(item), dest) }, enabled = app.storage.canAccept(item.toLorcanaCard(), dest)) { Text(dest.name) }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { menuFor = null }) { Text("Close") } },
        )
    }
    when (dialog) {
        "add" -> AddToContainerSheet(box) { dialog = null }
        "edit" -> ContainerEditorSheet(box, onDismiss = { dialog = null })
        "delete" -> DeleteContainerDialog(box) { dialog = null }
    }
}
