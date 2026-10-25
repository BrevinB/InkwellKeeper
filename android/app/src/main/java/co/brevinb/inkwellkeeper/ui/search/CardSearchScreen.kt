package co.brevinb.inkwellkeeper.ui.search

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardGroup
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** Search every card in the catalog and add it to the collection or wishlist. */
@Composable
fun CardSearchScreen(wishlistMode: Boolean = false) {
    var query by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<List<CardGroup>>(emptyList()) }
    var adding by remember { mutableStateOf<Pair<CardGroup, Boolean>?>(null) }
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val allGroups = remember(SetsDataManager.isDataLoaded) { SetsDataManager.getAllCardGroups() }

    LaunchedEffect(query, SetsDataManager.isDataLoaded) {
        delay(200)
        results = if (query.isBlank()) emptyList() else SetsDataManager.searchCardGroups(query)
    }
    val displayed = if (query.isBlank()) allGroups else results

    InkwellScaffold(title = if (wishlistMode) "Add to Wishlist" else "Search All Cards", showBack = true, snackbarHostState = snackbar) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            SearchBar(query, { query = it }, Modifier.padding(16.dp), placeholder = "Search all cards...")
            when {
                !SetsDataManager.isDataLoaded -> Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    CircularProgressIndicator(color = LorcanaGold)
                }
                displayed.isEmpty() -> EmptyState(Icons.Filled.Search, "No cards found", "No cards found for '$query'")
                else -> LazyColumn(Modifier.fillMaxSize()) {
                    items(displayed, key = { it.id }) { group ->
                        CardGroupRow(
                            group,
                            onTap = { adding = group to wishlistMode },
                            onWishlist = if (wishlistMode) null else ({ adding = group to true }),
                        )
                        HorizontalDivider(color = Color.White.copy(alpha = 0.06f))
                    }
                }
            }
        }
    }
    adding?.let { (group, toWishlist) ->
        AddCardGroupSheet(group, isWishlist = toWishlist, onDismiss = { adding = null }, onAdded = { message ->
            scope.launch { snackbar.showSnackbar(message) }
        })
    }
}
