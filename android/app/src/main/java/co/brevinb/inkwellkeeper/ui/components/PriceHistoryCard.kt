package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.TrendingDown
import androidx.compose.material.icons.automirrored.filled.TrendingUp
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import java.util.Locale
import kotlin.math.abs

/** Market price trend for the card's printing from the backend's daily history. */
@Composable
fun PriceHistoryCard(card: LorcanaCard, modifier: Modifier = Modifier) {
    var loading by remember(card.variantAwareId) { mutableStateOf(true) }
    var points by remember(card.variantAwareId) { mutableStateOf<List<PricingService.PricePoint>>(emptyList()) }
    LaunchedEffect(card.variantAwareId) {
        points = PricingService.fetchPriceHistory(card)
        loading = false
    }
    SectionCard(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Price History", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
            Spacer(Modifier.weight(1f))
            if (points.size >= 2) {
                val change = points.last().price - points.first().price
                PriceChangeBadge(change)
            }
        }
        when {
            loading -> Box(Modifier.fillMaxWidth().heightIn(min = 80.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = LorcanaGold, modifier = Modifier.size(24.dp))
            }
            points.size < 2 -> Text(
                "Not enough price history yet — daily tracking builds this out over time.",
                style = MaterialTheme.typography.labelMedium,
                color = Color.Gray,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp),
            )
            else -> PriceTrendChart(points.map { it.date to it.price })
        }
    }
}

@Composable
fun PriceChangeBadge(change: Double) {
    val up = change >= 0
    val color = if (up) SystemColors.green else SystemColors.red
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(2.dp)) {
        Icon(if (up) Icons.AutoMirrored.Filled.TrendingUp else Icons.AutoMirrored.Filled.TrendingDown, contentDescription = if (up) "Up" else "Down", tint = color, modifier = Modifier.size(14.dp))
        Text(String.format(Locale.US, "$%.2f", abs(change)), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = color)
    }
}
