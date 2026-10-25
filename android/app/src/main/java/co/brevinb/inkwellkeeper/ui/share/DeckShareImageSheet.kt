package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.decks.DeckStatistics
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Branded deck image: name, format, inks, four headline cards, and the mana curve. */
@Composable
fun DeckShareImageSheet(deck: Deck, stats: DeckStatistics, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val code = remember(deck.id) { app.decks.generateShareCode(deck) }
    val headline = remember(deck.id) {
        deck.cards.sortedWith(compareByDescending<co.brevinb.inkwellkeeper.data.DeckCard> { it.cardRarity.sortOrder }.thenByDescending { it.cost }).take(4)
    }
    val buckets = (1..7).map { cost ->
        cost to if (cost == 7) stats.costDistribution.filterKeys { it >= 7 }.values.sum() else stats.costDistribution[cost] ?: 0
    }
    val maxCount = maxOf(1, buckets.maxOf { it.second })
    ShareCardPresenter(
        title = "Share Deck",
        analyticsType = "deck",
        fileName = "InkwellKeeper-${deck.name}",
        onDismiss = onDismiss,
        shareText = DeepLinkRouter.deckShareLink(code),
    ) {
        ShareCardChrome(qrPayload = DeepLinkRouter.deckQrPayload(code)) {
            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(deck.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = LorcanaGold, maxLines = 2)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("${deck.deckFormat.rawValue} · ${deck.totalCards} cards", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
                        deck.deckInkColors.forEach { Box(Modifier.size(12.dp).clip(CircleShape).background(it.color).border(0.5.dp, Color.White.copy(alpha = 0.3f), CircleShape)) }
                    }
                }
                if (headline.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        headline.forEach { card ->
                            CardImage(
                                card.toLorcanaCard(),
                                Modifier.size(68.dp, 95.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, card.cardRarity.color.copy(alpha = 0.7f), RoundedCornerShape(8.dp)),
                                contentScale = ContentScale.Crop,
                            )
                        }
                    }
                }
                Text("Mana Curve", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                Row(Modifier.fillMaxWidth().height(70.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
                    buckets.forEach { (cost, count) ->
                        Column(Modifier.weight(1f).fillMaxHeight(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.Bottom)) {
                            Text(if (count > 0) "$count" else "", fontSize = 9.sp, color = Color.Gray)
                            Box(Modifier.fillMaxWidth().height(maxOf(3f, 48f * count / maxCount).dp).clip(RoundedCornerShape(50)).background(LorcanaGold.copy(alpha = if (count > 0) 0.9f else 0.15f)))
                            Text(if (cost == 7) "7+" else "$cost", fontSize = 9.sp, color = Color.Gray)
                        }
                    }
                }
            }
        }
    }
}
