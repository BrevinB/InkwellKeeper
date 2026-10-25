package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

enum class PriceStyle { INLINE, DETAILED, HERO }

@Composable
fun ConfidenceBadge(confidence: PricingService.PriceConfidence) {
    val color = when (confidence) {
        PricingService.PriceConfidence.HIGH -> SystemColors.green
        PricingService.PriceConfidence.MEDIUM -> SystemColors.orange
        PricingService.PriceConfidence.LOW -> SystemColors.red
    }
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(color).padding(horizontal = 6.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(Icons.Filled.CheckCircle, null, tint = Color.White, modifier = Modifier.size(11.dp))
        Text(confidence.label.uppercase(), style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = Color.White)
    }
}

/**
 * Fetches and shows the card's market price. Cards without real market data show an
 * "unavailable" state, never an estimate.
 */
@Composable
fun AsyncPriceView(card: LorcanaCard, style: PriceStyle, modifier: Modifier = Modifier) {
    var loading by remember(card.variantAwareId) { mutableStateOf(true) }
    var result by remember(card.variantAwareId) { mutableStateOf<Pair<Double, PricingService.PriceConfidence>?>(null) }
    var low by remember(card.variantAwareId) { mutableStateOf<Double?>(null) }
    LaunchedEffect(card.variantAwareId) {
        result = PricingService.getPriceWithConfidence(card)
        low = PricingService.getLowPrice(card)
        loading = false
    }
    val current = result
    when {
        current != null -> PriceDisplay(current.first, current.second, style, low, modifier)
        loading -> Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp, color = Color.Gray)
            Text("Loading…", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
        else -> PriceUnavailable(style, modifier)
    }
}

@Composable
fun PriceDisplay(price: Double, confidence: PricingService.PriceConfidence, style: PriceStyle, low: Double?, modifier: Modifier = Modifier) {
    when (style) {
        PriceStyle.INLINE -> Text(
            "Market ${PricingService.formatPrice(price)}",
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
            color = LorcanaGold,
            modifier = modifier,
        )
        PriceStyle.HERO -> Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(PricingService.formatPrice(price), style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold, color = LorcanaGold)
            ConfidenceBadge(confidence)
        }
        PriceStyle.DETAILED -> Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Market ${PricingService.formatPrice(price)}", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
                ConfidenceBadge(confidence)
            }
            if (low != null) {
                Text("Low ${PricingService.formatPrice(low)} on TCGplayer", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
            Text(confidence.description, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
    }
}

@Composable
fun PriceUnavailable(style: PriceStyle, modifier: Modifier = Modifier) {
    when (style) {
        PriceStyle.INLINE -> Text("—", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = modifier)
        PriceStyle.HERO -> Text("No price", style = MaterialTheme.typography.titleLarge, color = Color.Gray, modifier = modifier)
        PriceStyle.DETAILED -> Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("No price available", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            Text("Market data couldn't be retrieved for this card.", style = MaterialTheme.typography.labelSmall, color = Color.Gray.copy(alpha = 0.8f))
        }
    }
}
