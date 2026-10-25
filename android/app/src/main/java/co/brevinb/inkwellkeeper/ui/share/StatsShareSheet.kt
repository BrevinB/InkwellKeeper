package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.stats.CollectionStatsSnapshot
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** "My collection" summary image: totals, value, top cards, rarity mix. */
@Composable
fun StatsShareSheet(snapshot: CollectionStatsSnapshot, onDismiss: () -> Unit) {
    val includePrices = AppSettings.shareIncludePrices
    ShareCardPresenter(
        title = "Share Collection",
        analyticsType = "stats",
        fileName = "InkwellKeeper-Collection",
        onDismiss = onDismiss,
        controls = { ToggleRow("Include prices", includePrices, { AppSettings.updateShareIncludePrices(it) }) },
    ) {
        ShareCardChrome(qrPayload = DeepLinkRouter.PLAY_STORE_URL) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("My Lorcana Collection", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = LorcanaGold)
                Row(Modifier.fillMaxWidth()) {
                    Stat("Cards", "${snapshot.totalCards}", Modifier.weight(1f))
                    Stat("Unique", "${snapshot.uniqueCards}", Modifier.weight(1f))
                    if (includePrices) Stat("Value", PricingService.formatPrice(snapshot.totalValue), Modifier.weight(1.4f))
                }
                if (snapshot.topValuable.isNotEmpty()) {
                    Text("Top cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        snapshot.topValuable.take(4).forEach { entry ->
                            CardImage(entry.card, Modifier.size(68.dp, 95.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, entry.card.rarity.color.copy(alpha = 0.7f), RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop)
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    CardRarity.entries.filter { (snapshot.rarityCounts[it] ?: 0) > 0 }.take(5).forEach { r ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(r.color))
                            Text(" ${snapshot.rarityCounts[r]}", style = MaterialTheme.typography.labelSmall, color = Color.White)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String, modifier: Modifier) {
    Column(modifier.padding(end = 8.dp)) {
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 1)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}
