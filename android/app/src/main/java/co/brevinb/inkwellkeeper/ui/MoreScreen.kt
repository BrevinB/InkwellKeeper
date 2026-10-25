package co.brevinb.inkwellkeeper.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ui.components.FormRowBackground
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.SectionCard
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** The overflow tabs iOS collects into "More" on iPhone, in the same order. */
private val moreItems = listOf(
    Triple("Bookshelf", Icons.Filled.AutoStories, Routes.BOOKSHELF),
    Triple("Sets", Icons.Filled.LibraryBooks, Routes.SETS),
    Triple("Trades", Icons.Filled.SwapHoriz, Routes.TRADES),
    Triple("Play", Icons.Filled.SportsEsports, Routes.PLAY),
    Triple("Wishlist", Icons.Filled.Star, Routes.WISHLIST),
    Triple("Settings", Icons.Filled.Settings, Routes.SETTINGS),
    Triple("Support", Icons.Filled.Favorite, Routes.SUPPORT),
    Triple("Rules", Icons.AutoMirrored.Filled.MenuBook, Routes.RULES),
)

@Composable
fun MoreScreen() {
    val nav = LocalNav.current
    InkwellScaffold(title = "More", large = true) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp)) {
            SectionCard(background = FormRowBackground, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp), spacing = 0.dp, cornerRadius = 12.dp) {
                moreItems.forEachIndexed { index, (title, icon, route) ->
                    MoreRow(title, icon) { nav.navigate(route) }
                    if (index < moreItems.lastIndex) HorizontalDivider(Modifier.padding(start = 56.dp), color = Color.White.copy(alpha = 0.08f))
                }
            }
        }
    }
}

@Composable
private fun MoreRow(title: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        Modifier.clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Icon(icon, null, tint = LorcanaGold)
        Text(title, style = MaterialTheme.typography.bodyLarge, color = Color.White, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
    }
}
