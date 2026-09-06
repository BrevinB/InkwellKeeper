package co.brevinb.inkwellkeeper

import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CollectionsBookmark
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileDownload
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card as MaterialCard
import androidx.compose.material3.CardDefaults
import androidx.compose.foundation.BorderStroke
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.activity.result.contract.ActivityResultContracts.RequestPermission
import androidx.lifecycle.LifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import co.brevinb.inkwellkeeper.data.CardRepository
import co.brevinb.inkwellkeeper.data.ImportExport
import co.brevinb.inkwellkeeper.data.LocalStore
import co.brevinb.inkwellkeeper.model.Card
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.CollectionEntry
import co.brevinb.inkwellkeeper.model.Deck
import co.brevinb.inkwellkeeper.model.matches
import co.brevinb.inkwellkeeper.model.normalizedCardName
import co.brevinb.inkwellkeeper.model.health
import co.brevinb.inkwellkeeper.model.withVariant
import co.brevinb.inkwellkeeper.scanner.CameraCardScanner
import java.util.UUID

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { InkwellKeeperTheme { KeeperApp() } }
    }
}

@Composable
private fun InkwellKeeperTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = androidx.compose.material3.darkColorScheme(
            primary = IwkGold,
            secondary = IwkGold,
            surface = IwkPanel,
            background = IwkNavy,
            onSurface = Color(0xFFF7F3FF),
            onBackground = Color(0xFFF7F3FF)
        ),
        content = content
    )
}

private val IwkNavy = Color(0xFF0D0D19)
private val IwkNavyMid = Color(0xFF17152B)
private val IwkPanel = Color(0xE6191829)
private val IwkPanelLight = Color(0xFF211F34)
private val IwkGold = Color(0xFFFFD400)
private val IwkGoldDim = Color(0xFF8A7220)
private val IwkTextMuted = Color(0xFFB6B1C4)
private val IwkDivider = Color(0xFF373348)

@Composable
private fun LorcanaBackground(content: @Composable () -> Unit) {
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(IwkNavy, IwkNavyMid, Color(0xFF111022))))) {
        repeat(18) { index ->
            Box(
                Modifier
                    .size(if (index % 3 == 0) 3.dp else 2.dp)
                    .clip(CircleShape)
                    .background(IwkGold.copy(alpha = if (index % 4 == 0) 0.28f else 0.12f))
                    .align(Alignment.TopStart)
                    .offset(x = ((index * 73) % 360).dp, y = ((index * 47 + 13) % 780).dp)
            )
        }
        content()
    }
}

@Composable
private fun GlassPanel(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    MaterialCard(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = IwkPanel),
        border = BorderStroke(1.dp, IwkGoldDim),
        shape = RoundedCornerShape(18.dp),
        elevation = CardDefaults.cardElevation(0.dp)
    ) { content() }
}

private enum class Tab(val label: String) { Collection("Collection"), Scan("Scan"), Catalog("Catalog"), Decks("Decks"), Wishlist("Wishlist"), More("More") }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun KeeperApp() {
    val context = LocalContext.current
    val store = remember { LocalStore(context) }
    var cards by remember { mutableStateOf(emptyList<Card>()) }
    var collection by remember { mutableStateOf(store.collections()) }
    var decks by remember { mutableStateOf<List<Deck>>(store.decks()) }
    var selectedTab by remember { mutableStateOf(Tab.Collection) }
    var selectedCard by remember { mutableStateOf<Card?>(null) }
    var search by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }
    var deckPendingExport by remember { mutableStateOf<Deck?>(null) }

    LaunchedEffect(Unit) { cards = CardRepository(context).loadCards() }

    fun updateCard(card: Card, delta: Int) {
        val next = collection.toMutableMap()
        val current = next[card.id] ?: CollectionEntry(card.id)
        next[card.id] = current.copy(quantity = (current.quantity + delta).coerceAtLeast(0))
        collection = next
        store.saveCollections(next)
    }

    fun toggleWishlist(card: Card) {
        val next = collection.toMutableMap()
        val current = next[card.id] ?: CollectionEntry(card.id, quantity = 0)
        next[card.id] = current.copy(wishlisted = !current.wishlisted)
        collection = next
        store.saveCollections(next)
    }

    fun updateEntry(card: Card, entry: CollectionEntry) {
        val next = collection.toMutableMap()
        next[card.id] = entry
        collection = next
        store.saveCollections(next)
    }

    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val text = ImportExport.exportDreamborn(cards, collection.mapValues { it.value.quantity })
        context.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
        status = "Collection exported"
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val text = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }.orEmpty()
        val (imported, report) = ImportExport.import(text, cards)
        val next = collection.toMutableMap()
        imported.forEach { (id, quantity) ->
            val old = next[id] ?: CollectionEntry(id)
            next[id] = old.copy(quantity = old.quantity + quantity)
        }
        collection = next
        store.saveCollections(next)
        status = "Imported ${report.imported} cards" + if (report.unmatched.isEmpty()) "" else " (${report.unmatched.size} unmatched)"
    }
    val deckExportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/plain")) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        deckPendingExport?.let { deck ->
            val text = ImportExport.exportDeckText(deck, cards)
            context.contentResolver.openOutputStream(uri)?.use { it.write(text.toByteArray()) }
            status = "Deck exported"
        }
        deckPendingExport = null
    }
    val deckImportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        val text = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }.orEmpty()
        val imported = ImportExport.importDeck(text, cards)
        imported.deck?.let { deck ->
            decks = decks + deck
            store.saveDecks(decks)
            status = "Deck imported" + if (imported.unmatched.isEmpty()) "" else " (${imported.unmatched.size} unmatched)"
        } ?: run { status = "No cards matched in that deck list" }
    }

    Scaffold(
        topBar = {
                TopAppBar(
                title = { Text(if (selectedTab == Tab.Collection) "My Collection" else selectedTab.label, fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent),
                actions = {
                    IconButton(onClick = { selectedTab = Tab.Catalog }) { Icon(Icons.Default.Search, "Search cards", tint = IwkGold) }
                    IconButton(onClick = { importLauncher.launch("text/*") }) { Icon(Icons.Default.FileUpload, "Import collection", tint = IwkGold) }
                }
            )
        },
        bottomBar = {
            NavigationBar(containerColor = Color(0xE6161526), tonalElevation = 0.dp) {
                Tab.values().forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        icon = { Icon(tabIcon(tab), tab.label) },
                        colors = androidx.compose.material3.NavigationBarItemDefaults.colors(
                            selectedIconColor = IwkGold,
                            selectedTextColor = IwkGold,
                            indicatorColor = IwkPanelLight,
                            unselectedIconColor = Color.White.copy(alpha = 0.72f),
                            unselectedTextColor = Color.White.copy(alpha = 0.72f)
                        ),
                        label = { Text(tab.label) }
                    )
                }
            }
        }
    ) { padding ->
        Surface(modifier = Modifier.fillMaxSize().padding(padding), color = Color.Transparent) {
            LorcanaBackground {
                when (selectedTab) {
                    Tab.Collection -> CollectionScreen(cards, collection, search, { search = it }, { selectedCard = it }, ::updateCard, exportLauncher::launch)
                    Tab.Scan -> ScanScreen(cards, collection, ::updateCard, { selectedCard = it })
                    Tab.Catalog -> CatalogScreen(cards, collection, search, { search = it }, { selectedCard = it }, ::updateCard, ::toggleWishlist)
                    Tab.Decks -> DecksScreen(cards, decks, { next -> decks = next; store.saveDecks(next) }, { selectedCard = it }, { deck -> deckPendingExport = deck; deckExportLauncher.launch("${deck.name}.txt") }, { deckImportLauncher.launch("text/*") })
                    Tab.Wishlist -> WishlistScreen(cards, collection, search, { search = it }, { selectedCard = it }, ::updateCard, ::toggleWishlist)
                    Tab.More -> MoreScreen(collection, decks, { importLauncher.launch("text/*") }, { exportLauncher.launch("inkwell-keeper-collection.csv") })
                }
            }
        }
    }

    status?.let { message ->
        AlertDialog(onDismissRequest = { status = null }, title = { Text("Ink Well Keeper") }, text = { Text(message) }, confirmButton = { TextButton({ status = null }) { Text("OK") } })
    }
    selectedCard?.let { card ->
        CardDetailDialog(card, collection, ::updateCard, ::toggleWishlist, ::updateEntry) { selectedCard = null }
    }
}

private fun tabIcon(tab: Tab) = when (tab) {
    Tab.Collection -> Icons.Default.CollectionsBookmark
    Tab.Scan -> Icons.Default.CameraAlt
    Tab.Catalog -> Icons.Default.GridView
    Tab.Decks -> Icons.Default.Bookmark
    Tab.Wishlist -> Icons.Default.Favorite
    Tab.More -> Icons.Default.MoreHoriz
}

@Composable
private fun CollectionScreen(cards: List<Card>, collection: Map<String, CollectionEntry>, search: String, onSearch: (String) -> Unit, onSelect: (Card) -> Unit, onAdjust: (Card, Int) -> Unit, onExport: (String) -> Unit) {
    var filter by remember { mutableStateOf("All") }
    val owned = cards.filter {
        val normalQuantity = collection[it.id]?.quantity ?: 0
        val foilQuantity = if (it.variant == CardVariant.Normal) collection[it.withVariant(CardVariant.Foil).id]?.quantity ?: 0 else 0
        (normalQuantity + foilQuantity) > 0 && it.matches(search) && (filter == "All" || it.type == filter)
    }
    val total = collection.values.sumOf { it.quantity }
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            GlassPanel(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Collection Overview", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OverviewMetric(total.toString(), "Cards", Modifier.weight(1f))
                        OverviewMetric(owned.size.toString(), "Unique", Modifier.weight(1f))
                        OverviewMetric("${(owned.size * 100 / cards.size.coerceAtLeast(1))}%", "Complete", Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(14.dp))
                    CompletionBar(owned.size, cards.size)
                }
            }
            CollectionMixPanel(cards, collection)
            Spacer(Modifier.height(14.dp))
            SearchField(search, onSearch, "Search your collection")
            FilterRow(listOf("All", "Character", "Action", "Item", "Song"), filter, { filter = it })
            Spacer(Modifier.height(8.dp))
            OutlinedButton(onClick = { onExport("inkwell-keeper-collection.csv") }, colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = IwkGold), border = BorderStroke(1.dp, IwkGoldDim)) { Icon(Icons.Default.FileDownload, null); Spacer(Modifier.width(6.dp)); Text("Export Collection") }
        }
        if (owned.isEmpty()) EmptyState("Your collection is empty", "Import a collection or browse the catalog to add cards.")
        else LazyVerticalGrid(GridCells.Adaptive(150.dp), contentPadding = PaddingValues(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(owned, key = { it.id }) { card ->
                CardTile(
                    card = card,
                    quantity = collection[card.id]?.quantity ?: 0,
                    onSelect = onSelect,
                    onAdjust = onAdjust,
                    foilQuantity = if (card.variant == CardVariant.Normal) collection[card.withVariant(CardVariant.Foil).id]?.quantity ?: 0 else 0
                )
            }
        }
    }
}

@Composable
private fun CollectionMixPanel(cards: List<Card>, collection: Map<String, CollectionEntry>) {
    val owned = cards.filter { (collection[it.id]?.quantity ?: 0) > 0 }
    val rarityCounts = owned.groupingBy { it.rarity }.fold(0) { total, card -> total + (collection[card.id]?.quantity ?: 0) }
        .toList().sortedByDescending { it.second }.take(4)
    val inkCounts = owned.flatMap { card -> card.inkColor.orEmpty().split(",").map { it.trim() }.filter(String::isNotEmpty) }
        .groupingBy { it }.eachCount().toList().sortedByDescending { it.second }.take(4)
    if (owned.isEmpty()) return
    Spacer(Modifier.height(12.dp))
    GlassPanel(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text("Collection Mix", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Text("How your collection breaks down", color = IwkTextMuted, fontSize = 12.sp)
            Spacer(Modifier.height(12.dp))
            rarityCounts.forEach { (rarity, count) -> DistributionRow(rarity, count, rarityCounts.maxOf { it.second }) }
            if (inkCounts.isNotEmpty()) {
                Spacer(Modifier.height(10.dp)); Text("Ink distribution", color = IwkTextMuted, fontSize = 12.sp)
                Row(Modifier.fillMaxWidth().padding(top = 7.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) { inkCounts.forEach { (ink, count) -> Surface(color = inkColor(ink).copy(alpha = 0.2f), shape = RoundedCornerShape(50)) { Text("$ink $count", color = inkColor(ink), modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold) } } }
            }
        }
    }
}

@Composable
private fun DistributionRow(label: String, count: Int, max: Int) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        RarityBadge(label); Spacer(Modifier.width(8.dp)); Box(Modifier.weight(1f).height(6.dp).clip(RoundedCornerShape(50)).background(IwkDivider)) { Box(Modifier.fillMaxWidth(count.toFloat() / max.coerceAtLeast(1)).height(6.dp).clip(RoundedCornerShape(50)).background(Brush.horizontalGradient(listOf(IwkGold, Color(0xFFFFA928))))) }; Spacer(Modifier.width(8.dp)); Text(count.toString(), color = Color.White, fontWeight = FontWeight.Bold, fontSize = 12.sp)
    }
}

private fun inkColor(ink: String) = when (ink) { "Amber" -> Color(0xFFFFB52E); "Amethyst" -> Color(0xFFB35ADE); "Emerald" -> Color(0xFF53D477); "Ruby" -> Color(0xFFFF4C5D); "Sapphire" -> Color(0xFF5C9BFF); "Steel" -> Color(0xFFBFC2CC); else -> IwkTextMuted }

@Composable
private fun ScanScreen(cards: List<Card>, collection: Map<String, CollectionEntry>, onAdjust: (Card, Int) -> Unit, onSelect: (Card) -> Unit) {
    val context = LocalContext.current
    val owner = context as? LifecycleOwner
    var hasPermission by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    var recognizedText by remember { mutableStateOf("") }
    var scanner by remember { mutableStateOf<CameraCardScanner?>(null) }
    val permissionLauncher = rememberLauncherForActivityResult(RequestPermission()) { hasPermission = it }
    val matchedCard = remember(recognizedText, cards) {
        val text = recognizedText.normalizedCardName()
        cards.asSequence().filter { it.variant.name == "Normal" }.sortedByDescending { it.name.length }
            .firstOrNull { text.contains(it.name.normalizedCardName()) }
    }

    DisposableEffect(hasPermission) { onDispose { scanner?.stop(); scanner = null } }

    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text("Scan Cards", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text("Point your camera at a Lorcana card", color = IwkTextMuted)
        Spacer(Modifier.height(14.dp))
        if (!hasPermission) {
            GlassPanel(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(Icons.Default.CameraAlt, null, tint = IwkGold, modifier = Modifier.size(48.dp))
                    Spacer(Modifier.height(12.dp)); Text("Camera access is needed to recognize cards", fontWeight = FontWeight.Bold)
                    Text("Recognition runs on this device and scan images are not uploaded.", color = IwkTextMuted)
                    Spacer(Modifier.height(16.dp)); Button({ permissionLauncher.launch(Manifest.permission.CAMERA) }, colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = IwkGold, contentColor = Color.Black)) { Text("Allow Camera") }
                }
            }
        } else {
            Box(Modifier.fillMaxWidth().height(390.dp).clip(RoundedCornerShape(20.dp)).border(2.dp, IwkGold, RoundedCornerShape(20.dp))) {
                AndroidView(
                    factory = { viewContext ->
                        androidx.camera.view.PreviewView(viewContext).also { preview ->
                            val newScanner = CameraCardScanner(viewContext, preview) { text -> recognizedText = text }
                            scanner = newScanner
                            owner?.let { newScanner.start(it) }
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
                Box(Modifier.fillMaxWidth().height(2.dp).align(Alignment.Center).background(IwkGold.copy(alpha = 0.85f)))
                Surface(Modifier.align(Alignment.TopCenter).padding(top = 14.dp), color = Color(0xCC141324), contentColor = IwkGold, shape = RoundedCornerShape(50)) { Text(if (matchedCard == null) "Scanning…" else "Recognized", Modifier.padding(horizontal = 14.dp, vertical = 7.dp), fontWeight = FontWeight.Bold, fontSize = 12.sp) }
            }
            Spacer(Modifier.height(14.dp))
            matchedCard?.let { card ->
                GlassPanel(Modifier.fillMaxWidth()) {
                    Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        CardArt(card, Modifier.width(76.dp).aspectRatio(0.69f).clip(RoundedCornerShape(8.dp)))
                        Column(Modifier.padding(start = 12.dp).weight(1f)) { Text(card.name, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis); Text("${card.setCode} · ${card.rarity}", color = IwkTextMuted, fontSize = 12.sp); Spacer(Modifier.height(8.dp)); Text("Owned: ${collection[card.id]?.quantity ?: 0}", color = IwkGold, fontWeight = FontWeight.Bold) }
                        Button({ onAdjust(card, 1) }, colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = IwkGold, contentColor = Color.Black)) { Icon(Icons.Default.Add, null); Text(" Add") }
                    }
                }
            } ?: Text("Hold the card inside the frame until its name is recognized.", color = IwkTextMuted, modifier = Modifier.align(Alignment.CenterHorizontally))
        }
    }
}

@Composable
private fun CatalogScreen(cards: List<Card>, collection: Map<String, CollectionEntry>, search: String, onSearch: (String) -> Unit, onSelect: (Card) -> Unit, onAdjust: (Card, Int) -> Unit, onWishlist: (Card) -> Unit) {
    var mode by remember { mutableStateOf("Cards") }
    var filter by remember { mutableStateOf("All") }
    if (mode == "Sets") {
        SetProgressScreen(cards, collection)
        return
    }
    val filtered = cards.filter { it.matches(search) && (filter == "All" || it.type == filter) }.take(1000)
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text("Card Catalog", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("${cards.size} cards across Lorcana sets", color = IwkTextMuted)
            FilterRow(listOf("Cards", "Sets"), mode, { mode = it })
            Spacer(Modifier.height(12.dp)); SearchField(search, onSearch, "Search cards, sets, or IDs")
            FilterRow(listOf("All", "Character", "Action", "Item", "Song"), filter, { filter = it })
        }
        LazyVerticalGrid(GridCells.Adaptive(150.dp), contentPadding = PaddingValues(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(filtered, key = { it.id }) { card ->
                CardTile(card, collection[card.id]?.quantity ?: 0, onSelect, onAdjust, collection[card.id]?.wishlisted == true, onWishlist, if (card.variant == CardVariant.Normal) collection[card.withVariant(CardVariant.Foil).id]?.quantity ?: 0 else 0)
            }
        }
    }
}

@Composable
private fun SetProgressScreen(cards: List<Card>, collection: Map<String, CollectionEntry>) {
    val sets = cards.filter { it.variant.name == "Normal" }.groupBy { it.setName }.toList().sortedBy { it.first }
    Column(Modifier.fillMaxSize().padding(horizontal = 16.dp, vertical = 12.dp)) {
        Text("Card Sets", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text("Track your progress across every Lorcana set", color = IwkTextMuted)
        Spacer(Modifier.height(12.dp))
        LazyColumn(contentPadding = PaddingValues(bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(sets, key = { it.first }) { (setName, setCards) ->
                val owned = setCards.count { (collection[it.id]?.quantity ?: 0) > 0 }
                GlassPanel(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(setName, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                            Text("${(owned * 100 / setCards.size.coerceAtLeast(1))}%", color = IwkGold, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                        }
                        Spacer(Modifier.height(4.dp)); Text("$owned of ${setCards.size} cards", color = IwkTextMuted, fontSize = 12.sp)
                        Spacer(Modifier.height(10.dp)); CompletionBar(owned, setCards.size)
                    }
                }
            }
        }
    }
}

@Composable
private fun WishlistScreen(cards: List<Card>, collection: Map<String, CollectionEntry>, search: String, onSearch: (String) -> Unit, onSelect: (Card) -> Unit, onAdjust: (Card, Int) -> Unit, onWishlist: (Card) -> Unit) {
    val wishlist = cards.filter { collection[it.id]?.wishlisted == true && it.matches(search) }
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text("Wishlist", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("${wishlist.size} cards you want to find next", color = IwkTextMuted)
            Spacer(Modifier.height(12.dp)); SearchField(search, onSearch, "Search your wishlist")
        }
        if (wishlist.isEmpty()) EmptyState("Your wishlist is empty", "Tap the heart on any catalog card to save it here.")
        else LazyVerticalGrid(GridCells.Adaptive(150.dp), contentPadding = PaddingValues(12.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            items(wishlist, key = { it.id }) { card -> CardTile(card, collection[card.id]?.quantity ?: 0, onSelect, onAdjust, true, onWishlist) }
        }
    }
}

@Composable
private fun SearchField(value: String, onValueChange: (String) -> Unit, placeholder: String) {
    OutlinedTextField(value, onValueChange, modifier = Modifier.fillMaxWidth(), singleLine = true, placeholder = { Text(placeholder, color = IwkTextMuted) }, leadingIcon = { Icon(Icons.Default.Search, null, tint = IwkGold) }, colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(focusedBorderColor = IwkGold, unfocusedBorderColor = IwkGoldDim, focusedContainerColor = IwkPanel, unfocusedContainerColor = IwkPanel))
}

@Composable
private fun FilterRow(options: List<String>, selected: String, onSelected: (String) -> Unit) {
    Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        options.forEach { option ->
            AssistChip(onClick = { onSelected(option) }, label = { Text(option) }, border = BorderStroke(1.dp, if (selected == option) IwkGold else IwkGoldDim), colors = androidx.compose.material3.AssistChipDefaults.assistChipColors(containerColor = if (selected == option) IwkGold.copy(alpha = 0.18f) else IwkPanel, labelColor = if (selected == option) IwkGold else IwkTextMuted))
        }
    }
}

@Composable
private fun OverviewMetric(value: String, label: String, modifier: Modifier) {
    Column(modifier.padding(vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text(value, color = IwkGold, fontSize = 25.sp, fontWeight = FontWeight.Bold); Text(label, color = IwkTextMuted, fontSize = 12.sp) }
}

@Composable
private fun CompletionBar(complete: Int, total: Int) {
    val progress = complete.toFloat() / total.coerceAtLeast(1)
    Column {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("Set completion", color = IwkTextMuted, fontSize = 12.sp); Text("${(progress * 100).toInt()}%", color = IwkGold, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
        Spacer(Modifier.height(6.dp))
        Box(Modifier.fillMaxWidth().height(7.dp).clip(RoundedCornerShape(50)).background(IwkDivider)) { Box(Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).height(7.dp).clip(RoundedCornerShape(50)).background(Brush.horizontalGradient(listOf(IwkGold, Color(0xFFFFB300)))) ) }
    }
}

@Composable
private fun CardTile(card: Card, quantity: Int, onSelect: (Card) -> Unit, onAdjust: (Card, Int) -> Unit, wishlisted: Boolean = false, onWishlist: (Card) -> Unit = {}, foilQuantity: Int = 0) {
    MaterialCard(modifier = Modifier.fillMaxWidth().clickable { onSelect(card) }, colors = CardDefaults.cardColors(containerColor = IwkPanel), border = BorderStroke(1.dp, if (card.variant.name != "Normal") IwkGold else IwkGoldDim), shape = RoundedCornerShape(14.dp), elevation = CardDefaults.cardElevation(4.dp)) {
        Column {
            Box {
                CardArt(card, Modifier.fillMaxWidth().aspectRatio(0.69f).clip(RoundedCornerShape(topStart = 14.dp, topEnd = 14.dp)))
                if (quantity > 0) Surface(Modifier.align(Alignment.TopEnd).padding(8.dp), color = IwkGold, contentColor = Color.Black, shape = RoundedCornerShape(50)) { Text("×$quantity", Modifier.padding(horizontal = 8.dp, vertical = 4.dp), fontWeight = FontWeight.Bold, fontSize = 12.sp) }
            }
            Column(Modifier.padding(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(card.name, modifier = Modifier.weight(1f), fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis, fontSize = 14.sp, color = Color.White)
                    if (wishlisted) Icon(Icons.Default.Favorite, "Wishlisted", tint = Color(0xFFB54444), modifier = Modifier.size(16.dp))
                }
                Row(verticalAlignment = Alignment.CenterVertically) { Text("${card.setCode} · ${card.variant.name}", color = IwkTextMuted, fontSize = 11.sp, maxLines = 1, modifier = Modifier.weight(1f)); RarityBadge(card.rarity) }
                if (card.variant == CardVariant.Normal && foilQuantity > 0) {
                    Row(Modifier.fillMaxWidth().padding(top = 1.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text("Foil ×$foilQuantity", color = IwkGold, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                        TextButton(onClick = { onSelect(card.withVariant(CardVariant.Foil)) }, contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)) { Icon(Icons.Default.Star, "Manage foil", modifier = Modifier.size(15.dp)); Text("Manage foil", fontSize = 11.sp) }
                    }
                } else if (card.variant == CardVariant.Normal) {
                    TextButton(onClick = { onSelect(card.withVariant(CardVariant.Foil)) }, modifier = Modifier.fillMaxWidth(), contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)) { Icon(Icons.Default.Star, "Add foil", modifier = Modifier.size(15.dp)); Text("Add foil", fontSize = 11.sp) }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth()) {
                    IconButton(onClick = { onAdjust(card, -1) }, modifier = Modifier.size(28.dp)) { Icon(Icons.Default.Remove, "Remove", modifier = Modifier.size(16.dp)) }
                    Text(quantity.toString(), fontWeight = FontWeight.Bold)
                    IconButton(onClick = { onAdjust(card, 1) }, modifier = Modifier.size(28.dp)) { Icon(Icons.Default.Add, "Add", modifier = Modifier.size(16.dp)) }
                }
            }
        }
    }
}

@Composable
private fun CardArt(card: Card, modifier: Modifier = Modifier.fillMaxWidth().height(170.dp)) {
    val tint = when (card.inkColor) { "Amber" -> Color(0xFFFFD98A); "Amethyst" -> Color(0xFFD7B5F0); "Emerald" -> Color(0xFFB7E6C4); "Ruby" -> Color(0xFFFFB6B0); "Sapphire" -> Color(0xFFAFCBF5); "Steel" -> Color(0xFFC9C9D0); else -> Color(0xFFE6E0D4) }
    Box(modifier.background(tint), contentAlignment = Alignment.Center) {
        if (card.imageUrl.isBlank()) {
            Text(card.name.take(1).uppercase(), fontSize = 36.sp, fontWeight = FontWeight.Bold, color = Color.White)
        } else {
            AsyncImage(model = card.imageUrl, contentDescription = card.name, modifier = Modifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
        }
        if (card.variant.isHolographic()) {
            FoilCardOverlay(card.variant, Modifier.fillMaxSize())
        }
    }
}

@Composable
private fun RarityBadge(rarity: String) {
    val color = when (rarity) { "Common" -> Color(0xFF777785); "Uncommon" -> Color(0xFF28A95A); "Rare" -> Color(0xFF2189D1); "Super Rare" -> Color(0xFFB333D8); "Legendary" -> Color(0xFFE68327); "Enchanted", "Iconic" -> IwkGold; else -> Color(0xFFB85A98) }
    Surface(color = color, shape = RoundedCornerShape(50), contentColor = Color.White) { Text(rarity, modifier = Modifier.padding(horizontal = 7.dp, vertical = 2.dp), fontSize = 9.sp, fontWeight = FontWeight.Bold, maxLines = 1) }
}

@Composable
private fun CardDetailDialog(card: Card, collection: Map<String, CollectionEntry>, onAdjust: (Card, Int) -> Unit, onWishlist: (Card) -> Unit, onUpdateEntry: (Card, CollectionEntry) -> Unit, onDismiss: () -> Unit) {
    val context = LocalContext.current
    var selectedVariant by remember(card.id) { mutableStateOf(card.variant) }
    val displayCard = card.withVariant(selectedVariant)
    val entry = collection[displayCard.id] ?: CollectionEntry(displayCard.id)
    var condition by remember(displayCard.id, entry.condition) { mutableStateOf(entry.condition) }
    var notes by remember(displayCard.id, entry.notes) { mutableStateOf(entry.notes) }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(displayCard.name) }, text = {
        Column {
            CardArt(displayCard)
            if (card.variant == CardVariant.Normal) {
                Spacer(Modifier.height(8.dp))
                Text("Finish", color = IwkTextMuted, fontSize = 12.sp)
                FilterRow(listOf(CardVariant.Normal.name, CardVariant.Foil.name), selectedVariant.name) { selectedVariant = CardVariant.valueOf(it) }
            } else {
                Spacer(Modifier.height(5.dp)); Text(displayCard.variant.name, color = IwkGold, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(6.dp)); Text("${displayCard.setName} · ${displayCard.uniqueId.orEmpty()}", color = Color.Gray)
            Text("${displayCard.rarity} · ${displayCard.type} · Cost ${displayCard.cost}", fontWeight = FontWeight.SemiBold)
            displayCard.inkColor?.let { Text("$it ink${if (displayCard.inkwell) " · Inkwell" else ""}") }
            Spacer(Modifier.height(8.dp)); Text(displayCard.cardText.ifBlank { "No card text available." }, maxLines = 7, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(10.dp)); Row(verticalAlignment = Alignment.CenterVertically) { Text("${displayCard.variant.name} owned: ${entry.quantity}", modifier = Modifier.weight(1f)); IconButton({ onAdjust(displayCard, -1) }) { Icon(Icons.Default.Remove, "Remove ${displayCard.variant.name}") }; IconButton({ onAdjust(displayCard, 1) }) { Icon(Icons.Default.Add, "Add ${displayCard.variant.name}") } }
            Text("Condition", color = IwkTextMuted, fontSize = 12.sp, modifier = Modifier.padding(top = 6.dp))
            FilterRow(listOf("Near Mint", "Lightly Played", "Moderately Played", "Damaged"), condition, { condition = it })
            OutlinedTextField(notes, { notes = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Notes") }, minLines = 2, maxLines = 4, colors = androidx.compose.material3.OutlinedTextFieldDefaults.colors(focusedBorderColor = IwkGold, unfocusedBorderColor = IwkGoldDim, focusedContainerColor = IwkPanel, unfocusedContainerColor = IwkPanel))
            OutlinedButton(onClick = {
                val url = "https://www.tcgplayer.com/search/all/product?q=${Uri.encode(displayCard.name)}"
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            }, modifier = Modifier.fillMaxWidth(), colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = IwkGold), border = BorderStroke(1.dp, IwkGoldDim)) { Icon(Icons.Default.ShoppingCart, null); Spacer(Modifier.width(6.dp)); Text("Find prices") }
            TextButton({ onWishlist(displayCard) }) { Icon(Icons.Default.Favorite, null); Spacer(Modifier.width(4.dp)); Text(if (entry.wishlisted) "Remove from wishlist" else "Add to wishlist", color = IwkGold) }
        }
    }, confirmButton = { TextButton({ onUpdateEntry(displayCard, entry.copy(condition = condition, notes = notes)); onDismiss() }) { Text("Save", color = IwkGold) } }, dismissButton = { TextButton(onDismiss) { Text("Cancel") } })
}

@Composable
private fun DecksScreen(cards: List<Card>, decks: List<Deck>, onDecksChanged: (List<Deck>) -> Unit, onSelect: (Card) -> Unit, onExport: (Deck) -> Unit, onImport: () -> Unit) {
    var selectedDeck by remember { mutableStateOf<Deck?>(null) }
    var showingCreate by remember { mutableStateOf(false) }
    if (selectedDeck != null) {
        DeckDetailScreen(cards, selectedDeck!!, { updated -> onDecksChanged(decks.map { if (it.id == updated.id) updated else it }); selectedDeck = updated }, { selectedDeck = null }, onSelect)
        return
    }
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) { Text("Decks", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); OutlinedButton(onImport, colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = IwkGold), border = BorderStroke(1.dp, IwkGoldDim)) { Icon(Icons.Default.FileUpload, null); Text(" Import") }; Spacer(Modifier.width(8.dp)); Button({ showingCreate = true }, colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = IwkGold, contentColor = Color.Black)) { Icon(Icons.Default.Add, null); Text(" New") } }
        Spacer(Modifier.height(12.dp))
        if (decks.isEmpty()) EmptyState("No decks yet", "Create a deck to start testing ideas.")
        else LazyColumn(verticalArrangement = Arrangement.spacedBy(10.dp)) { items(decks, key = { it.id }) { deck -> GlassPanel(Modifier.fillMaxWidth().clickable { selectedDeck = deck }) { Column(Modifier.padding(16.dp)) { Row(verticalAlignment = Alignment.CenterVertically) { Text(deck.name, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); Text("${deck.totalCards}/60", color = IwkGold, fontWeight = FontWeight.Bold) }; Spacer(Modifier.height(5.dp)); Text(deck.format, color = IwkTextMuted, fontSize = 12.sp); Spacer(Modifier.height(10.dp)); CompletionBar(deck.totalCards.coerceAtMost(60), 60); Spacer(Modifier.height(8.dp)); TextButton(onClick = { onExport(deck) }) { Icon(Icons.Default.FileDownload, null); Spacer(Modifier.width(5.dp)); Text("Export deck list", color = IwkGold) } } } } }
    }
    if (showingCreate) {
        var name by remember { mutableStateOf("") }
        AlertDialog(onDismissRequest = { showingCreate = false }, title = { Text("New deck") }, text = { OutlinedTextField(name, { name = it }, label = { Text("Deck name") }, singleLine = true) }, confirmButton = { TextButton({ if (name.isNotBlank()) { onDecksChanged(decks + Deck(UUID.randomUUID().toString(), name)); showingCreate = false } }) { Text("Create") } }, dismissButton = { TextButton({ showingCreate = false }) { Text("Cancel") } })
    }
}

@Composable
private fun DeckDetailScreen(cards: List<Card>, deck: Deck, onUpdate: (Deck) -> Unit, onBack: () -> Unit, onSelect: (Card) -> Unit) {
    var search by remember { mutableStateOf("") }
    val visible = cards.filter { it.matches(search) }.take(100)
    val health = remember(deck, cards) { deck.health(cards) }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) { IconButton(onBack) { Icon(Icons.Default.ArrowBack, "Back") }; Column { Text(deck.name, fontWeight = FontWeight.Bold); Text("${deck.totalCards} / 60 cards", color = Color.Gray, fontSize = 12.sp) } }
        DeckHealthPanel(health)
        Divider(color = IwkDivider); SearchField(search, { search = it }, "Add cards to deck")
        LazyColumn(contentPadding = PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            items(visible, key = { it.id }) { card ->
                val quantity = deck.cardQuantities[card.id] ?: 0
                Row(Modifier.fillMaxWidth().clickable { onSelect(card) }.padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text(card.name); Text("${card.setCode} · ${card.inkColor.orEmpty()}", color = Color.Gray, fontSize = 12.sp) }; IconButton({ onUpdate(deck.copy(cardQuantities = deck.cardQuantities + (card.id to (quantity - 1).coerceAtLeast(0)))) }) { Icon(Icons.Default.Remove, null) }; Text(quantity.toString(), fontWeight = FontWeight.Bold); IconButton({ onUpdate(deck.copy(cardQuantities = deck.cardQuantities + (card.id to (quantity + 1)))) }) { Icon(Icons.Default.Add, null) } }
            }
        }
    }
}

@Composable
private fun DeckHealthPanel(health: co.brevinb.inkwellkeeper.model.DeckHealth) {
    GlassPanel(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp)) {
        Column(Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(if (health.isValid) "Deck ready" else "Deck in progress", color = if (health.isValid) Color(0xFF65D979) else IwkGold, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
                Text("${health.totalCards}/60", color = IwkGold, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(8.dp)); CompletionBar(health.totalCards.coerceAtMost(60), 60)
            Spacer(Modifier.height(8.dp)); Text("${health.uniqueCards} unique · ${health.inkColors.joinToString(" · ").ifBlank { "No ink colors yet" }}", color = IwkTextMuted, fontSize = 12.sp)
            health.issues.take(2).forEach { issue -> Text("• $issue", color = Color(0xFFFFB56B), fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp)) }
        }
    }
}

@Composable
private fun MoreScreen(collection: Map<String, CollectionEntry>, decks: List<Deck>, onImport: () -> Unit, onExport: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("More", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold); Spacer(Modifier.height(12.dp))
        GlassPanel(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text("Data", fontWeight = FontWeight.Bold); Text("${collection.values.sumOf { it.quantity }} cards · ${decks.size} decks", color = IwkTextMuted); Spacer(Modifier.height(12.dp)); Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { OutlinedButton(onImport, colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = IwkGold), border = BorderStroke(1.dp, IwkGoldDim)) { Icon(Icons.Default.FileUpload, null); Text(" Import") }; OutlinedButton(onExport, colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(contentColor = IwkGold), border = BorderStroke(1.dp, IwkGoldDim)) { Icon(Icons.Default.FileDownload, null); Text(" Export") } } } }
        Spacer(Modifier.height(12.dp)); GlassPanel(Modifier.fillMaxWidth()) { Column(Modifier.padding(16.dp)) { Text("Ink Well Keeper for Android", fontWeight = FontWeight.Bold); Spacer(Modifier.height(5.dp)); Text("Local collection storage with iOS-compatible CSV and deck-list workflows.", color = IwkTextMuted); Spacer(Modifier.height(12.dp)); Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { InfoPill("LOCAL DATA"); InfoPill("MVP BUILD") } } }
    }
}

@Composable
private fun InfoPill(text: String) { Surface(color = IwkGold.copy(alpha = 0.15f), shape = RoundedCornerShape(50), contentColor = IwkGold) { Text(text, Modifier.padding(horizontal = 10.dp, vertical = 5.dp), fontSize = 10.sp, fontWeight = FontWeight.Bold) } }

@Composable
private fun EmptyState(title: String, message: String) { Column(Modifier.fillMaxWidth().padding(40.dp), horizontalAlignment = Alignment.CenterHorizontally) { Icon(Icons.Default.CollectionsBookmark, null, tint = Color(0xFFD59A35), modifier = Modifier.size(48.dp)); Spacer(Modifier.height(12.dp)); Text(title, fontWeight = FontWeight.Bold); Text(message, color = Color.Gray) } }
