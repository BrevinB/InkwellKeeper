package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.scan.ScannedCardEntry
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** "Today's haul": the best pulls from a scan session. */
@Composable
fun HaulShareSheet(entries: List<ScannedCardEntry>, onDismiss: () -> Unit) {
    var prices by remember { mutableStateOf<Map<String, Double>>(emptyMap()) }
    LaunchedEffect(entries) {
        prices = entries.mapNotNull { e -> PricingService.getMarketPrice(e.card)?.let { e.id to it } }.toMap()
    }
    val includePrices = AppSettings.shareIncludePrices
    val top = entries.sortedWith(compareByDescending<ScannedCardEntry> { prices[it.id] ?: 0.0 }.thenByDescending { it.card.rarity.sortOrder }).take(4)
    val total = entries.sumOf { (prices[it.id] ?: 0.0) * it.quantity }
    ShareCardPresenter(
        title = "Share Your Haul",
        analyticsType = "haul",
        fileName = "InkwellKeeper-Haul",
        onDismiss = onDismiss,
        controls = { ToggleRow("Include prices", includePrices, { AppSettings.updateShareIncludePrices(it) }) },
    ) {
        ShareCardChrome(qrPayload = DeepLinkRouter.PLAY_STORE_URL) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("Today's Haul", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = LorcanaGold)
                Text("${entries.sumOf { it.quantity }} cards scanned" + if (includePrices && total > 0) " · ${PricingService.formatPrice(total)}" else "", color = Color.White)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    top.forEach { e ->
                        CardImage(e.card, Modifier.size(68.dp, 95.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, e.card.rarity.color.copy(alpha = 0.7f), RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop)
                    }
                }
                top.firstOrNull()?.let { best ->
                    Text("Best pull: ${best.card.name}" + (prices[best.id]?.takeIf { includePrices }?.let { " · ${PricingService.formatPrice(it)}" } ?: ""), style = MaterialTheme.typography.labelLarge, color = Color.White)
                }
            }
        }
    }
}
