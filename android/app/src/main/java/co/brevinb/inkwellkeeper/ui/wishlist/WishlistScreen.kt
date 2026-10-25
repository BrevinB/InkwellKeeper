package co.brevinb.inkwellkeeper.ui.wishlist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.StarBorder
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.CardFilter
import co.brevinb.inkwellkeeper.model.InkColorFilter
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.SortOption
import co.brevinb.inkwellkeeper.model.VariantFilter
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.collection.CollectionFilter
import co.brevinb.inkwellkeeper.ui.components.AsyncPriceView
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FilterBar
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.PriceStyle
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SearchBar
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

@Composable
fun WishlistScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    var search by rememberSaveable { mutableStateOf("") }
    var filter by rememberSaveable { mutableStateOf(CardFilter.ALL) }
    var ink by rememberSaveable { mutableStateOf(InkColorFilter.ALL) }
    var variant by rememberSaveable { mutableStateOf(VariantFilter.ALL) }
    var sort by rememberSaveable { mutableStateOf(SortOption.RECENTLY_ADDED) }
    val all = app.collection.wishlistCards
    val cards = remember(all, search, filter, ink, variant, sort) { CollectionFilter.apply(all, search, filter, ink, variant, sort, null) }

    InkwellScaffold(
        title = "Wishlist",
        large = true,
        showBack = true,
        actions = { IconButton(onClick = { nav.navigate(Routes.search(wishlist = true)) }) { Icon(Icons.Filled.Add, contentDescription = "Add to wishlist") } },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(Modifier.background(LorcanaDark.copy(alpha = 0.3f)).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                SearchBar(search, { search = it })
                FilterBar(filter, { filter = it }, ink, { ink = it }, variant, { variant = it }, sort, { sort = it })
            }
            if (cards.isEmpty()) {
                EmptyState(Icons.Filled.StarBorder, "Your Wishlist is Empty", "Add cards you're hoping to find!")
            } else {
                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(cards, key = { it.variantAwareId }) { card -> WishlistRow(card) }
                }
            }
        }
    }
}

@Composable
private fun WishlistRow(card: LorcanaCard) {
    val app = LocalApp.current
    val nav = LocalNav.current
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f))
            .clickable { nav.openCard(card, CardDetailMode.WISHLIST) }.padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CardImage(card, Modifier.size(60.dp, 84.dp).clip(RoundedCornerShape(8.dp)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(card.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(card.setName, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            RarityBadge(card.rarity)
            AsyncPriceView(card, PriceStyle.INLINE)
        }
        IconButton(onClick = {
            app.collection.addCard(card, 1)
            app.collection.removeFromWishlist(card)
        }) { Icon(Icons.Filled.AddCircle, contentDescription = "Move to collection", tint = LorcanaGold) }
        IconButton(onClick = { app.collection.removeFromWishlist(card) }) { Icon(Icons.Filled.Delete, contentDescription = "Remove from wishlist", tint = SystemColors.red) }
    }
}
