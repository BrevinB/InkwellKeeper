package co.brevinb.inkwellkeeper.ui.collection

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardFilter
import co.brevinb.inkwellkeeper.model.InkColorFilter
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.SortOption
import co.brevinb.inkwellkeeper.model.VariantFilter
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardTile
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FilterBar
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.storage.StorageShelf
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Filters and sorts the collection exactly as the iOS Collection tab does. */
object CollectionFilter {
    fun apply(
        cards: List<LorcanaCard>,
        search: String,
        filter: CardFilter,
        ink: InkColorFilter,
        variant: VariantFilter,
        sort: SortOption,
        unsortedKeys: Set<String>?,
    ): List<LorcanaCard> {
        var result = cards
        if (unsortedKeys != null) result = result.filter { it.identityKey in unsortedKeys }
        if (search.isNotEmpty()) {
            result = result.filter { it.name.contains(search, ignoreCase = true) || it.cardText.contains(search, ignoreCase = true) }
        }
        filter.type?.let { type -> result = result.filter { it.type == type } }
        if (ink != InkColorFilter.ALL) {
            result = result.filter { card -> card.inkColor?.split(",")?.map { it.trim() }?.contains(ink.rawValue) == true }
        }
        if (variant != VariantFilter.ALL) result = result.filter { variant.matches(it.variant) }
        return when (sort) {
            SortOption.RECENTLY_ADDED -> result.sortedByDescending { it.dateAdded ?: Long.MIN_VALUE }
            SortOption.NAME -> result.sortedBy { it.name }
            SortOption.COST -> result.sortedByDescending { it.cost }
            SortOption.RARITY -> result.sortedByDescending { it.rarity.sortOrder }
            SortOption.SET -> {
                val order = SetsDataManager.sets.associate { (it.name) to Pair(it.setNumber?.toIntOrNull() ?: Int.MAX_VALUE, it.releaseDate ?: "") }
                result.sortedWith(
                    compareBy<LorcanaCard>(
                        { order[it.setName]?.first ?: Int.MAX_VALUE },
                        { order[it.setName]?.second ?: "" },
                        { it.setName },
                    ),
                )
            }
            SortOption.PRICE -> result.sortedByDescending { it.price ?: 0.0 }
        }
    }
}

@Composable
fun CollectionScreen(onScanTapped: () -> Unit) {
    val app = LocalApp.current
    val nav = LocalNav.current
    var search by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf(CardFilter.ALL) }
    var ink by rememberSaveable { mutableStateOf(InkColorFilter.ALL) }
    var variant by rememberSaveable { mutableStateOf(VariantFilter.ALL) }
    var sort by rememberSaveable { mutableStateOf(SortOption.RECENTLY_ADDED) }
    var unsortedOnly by rememberSaveable { mutableStateOf(false) }
    var menu by remember { mutableStateOf(false) }

    val collected = app.collection.collectedCards
    val unsorted = app.storage.unsortedQuantitiesByIdentity()
    val unsortedCount = unsorted.values.sum()
    val cards = remember(collected, search, filter, ink, variant, sort, unsortedOnly, app.storage.revision) {
        CollectionFilter.apply(collected, search, filter, ink, variant, sort, if (unsortedOnly) unsorted.keys else null)
    }

    InkwellScaffold(
        title = "My Collection",
        large = true,
        actions = {
            IconButton(onClick = { nav.navigate(Routes.search()) }) {
                Icon(Icons.Filled.Search, contentDescription = "Search card catalog")
            }
            IconButton(onClick = { menu = true }) {
                Icon(Icons.Filled.MoreVert, contentDescription = "More options")
            }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                DropdownMenuItem(
                    text = { Text("Bulk Import") },
                    leadingIcon = { Icon(Icons.Filled.Download, null) },
                    onClick = { menu = false; nav.navigate(Routes.IMPORT) },
                )
                DropdownMenuItem(
                    text = { Text("Export Collection") },
                    leadingIcon = { Icon(Icons.Filled.IosShare, null) },
                    onClick = { menu = false; nav.navigate(Routes.EXPORT) },
                )
                HorizontalDivider()
                val total = app.collection.collectedRows.sumOf { (it.price ?: 0.0) }
                val count = app.collection.collectedRows.sumOf { it.quantity }
                DropdownMenuItem(
                    text = {
                        Column {
                            Text(if (total > 0) PricingService.formatPrice(total) else "—", color = if (total > 0) LorcanaGold else Color.Gray)
                            Text("$count cards", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                        }
                    },
                    onClick = { menu = false; nav.navigate(Routes.STATS) },
                )
                HorizontalDivider()
                DropdownMenuItem(
                    text = { Text("Settings") },
                    leadingIcon = { Icon(Icons.Filled.Settings, null) },
                    onClick = { menu = false; nav.navigate(Routes.SETTINGS) },
                )
            }
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(
                Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.3f)).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SearchBar(search, { search = it })
                FilterBar(filter, { filter = it }, ink, { ink = it }, variant, { variant = it }, sort, { sort = it })
                if (collected.isNotEmpty()) {
                    StorageShelf(unsortedCount, unsortedOnly, { unsortedOnly = !unsortedOnly }, Modifier.padding(bottom = 8.dp))
                }
            }
            when {
                !app.isReady -> Row(Modifier.fillMaxSize(), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(color = LorcanaGold)
                }
                cards.isEmpty() -> CollectionEmptyState(
                    isSearching = search.isNotBlank() || collected.isNotEmpty(),
                    onImport = { nav.navigate(Routes.IMPORT) },
                    onScan = onScanTapped,
                    onManualAdd = { nav.navigate(Routes.search()) },
                )
                else -> LazyVerticalGrid(
                    columns = GridCells.Adaptive(160.dp),
                    contentPadding = PaddingValues(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.fillMaxSize(),
                ) {
                    items(cards, key = { it.variantAwareId }) { card ->
                        CardTile(card, isWishlist = false, onClick = { nav.openCard(card, CardDetailMode.COLLECTION) }, modifier = Modifier.animateItem())
                    }
                    item(span = { GridItemSpan(maxLineSpan) }) { Spacer(Modifier.padding(8.dp)) }
                }
            }
        }
    }
}

@Composable
private fun CollectionEmptyState(isSearching: Boolean, onImport: () -> Unit, onScan: () -> Unit, onManualAdd: () -> Unit) {
    EmptyState(
        icon = if (isSearching) Icons.Filled.Search else Icons.Filled.GridOn,
        title = if (isSearching) "No Results Found" else "Your Collection is Empty",
        message = if (isSearching) "Try adjusting your search or filters" else "Start building your collection!",
    ) {
        if (!isSearching) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                LorcanaPrimaryButton(onClick = onImport, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Download, null)
                    Spacer(Modifier.width(8.dp))
                    Text("Import from Dreamborn")
                }
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    LorcanaSecondaryButton(onClick = onScan, modifier = Modifier.weight(1f)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Filled.CameraAlt, null)
                            Text("Scan Cards", style = MaterialTheme.typography.labelMedium)
                        }
                    }
                    LorcanaSecondaryButton(onClick = onManualAdd, modifier = Modifier.weight(1f)) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Icon(Icons.Filled.AddCircle, null)
                            Text("Manual Add", style = MaterialTheme.typography.labelMedium)
                        }
                    }
                }
            }
        }
    }
}
