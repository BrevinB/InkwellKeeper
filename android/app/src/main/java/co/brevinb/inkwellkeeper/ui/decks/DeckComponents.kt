package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.data.DeckCard
import co.brevinb.inkwellkeeper.decks.DeckStatistics
import co.brevinb.inkwellkeeper.decks.DeckValidation
import co.brevinb.inkwellkeeper.decks.DeckManager
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.components.SectionCard
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import java.util.Locale

@Composable
fun InkDots(inks: List<InkColor>, size: Int = 10) {
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        inks.forEach { Box(Modifier.size(size.dp).clip(CircleShape).background(it.color)) }
    }
}

@Composable
fun InkChip(ink: InkColor) {
    Row(
        Modifier.clip(RoundedCornerShape(6.dp)).background(ink.color.copy(alpha = 0.2f)).padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(12.dp).clip(CircleShape).background(ink.color))
        Text(" ${ink.rawValue}", style = MaterialTheme.typography.labelSmall, color = Color.White)
    }
}

/** Tiny 0–7 cost histogram for the summary bar. */
@Composable
fun CurveSparkline(costDistribution: Map<Int, Int>) {
    val max = maxOf(costDistribution.values.maxOrNull() ?: 1, 1)
    Canvas(Modifier.width(38.dp).height(18.dp)) {
        val barWidth = 3.dp.toPx()
        val gap = (size.width - barWidth * 8) / 7
        for (cost in 0 until 8) {
            val value = costDistribution[cost] ?: 0
            val h = maxOf(value.toFloat() / max * size.height, 2.dp.toPx())
            drawRoundRect(
                if (value > 0) LorcanaGold else Color.Gray.copy(alpha = 0.3f),
                topLeft = Offset(cost * (barWidth + gap), size.height - h),
                size = Size(barWidth, h),
                cornerRadius = CornerRadius(barWidth / 2),
            )
        }
    }
}

@Composable
fun DeckStatisticsCard(statistics: DeckStatistics, validation: DeckValidation, deck: Deck) {
    SectionCard(cornerRadius = 12.dp, border = LorcanaGold.copy(alpha = 0.3f)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(deck.deckFormat.rawValue, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    deck.deckInkColors.forEach { ink ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(10.dp).clip(CircleShape).background(ink.color))
                            Text(" ${ink.rawValue}", style = MaterialTheme.typography.labelSmall, color = Color.White)
                        }
                    }
                }
            }
            val (icon, label, color) = if (validation.isValid) Triple(Icons.Filled.CheckCircle, "Valid", SystemColors.green)
            else Triple(Icons.Filled.Warning, "Invalid", SystemColors.orange)
            Icon(icon, null, tint = color, modifier = Modifier.size(14.dp))
            Text(" $label", style = MaterialTheme.typography.labelMedium, color = color)
        }
        HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
        Row(Modifier.fillMaxWidth()) {
            StatItem("Cards", "${statistics.totalCards}", if (statistics.totalCards >= 60) Color.White else SystemColors.orange, Modifier.weight(1f))
            StatItem("Unique", "${statistics.uniqueCards}", Color.White, Modifier.weight(1f))
            StatItem("Avg Cost", String.format(Locale.US, "%.1f", statistics.averageCost), Color.White, Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth()) {
            StatItem("Inkable", "${(statistics.inkableRatio * 100).toInt()}%", if (statistics.inkableRatio >= DeckValidation.MINIMUM_INKABLE_RATIO) Color.White else SystemColors.orange, Modifier.weight(1f))
            StatItem("Complete", "${statistics.completionPercentage.toInt()}%", if (statistics.completionPercentage >= 100) SystemColors.green else LorcanaGold, Modifier.weight(1f))
            StatItem("Value", PricingService.formatPrice(statistics.totalValue), LorcanaGold, Modifier.weight(1f))
        }
    }
}

@Composable
fun StatItem(label: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = color, maxLines = 1)
        Text(label, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}

@Composable
fun ValidationCard(validation: DeckValidation) {
    SectionCard(background = SystemColors.red.copy(alpha = 0.1f), border = SystemColors.orange, cornerRadius = 12.dp, spacing = 8.dp) {
        if (validation.errors.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Warning, null, tint = SystemColors.red)
                Text(" Errors", style = MaterialTheme.typography.titleMedium, color = SystemColors.red)
            }
            validation.errors.forEach { Text("• $it", style = MaterialTheme.typography.labelMedium, color = SystemColors.red.copy(alpha = 0.9f)) }
        }
        if (validation.warnings.isNotEmpty()) {
            if (validation.errors.isNotEmpty()) HorizontalDivider(color = Color.White.copy(alpha = 0.1f))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Error, null, tint = SystemColors.orange)
                Text(" Warnings", style = MaterialTheme.typography.titleMedium, color = SystemColors.orange)
            }
            validation.warnings.forEach { Text("• $it", style = MaterialTheme.typography.labelMedium, color = SystemColors.orange.copy(alpha = 0.9f)) }
        }
    }
}

@Composable
fun MissingCardsCard(missing: List<DeckManager.MissingCard>, costToComplete: Double) {
    SectionCard(cornerRadius = 12.dp, border = LorcanaGold.copy(alpha = 0.3f)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.ShoppingCart, null, tint = LorcanaGold)
            Text(" Missing Cards", style = MaterialTheme.typography.titleMedium, color = LorcanaGold, modifier = Modifier.weight(1f))
            Text(PricingService.formatPrice(costToComplete), style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
        }
        missing.take(5).forEach { item ->
            Row {
                Text("${item.needed}x ${item.card.name}", style = MaterialTheme.typography.labelMedium, color = Color.White, modifier = Modifier.weight(1f))
                item.card.price?.let { Text(PricingService.formatPrice(it * item.needed), style = MaterialTheme.typography.labelMedium, color = Color.Gray) }
            }
        }
        if (missing.size > 5) Text("+ ${missing.size - 5} more cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
    }
}

/** 0–9 cost bars with counts above. */
@Composable
fun CostCurveCard(costDistribution: Map<Int, Int>, title: String = "Cost Curve") {
    val max = costDistribution.values.maxOrNull() ?: 1
    SectionCard(cornerRadius = 12.dp, border = LorcanaGold.copy(alpha = 0.3f), title = title) {
        Row(Modifier.fillMaxWidth().height(120.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Bottom) {
            for (cost in 0 until 10) {
                val count = costDistribution[cost] ?: 0
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(if (count > 0) "$count" else "", style = MaterialTheme.typography.labelSmall, color = Color.White)
                    Box(
                        Modifier.fillMaxWidth().height(maxOf(if (max > 0) 80f * count / max else 0f, 4f).dp)
                            .clip(RoundedCornerShape(4.dp)).background(if (count > 0) LorcanaGold else Color.Gray.copy(alpha = 0.3f)),
                    )
                    Text("$cost", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
            }
        }
    }
}

/** A card in the deck list with ownership and an inline stepper. */
@Composable
fun DeckCardRow(card: DeckCard, deck: Deck, owned: Int, onOpen: () -> Unit, onAdd: () -> Unit, onRemove: () -> Unit) {
    val complete = owned >= card.quantity
    val atMax = deck.totalQuantity(card.name) >= deck.maxCopies(card.name)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(8.dp)).background(LorcanaDark.copy(alpha = 0.6f)).padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(Modifier.weight(1f).clickable(onClick = onOpen), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            CardImage(card.toLorcanaCard(), Modifier.size(40.dp, 56.dp).clip(RoundedCornerShape(6.dp)))
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(card.name, style = MaterialTheme.typography.bodyMedium, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    RarityBadge(card.cardRarity)
                    if (card.cardVariant == CardVariant.FOIL) FoilPill()
                    card.cardInkColor?.let { ink ->
                        Box(Modifier.size(8.dp).clip(CircleShape).background(ink.color))
                        Text(ink.rawValue, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                    if (card.inkwell) Icon(Icons.Filled.WaterDrop, contentDescription = "Inkable", tint = SystemColors.blue, modifier = Modifier.size(12.dp))
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    val tint = if (complete) SystemColors.green else SystemColors.orange
                    Icon(if (complete) Icons.Filled.CheckCircle else Icons.Filled.Error, null, tint = tint, modifier = Modifier.size(11.dp))
                    Text(" $owned/${card.quantity} owned", style = MaterialTheme.typography.labelSmall, color = tint)
                    card.price?.let { Text(" · ${PricingService.formatPrice(it)}", style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
                }
            }
        }
        IconButton(onClick = onRemove, modifier = Modifier.size(32.dp)) { Icon(Icons.Filled.RemoveCircle, "Remove one ${card.name}", tint = SystemColors.red) }
        Text("${card.quantity}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = Color.White)
        IconButton(onClick = onAdd, enabled = !atMax, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Filled.AddCircle, "Add one ${card.name}", tint = if (atMax) Color.Gray else SystemColors.green)
        }
    }
}

@Composable
fun FoilPill() {
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaDark, modifier = Modifier.size(10.dp))
        Text(" Foil", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = LorcanaDark)
    }
}

