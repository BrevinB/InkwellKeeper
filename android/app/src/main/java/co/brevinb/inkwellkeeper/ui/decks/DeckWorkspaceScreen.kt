package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.MoveToInbox
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Send
import androidx.compose.material.icons.filled.Style
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.data.SpoilerSettings
import co.brevinb.inkwellkeeper.decks.DeckStatistics
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.storage.StorageKind
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.share.DeckShareImageSheet
import co.brevinb.inkwellkeeper.ui.storage.BuildDeckSheet
import co.brevinb.inkwellkeeper.ui.storage.ContainerArtwork
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

private enum class WorkspaceMode { ADD, DECK }

/** The unified build + view screen for one deck. */
@Composable
fun DeckWorkspaceScreen(deckId: String) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val deck = app.decks.deck(deckId)
    if (deck == null) {
        InkwellScaffold("Deck", showBack = true) { }
        return
    }
    app.decks.revision
    var mode by rememberSaveable { mutableStateOf(if (deck.cards.isEmpty()) WorkspaceMode.ADD else WorkspaceMode.DECK) }
    var menu by remember { mutableStateOf(false) }
    var showing by remember { mutableStateOf<String?>(null) }
    val stats = app.decks.statistics(deck, app.collection)
    val validation = app.decks.validateDeck(deck)
    val count = deck.totalCards

    DisposableEffect(deck.id) {
        onDispose {
            // Only auto-detect inks when the user didn't choose them at creation.
            if (deck.deckInkColors.isEmpty()) app.decks.updateDeckColorsFromCards(deck)
        }
    }

    InkwellScaffold(
        title = deck.name,
        showBack = true,
        titleContent = {
            Row(Modifier.clickable { showing = "rename" }, verticalAlignment = Alignment.CenterVertically) {
                Text(deck.name, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Icon(Icons.Filled.Edit, contentDescription = "Rename deck", tint = LorcanaGold, modifier = Modifier.padding(start = 6.dp).size(14.dp))
            }
        },
        actions = {
            IconButton(onClick = { menu = true }) { Icon(Icons.Filled.MoreVert, contentDescription = "Deck options") }
            DropdownMenu(menu, { menu = false }) {
                @Composable
                fun item(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, enabled: Boolean = true, action: () -> Unit) =
                    DropdownMenuItem(text = { Text(label) }, leadingIcon = { Icon(icon, null) }, enabled = enabled, onClick = { menu = false; action() })
                item("AI Complete Deck", Icons.Filled.AutoAwesome) { nav.navigate("${Routes.AI_DECK_BUILDER}?deck=${deck.id}") }
                item("AI Strategy Guide", Icons.Filled.Psychology) { nav.navigate("${Routes.AI_DECK_BUILDER}?deck=${deck.id}&strategy=true") }
                item("Edit Deck Info", Icons.Filled.Edit) { showing = "edit" }
                item("Export Deck List", Icons.Filled.IosShare) { showing = "export" }
                item("Share Deck", Icons.Filled.Send) { showing = "share" }
                item("Draw Opening Hand", Icons.Filled.Style) { showing = "hand" }
                item("Duplicate Deck", Icons.Filled.ContentCopy) { nav.navigate(Routes.deck(app.decks.duplicateDeck(deck).id)) }
                HorizontalDivider()
                if (app.storage.isBuilt(deck)) {
                    item("Pull Cards", Icons.Filled.MoveToInbox) { showing = "build" }
                    item("Take Deck Apart", Icons.Filled.Inventory2) { showing = "takeApart" }
                } else {
                    item("Build This Deck", Icons.Filled.Inventory2, enabled = count > 0) { showing = "build" }
                }
                HorizontalDivider()
                item("Delete Deck", Icons.Filled.Delete) { showing = "delete" }
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            DeckSummaryBar(count, deck, stats.costDistribution, validation.isValid) { mode = WorkspaceMode.DECK }
            val box = app.storage.deckBox(deck.id)
            DeckBuildStatusBar(deck, box) { showing = "build" }
            BoxWithConstraints(Modifier.fillMaxSize()) {
                val both = maxWidth >= 900.dp
                Column(Modifier.fillMaxSize()) {
                    if (!both) {
                        SegmentedPicker(
                            WorkspaceMode.entries, mode, { mode = it },
                            { if (it == WorkspaceMode.ADD) "Add Cards" else "Deck ($count)" },
                            Modifier.background(Color.Black.copy(alpha = 0.2f)).padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }
                    Row(Modifier.fillMaxSize()) {
                        if (both || mode == WorkspaceMode.ADD) BuilderBrowser(deck, Modifier.weight(1f).fillMaxHeight())
                        if (both) VerticalDivider(color = LorcanaGold.copy(alpha = 0.25f))
                        if (both || mode == WorkspaceMode.DECK) {
                            DeckOverview(deck, if (both) Modifier.width(420.dp).fillMaxHeight() else Modifier.weight(1f).fillMaxHeight())
                        }
                    }
                }
            }
        }
    }

    when (showing) {
        "edit" -> EditDeckSheet(deck) { showing = null }
        "export" -> ExportDeckSheet(app.decks.exportCommunityDeckList(deck), app.decks.exportDeckList(deck)) { showing = null }
        "share" -> DeckShareSheet(deck, onShareImage = { showing = "shareImage" }) { showing = null }
        "shareImage" -> DeckShareImageSheet(deck, stats) { showing = null }
        "hand" -> OpeningHandSheet(deck) { showing = null }
        "build" -> BuildDeckSheet(deck) { showing = null }
        "rename" -> {
            var text by remember { mutableStateOf(deck.name) }
            AlertDialog(
                onDismissRequest = { showing = null },
                title = { Text("Rename Deck") },
                text = { OutlinedTextField(text, { text = it }, singleLine = true, label = { Text("Deck name") }) },
                confirmButton = {
                    TextButton(onClick = {
                        text.trim().takeIf { it.isNotEmpty() }?.let { deck.name = it; app.decks.updateDeck(deck) }
                        showing = null
                    }) { Text("Save") }
                },
                dismissButton = { TextButton(onClick = { showing = null }) { Text("Cancel") } },
            )
        }
        "delete" -> AlertDialog(
            onDismissRequest = { showing = null },
            title = { Text("Delete Deck?") },
            text = {
                Text(
                    if (app.storage.isBuilt(deck)) "Are you sure you want to delete \"${deck.name}\"? Its cards stay in the deck box. This action cannot be undone."
                    else "Are you sure you want to delete \"${deck.name}\"? This action cannot be undone.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    app.storage.unlinkDeck(deck.id)
                    app.decks.deleteDeck(deck)
                    showing = null
                    nav.popBackStack()
                }) { Text("Delete", color = SystemColors.red) }
            },
            dismissButton = { TextButton(onClick = { showing = null }) { Text("Cancel") } },
        )
        "takeApart" -> AlertDialog(
            onDismissRequest = { showing = null },
            title = { Text("Take ${deck.name} apart?") },
            text = { Text("The deck stays as an idea. Cards go back to their binder pockets and boxes when there's room; the rest go to Unsorted.") },
            confirmButton = {
                Column(horizontalAlignment = Alignment.End) {
                    listOf(true to "Put Cards Back Where They Came From", false to "Move All to Unsorted").forEach { (origins, label) ->
                        TextButton(onClick = {
                            app.storage.deckBox(deck.id)?.let { app.storage.takeApart(it, origins) }
                            Analytics.send("deck.takenApart", mapOf("returnedToOrigins" to "$origins"))
                            showing = null
                        }) { Text(label) }
                    }
                    TextButton(onClick = { showing = null }) { Text("Cancel") }
                }
            },
        )
    }
}

@Composable
private fun DeckSummaryBar(count: Int, deck: Deck, costDistribution: Map<Int, Int>, isValid: Boolean, onTap: () -> Unit) {
    var showingLeader by remember { mutableStateOf(false) }
    val leader = deck.coconutLeaderInfo
    Row(
        Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.85f)).clickable(onClick = onTap).padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("$count/60", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = if (count >= 60) SystemColors.green else LorcanaGold)
        if (leader != null) {
            Row(
                Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold.copy(alpha = 0.15f)).clickable { showingLeader = true }.padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.EmojiEvents, null, tint = LorcanaGold, modifier = Modifier.size(10.dp))
                Text(" ${leader.name.substringBefore(" – ")}", style = MaterialTheme.typography.labelSmall, color = LorcanaGold, maxLines = 1)
            }
        }
        if (deck.deckInkColors.isNotEmpty()) InkDots(deck.deckInkColors)
        if (count > 0) CurveSparkline(costDistribution)
        Spacer(Modifier.weight(1f))
        if (count > 0) {
            Icon(if (isValid) Icons.Filled.Verified else Icons.Filled.Warning, contentDescription = if (isValid) "Valid" else "Invalid", tint = if (isValid) SystemColors.green else SystemColors.orange)
        }
    }
    if (showingLeader && leader != null) {
        AlertDialog(
            onDismissRequest = { showingLeader = false },
            title = { Text(leader.name) },
            text = { Text("${leader.abilityText}\n\n4 copies allowed: ${leader.fourOfCardNames.joinToString()}") },
            confirmButton = { TextButton(onClick = { showingLeader = false }) { Text("Done") } },
        )
    }
}

@Composable
private fun DeckBuildStatusBar(deck: Deck, box: co.brevinb.inkwellkeeper.storage.StorageContainer?, onBuild: () -> Unit) {
    val app = LocalApp.current
    Row(
        Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.25f)).padding(horizontal = 16.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (box != null) {
            val progress = app.storage.deckProgress(deck, box)
            ContainerArtwork(StorageKind.DECK_BOX, box.coverColor, box.cover, Modifier.size(22.dp))
            Column(Modifier.weight(1f)) {
                Text("Built · ${box.name}", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
                val done = progress.inBox >= progress.total
                Text(
                    if (done) "All ${progress.total} cards in the box" else "${progress.inBox} of ${progress.total} cards in the box",
                    style = MaterialTheme.typography.labelSmall, color = if (done) SystemColors.green else Color.Gray,
                )
            }
            OutlinedButton(onClick = onBuild, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp), modifier = Modifier.height(32.dp)) {
                Text(if (progress.inBox >= progress.total) "View" else "Pull Cards", color = LorcanaGold, style = MaterialTheme.typography.labelMedium)
            }
        } else {
            Icon(Icons.Filled.Lightbulb, null, tint = LorcanaGold)
            Column(Modifier.weight(1f)) {
                Text("Idea deck", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = Color.White)
                Text("Doesn't use your cards until you build it", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
            OutlinedButton(onClick = onBuild, enabled = deck.totalCards > 0, contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp), modifier = Modifier.height(32.dp)) {
                Icon(Icons.Filled.Inventory2, null, tint = LorcanaGold, modifier = Modifier.size(14.dp))
                Text(" Build", color = LorcanaGold, style = MaterialTheme.typography.labelMedium)
            }
        }
    }
}

/** Deck stats, validation, missing cards, curve, and the card list grouped by cost. */
@Composable
private fun DeckOverview(deck: Deck, modifier: Modifier) {
    val app = LocalApp.current
    val nav = LocalNav.current
    app.decks.revision
    if (deck.cards.isEmpty()) {
        Column(modifier.padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Spacer(Modifier.height(40.dp))
            Icon(Icons.Filled.ViewCarousel, null, tint = LorcanaGold.copy(alpha = 0.6f), modifier = Modifier.size(48.dp))
            Text("No cards yet", style = MaterialTheme.typography.titleMedium, color = Color.White)
            Text("Add cards from the browser to start building.", style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center)
        }
        return
    }
    val stats = app.decks.statistics(deck, app.collection)
    val validation = app.decks.validateDeck(deck)
    val missing = app.decks.getMissingCards(deck, app.collection)
    val byCost = deck.cards.groupBy { it.cost }.toSortedMap()
    LazyColumn(modifier, contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item { DeckStatisticsCard(stats, validation, deck) }
        if (validation.errors.isNotEmpty() || validation.warnings.isNotEmpty()) item { ValidationCard(validation) }
        if (missing.isNotEmpty()) item { MissingCardsCard(missing, stats.costToComplete) }
        item { CostCurveCard(stats.costDistribution) }
        item { Text("Cards (${stats.totalCards})", style = MaterialTheme.typography.titleMedium, color = LorcanaGold) }
        byCost.forEach { (cost, cards) ->
            item(key = "cost$cost") {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Cost $cost", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.Gray)
                    Text("  (${cards.sumOf { it.quantity }} cards)", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
            }
            items(cards.sortedBy { it.name }, key = { "${it.cardId}|${it.variant}" }) { card ->
                DeckCardRow(
                    card, deck, DeckStatistics.ownedQuantity(card, app.collection),
                    onOpen = { nav.openCard(card.toLorcanaCard(), CardDetailMode.SET) },
                    onAdd = { app.decks.updateCardQuantity(card, deck, card.quantity + 1) },
                    onRemove = { app.decks.updateCardQuantity(card, deck, card.quantity - 1) },
                )
            }
        }
    }
}

/** Search + filters + card grid with tap-to-add. */
@Composable
private fun BuilderBrowser(deck: Deck, modifier: Modifier) {
    val app = LocalApp.current
    var search by rememberSaveable { mutableStateOf("") }
    var ownedOnly by rememberSaveable { mutableStateOf(false) }
    var ink by remember { mutableStateOf<InkColor?>(null) }
    var cost by rememberSaveable { mutableStateOf<Int?>(null) }
    var inkMenu by remember { mutableStateOf(false) }
    var costMenu by remember { mutableStateOf(false) }
    val catalog = remember(SetsDataManager.isDataLoaded) {
        SpoilerSettings.visibleCards(SetsDataManager.getAllCards()).filter { it.variant != CardVariant.FOIL }
    }
    val cards = remember(catalog, search, ownedOnly, ink, cost, deck.inkColors, app.collection.revision) {
        var list = catalog.flatMap { card ->
            if (card.variant == CardVariant.NORMAL && app.collection.isCardCollectedByName(card.name, card.setName, CardVariant.FOIL)) {
                listOf(card, card.withVariant(CardVariant.FOIL))
            } else listOf(card)
        }
        val deckInks = deck.deckInkColors
        if (deckInks.isNotEmpty()) {
            list = list.filter { card ->
                val cardInk = card.inkColor ?: return@filter true
                deckInks.any { it.rawValue.equals(cardInk, ignoreCase = true) }
            }
        }
        if (search.isNotEmpty()) list = list.filter { it.name.contains(search, true) || it.type.contains(search, true) }
        if (ownedOnly) {
            list = list.filter { app.collection.isCardCollected(it.id) || app.collection.isCardCollectedByName(it.name, it.setName, it.variant) }
        }
        ink?.let { i -> list = list.filter { it.inkColor.equals(i.rawValue, ignoreCase = true) } }
        cost?.let { c -> list = list.filter { it.cost == c } }
        list.sortedBy { it.name }
    }

    Column(modifier) {
        Row(Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.6f)).padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Search, null, tint = Color.Gray)
            Box(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                if (search.isEmpty()) Text("Search cards...", color = Color.Gray)
                BasicTextField(search, { search = it }, singleLine = true, textStyle = MaterialTheme.typography.bodyLarge.copy(color = Color.White), cursorBrush = SolidColor(LorcanaGold), modifier = Modifier.fillMaxWidth())
            }
            if (search.isNotEmpty()) Icon(Icons.Filled.Cancel, "Clear search", tint = Color.Gray, modifier = Modifier.clickable { search = "" })
        }
        Row(
            Modifier.fillMaxWidth().background(Color.Black.copy(alpha = 0.2f)).padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("Show:", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            listOf(false to "All Cards", true to "Owned Only").forEach { (value, label) ->
                val selected = ownedOnly == value
                Text(
                    label,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                    color = if (selected) LorcanaGold else Color.Gray,
                    modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(if (selected) LorcanaGold.copy(alpha = 0.2f) else Color.Transparent)
                        .clickable { ownedOnly = value }.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }
        }
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box {
                FilterPill(ink != null, onClick = { inkMenu = true }) {
                    if (ink != null) {
                        Box(Modifier.size(12.dp).clip(CircleShape).background(ink!!.color))
                        Text(" ${ink!!.rawValue}", style = MaterialTheme.typography.labelMedium, color = Color.White)
                    } else {
                        Icon(Icons.Filled.Palette, null, tint = Color.White, modifier = Modifier.size(14.dp))
                        Text(" Color", style = MaterialTheme.typography.labelMedium, color = Color.White)
                    }
                }
                DropdownMenu(inkMenu, { inkMenu = false }) {
                    DropdownMenuItem(text = { Text("All Colors") }, onClick = { ink = null; inkMenu = false })
                    (deck.deckInkColors.ifEmpty { InkColor.entries }).forEach { color ->
                        DropdownMenuItem(
                            text = { Text(color.rawValue) },
                            leadingIcon = { Box(Modifier.size(12.dp).clip(CircleShape).background(color.color)) },
                            onClick = { ink = if (ink == color) null else color; inkMenu = false },
                        )
                    }
                }
            }
            Box {
                FilterPill(cost != null, onClick = { costMenu = true }) {
                    Text(cost?.let { "Cost $it" } ?: "Cost", style = MaterialTheme.typography.labelMedium, color = Color.White)
                }
                DropdownMenu(costMenu, { costMenu = false }) {
                    DropdownMenuItem(text = { Text("All Costs") }, onClick = { cost = null; costMenu = false })
                    (0..9).forEach { c -> DropdownMenuItem(text = { Text("$c") }, onClick = { cost = if (cost == c) null else c; costMenu = false }) }
                }
            }
            Text("${cards.size} cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.align(Alignment.CenterVertically))
        }
        LazyVerticalGrid(
            columns = GridCells.Adaptive(110.dp),
            contentPadding = PaddingValues(start = 12.dp, end = 12.dp, bottom = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().navigationBarsPadding(),
        ) {
            items(cards, key = { it.variantAwareId }) { card ->
                app.decks.revision
                val inDeck = deck.cards.firstOrNull { it.cardId == card.id && it.variant == card.variant.rawValue }
                    ?: deck.cards.firstOrNull { it.cardId == card.id }
                val owned = if (ownedOnly) app.collection.getCollectedQuantityByName(card.name, card.setName, card.variant) else null
                BuilderCard(card, deck, inDeck, deck.totalQuantity(card.name), owned)
            }
        }
    }
}

@Composable
private fun FilterPill(active: Boolean, onClick: () -> Unit, content: @Composable () -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(8.dp)).background(if (active) LorcanaGold.copy(alpha = 0.2f) else LorcanaDark.copy(alpha = 0.6f))
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) { content() }
}

@Composable
private fun BuilderCard(card: LorcanaCard, deck: Deck, inDeck: DeckCard?, totalForName: Int, ownedQuantity: Int?) {
    val app = LocalApp.current
    app.decks.revision
    val quantity = inDeck?.quantity ?: 0
    val atOwnedCap = ownedQuantity != null && quantity >= ownedQuantity
    val atMax = totalForName >= deck.maxCopies(card.name) || atOwnedCap
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.alpha(if (atMax && quantity == 0) 0.55f else 1f).clickable(enabled = !atMax) { app.decks.addCard(card, deck, 1) }) {
            CardImage(
                card,
                Modifier.clip(RoundedCornerShape(8.dp)).border(if (quantity > 0) 2.dp else 1.dp, if (quantity > 0) LorcanaGold else card.rarity.color, RoundedCornerShape(8.dp)),
            )
            if (quantity > 0) {
                Box(Modifier.align(Alignment.TopEnd).padding(4.dp).size(28.dp).clip(CircleShape).background(LorcanaGold), contentAlignment = Alignment.Center) {
                    Text("$quantity", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LorcanaDark)
                }
            }
            if (card.variant == CardVariant.FOIL) Box(Modifier.align(Alignment.BottomStart).padding(4.dp)) { FoilPill() }
        }
        Text(card.name, style = MaterialTheme.typography.labelSmall, color = Color.White, maxLines = 2, textAlign = TextAlign.Center)
        if (quantity > 0 && inDeck != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.RemoveCircle, "Remove one ${card.name}", tint = SystemColors.red, modifier = Modifier.size(26.dp).clickable { app.decks.updateCardQuantity(inDeck, deck, quantity - 1) })
                Text("$quantity", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = Color.White)
                Icon(Icons.Filled.AddCircle, "Add one ${card.name}", tint = if (atMax) Color.Gray else SystemColors.green, modifier = Modifier.size(26.dp).clickable(enabled = !atMax) { app.decks.addCard(card, deck, 1) })
            }
        }
    }
}
