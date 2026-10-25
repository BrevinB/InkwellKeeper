package co.brevinb.inkwellkeeper.ui.stats

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.stats.CollectionStatsSnapshot
import co.brevinb.inkwellkeeper.stats.PortfolioHistoryModel
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.PriceTrendChart
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.sets.ProgressBar
import co.brevinb.inkwellkeeper.ui.share.StatsShareSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.launch
import java.util.Locale
import kotlin.math.abs

@Composable
fun StatsScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val portfolio = remember { PortfolioHistoryModel() }
    val scope = rememberCoroutineScope()
    var sharing by remember { mutableStateOf(false) }
    val rows = app.collection.collectedRows
    val snapshot = remember(rows, app.collection.revision, portfolio.livePrices) { CollectionStatsSnapshot.build(rows, portfolio.livePrices) }
    val isPro = AppSettings.isProUnlocked

    LaunchedEffect(app.collection.collectedCards.size) { portfolio.load(app.collection.collectedRows) }

    InkwellScaffold(
        title = "Stats",
        large = true,
        actions = {
            IconButton(onClick = { sharing = true }, enabled = snapshot.totalCards > 0) { Icon(Icons.Filled.IosShare, "Share") }
            IconButton(
                onClick = {
                    scope.launch {
                        app.collection.refreshAllPrices()
                        portfolio.load(app.collection.collectedRows, force = true)
                    }
                },
                enabled = !app.collection.isRefreshingPrices && rows.isNotEmpty(),
            ) {
                if (app.collection.isRefreshingPrices) CircularProgressIndicator(Modifier.size(18.dp), color = LorcanaGold, strokeWidth = 2.dp)
                else Icon(Icons.Filled.Refresh, "Refresh prices")
            }
        },
    ) { padding ->
        LazyVerticalGrid(
            GridCells.Adaptive(340.dp),
            Modifier.padding(padding).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
            horizontalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            item { OverviewCard(snapshot) }
            if (snapshot.totalCards == 0) {
                item { StatsCard("No cards yet") { Text("Scan or import cards to see your collection analytics — rarity, ink colors, cost curve, and top-value cards will appear here.", style = MaterialTheme.typography.bodyMedium, color = Color.Gray) } }
                return@LazyVerticalGrid
            }
            item { ProGate(isPro, "Collection Value", "See what your collection is worth over time") { PortfolioValueContent(portfolio) } }
            item {
                StatsCard("Top 10 Most Valuable", "Highest stack value based on live market pricing") {
                    snapshot.topValuable.forEachIndexed { index, entry ->
                        Row(Modifier.fillMaxWidth().clickable { nav.openCard(entry.card, CardDetailMode.COLLECTION) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text("${index + 1}", style = MaterialTheme.typography.labelLarge, color = LorcanaGold, modifier = Modifier.width(20.dp))
                            CardImage(entry.card, Modifier.size(32.dp, 45.dp).clip(RoundedCornerShape(4.dp)))
                            Column(Modifier.weight(1f)) {
                                Text(entry.card.name, style = MaterialTheme.typography.bodySmall, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text("× ${entry.quantity} · ${PricingService.formatPrice(entry.unitPrice)} ea.", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                            }
                            Text(PricingService.formatPrice(entry.stackValue), style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold, color = LorcanaGold)
                        }
                    }
                }
            }
            item {
                ProGate(isPro, "Biggest Movers", "What gained and lost the most in the past week") {
                    val gainers = portfolio.movers.filter { it.isGain }.take(5)
                    val losers = portfolio.movers.filter { !it.isGain }.take(5)
                    if (portfolio.movers.isEmpty()) Text(if (portfolio.isLoading) "Loading…" else "No price moves this week.", color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                    if (gainers.isNotEmpty()) Text("Gainers", style = MaterialTheme.typography.labelLarge, color = SystemColors.green)
                    gainers.forEach { MoverRow(it.name, it.isFoil, it.change, it.percentChange) }
                    if (losers.isNotEmpty()) Text("Losers", style = MaterialTheme.typography.labelLarge, color = SystemColors.red)
                    losers.forEach { MoverRow(it.name, it.isFoil, it.change, it.percentChange) }
                }
            }
            item {
                StatsCard("Value by Set", "Which sets you've invested the most in") {
                    val max = snapshot.valueBySet.values.maxOrNull() ?: 1.0
                    snapshot.valueBySet.entries.sortedByDescending { it.value }.take(8).forEach { (set, value) ->
                        BarRow(set, PricingService.formatPrice(value), value / max, LorcanaGold)
                    }
                }
            }
            item {
                ProGate(isPro, "Highs & Lows", "Cards at the edge of their 6-month range") {
                    val highs = portfolio.extremes.filter { it.isHigh }.take(5)
                    val lows = portfolio.extremes.filter { !it.isHigh }.take(5)
                    if (portfolio.extremes.isEmpty()) Text("Nothing at a high or low right now.", color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                    if (highs.isNotEmpty()) Text("At a high", style = MaterialTheme.typography.labelLarge, color = SystemColors.green)
                    highs.forEach { ExtremeRow(it.name, it.isFoil, it.price) }
                    if (lows.isNotEmpty()) Text("At a low", style = MaterialTheme.typography.labelLarge, color = SystemColors.red)
                    lows.forEach { ExtremeRow(it.name, it.isFoil, it.price) }
                }
            }
            item { RarityDonutCard(snapshot.rarityCounts) }
            item {
                ProGate(isPro, "Foil Premium", "Average value of a copy, foil against normal") {
                    val split = portfolio.variantSplit
                    val foilAvg = if (split.foilCopies > 0) split.foilValue / split.foilCopies else 0.0
                    val normalAvg = if (split.normalCopies > 0) split.normalValue / split.normalCopies else 0.0
                    Row(Modifier.fillMaxWidth()) {
                        BigStat("Foil", PricingService.formatPrice(foilAvg), "${split.foilCopies} copies", LorcanaGold, Modifier.weight(1f))
                        BigStat("Normal", PricingService.formatPrice(normalAvg), "${split.normalCopies} copies", Color.White, Modifier.weight(1f))
                    }
                    if (normalAvg > 0 && foilAvg > 0) Text(String.format(Locale.US, "Foils are worth %.1f× a normal copy on average.", foilAvg / normalAvg), style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
            }
            item { SetCompletionCard() }
            item {
                ProGate(isPro, "Cost vs Value", "What you paid against what it's worth") {
                    val basis = portfolio.costBasis
                    if (!basis.hasRecordedCost) {
                        Text("Record what you paid on a card's detail screen to see your gain or loss.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                    } else {
                        Row(Modifier.fillMaxWidth()) {
                            BigStat("Paid", PricingService.formatPrice(basis.costBasis), null, Color.White, Modifier.weight(1f))
                            BigStat("Those worth now", PricingService.formatPrice(basis.marketValue), null, LorcanaGold, Modifier.weight(1f))
                        }
                        val tint = if (basis.gain >= 0) SystemColors.green else SystemColors.red
                        Text((if (basis.gain >= 0) "+" else "−") + PricingService.formatPrice(abs(basis.gain)) + (basis.percentGain?.let { String.format(Locale.US, " (%.1f%%)", it) } ?: ""), style = MaterialTheme.typography.titleMedium, color = tint)
                        if (basis.isPartial) Text("Covers the ${basis.recordedCopies} copies with a recorded price; ${basis.unrecordedCopies} have none yet.", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                        Text("Biggest positions", style = MaterialTheme.typography.labelLarge, color = LorcanaGold)
                        portfolio.costBasisEntries.take(5).forEach { e -> MoverRow(e.name, e.isFoil, e.gain, null) }
                    }
                }
            }
            item {
                StatsCard("Ink Distribution", "Cards owned per ink color") {
                    val max = snapshot.inkColorCounts.values.maxOrNull() ?: 1
                    snapshot.inkColorCounts.entries.sortedByDescending { it.value }.forEach { (ink, count) ->
                        BarRow(ink, "$count", count.toDouble() / max, InkColor.fromString(ink)?.color ?: Color.Gray)
                    }
                }
            }
            item { CostCurve(snapshot.costCounts) }
            item {
                StatsCard("Card Types", "What kinds of cards you're collecting") {
                    val max = snapshot.typeCounts.values.maxOrNull() ?: 1
                    snapshot.typeCounts.entries.sortedByDescending { it.value }.forEach { (type, count) -> BarRow(type, "$count", count.toDouble() / max, SystemColors.teal) }
                }
            }
            if (snapshot.hasInkableData) {
                item {
                    StatsCard("Inkable Ratio", "How much of your collection is inkable") {
                        val total = snapshot.inkableCount + snapshot.nonInkableCount
                        val pct = snapshot.inkableCount.toDouble() / total
                        Text("${(pct * 100).toInt()}% inkable", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = SystemColors.blue)
                        ProgressBar(pct, 10)
                        Text("${snapshot.inkableCount} inkable · ${snapshot.nonInkableCount} not", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
            }
            item {
                StatsCard("Recent Additions") {
                    if (snapshot.recentCards.isEmpty()) Text("No recent additions", color = Color.Gray)
                    snapshot.recentCards.forEach { card ->
                        Row(Modifier.fillMaxWidth().clickable { nav.openCard(card, CardDetailMode.COLLECTION) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            CardImage(card, Modifier.size(32.dp, 45.dp).clip(RoundedCornerShape(4.dp)))
                            Column(Modifier.weight(1f)) {
                                Text(card.name, style = MaterialTheme.typography.bodySmall, color = Color.White, maxLines = 1)
                                Text(card.setName, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                            }
                        }
                    }
                }
            }
        }
    }
    if (sharing) StatsShareSheet(snapshot) { sharing = false }
}

@Composable
fun StatsCard(title: String, subtitle: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(LorcanaDark.copy(alpha = 0.8f))
            .border(1.dp, LorcanaGold.copy(alpha = 0.2f), RoundedCornerShape(16.dp)).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Column {
            Text(title, style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
            if (subtitle != null) Text(subtitle, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        }
        content()
    }
}

/** Pro cards show a locked teaser for free users (Play Billing isn't wired yet). */
@Composable
private fun ProGate(isPro: Boolean, title: String, subtitle: String, content: @Composable ColumnScope.() -> Unit) {
    val nav = LocalNav.current
    if (isPro) {
        StatsCard(title, subtitle, content)
    } else {
        StatsCard(title, subtitle) {
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaGold.copy(alpha = 0.1f)).clickable { nav.navigate(Routes.paywall("portfolioHistory")) }.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Icon(Icons.Filled.Lock, null, tint = LorcanaGold)
                Text("Unlock with Inkwell Keeper Pro", style = MaterialTheme.typography.bodyMedium, color = Color.White, modifier = Modifier.weight(1f))
                Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold)
            }
        }
    }
}

@Composable
private fun OverviewCard(snapshot: CollectionStatsSnapshot) {
    StatsCard("Collection Overview") {
        Row(Modifier.fillMaxWidth()) {
            BigStat("Cards", "${snapshot.totalCards}", "${snapshot.uniqueCards} unique", Color.White, Modifier.weight(1f))
            BigStat(
                "Value",
                if (snapshot.totalValue > 0) PricingService.formatPrice(snapshot.totalValue) else "—",
                if (snapshot.pricedCardCount > 0) "avg ${PricingService.formatPrice(snapshot.averageValuePerPricedCard)}" else "No price data",
                LorcanaGold,
                Modifier.weight(1f),
            )
        }
        if (snapshot.unpricedCardCount > 0 && snapshot.totalCards > 0) {
            Text("${snapshot.unpricedCardCount} cards have no market price yet.", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
    }
}

@Composable
private fun BigStat(label: String, value: String, caption: String?, color: Color, modifier: Modifier) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        Text(value, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = color, maxLines = 1)
        if (caption != null) Text(caption, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}

@Composable
private fun PortfolioValueContent(portfolio: PortfolioHistoryModel) {
    val summary = portfolio.summary
    when {
        portfolio.isLoading && !portfolio.hasLoadedOnce -> Box(Modifier.fillMaxWidth().height(120.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = LorcanaGold) }
        summary == null || portfolio.points.size < 2 -> Text("Not enough price history yet.", color = Color.Gray, style = MaterialTheme.typography.bodySmall)
        else -> {
            Text(PricingService.formatPrice(summary.currentValue), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = LorcanaGold)
            val tint = if (summary.change >= 0) SystemColors.green else SystemColors.red
            Text(
                (if (summary.change >= 0) "+" else "−") + PricingService.formatPrice(abs(summary.change)) +
                    (summary.percentChange?.let { String.format(Locale.US, " (%.1f%%)", it) } ?: "") + " over 6 months",
                style = MaterialTheme.typography.labelLarge, color = tint,
            )
            portfolio.weeklyChange?.let { Text("This week: " + (if (it >= 0) "+" else "−") + PricingService.formatPrice(abs(it)), style = MaterialTheme.typography.labelMedium, color = Color.Gray) }
            PriceTrendChart(portfolio.points.map { it.date to it.value })
        }
    }
}

@Composable
private fun MoverRow(name: String, isFoil: Boolean, change: Double, percent: Double?) {
    val tint = if (change >= 0) SystemColors.green else SystemColors.red
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(name, style = MaterialTheme.typography.bodySmall, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        if (isFoil) Text("Foil ", style = MaterialTheme.typography.labelSmall, color = LorcanaGold)
        Text((if (change >= 0) "+" else "−") + PricingService.formatPrice(abs(change)) + (percent?.let { String.format(Locale.US, " %.0f%%", it) } ?: ""), style = MaterialTheme.typography.labelMedium, color = tint)
    }
}

@Composable
private fun ExtremeRow(name: String, isFoil: Boolean, price: Double) {
    Row(Modifier.fillMaxWidth()) {
        Text(name, style = MaterialTheme.typography.bodySmall, color = Color.White, maxLines = 1, modifier = Modifier.weight(1f))
        if (isFoil) Text("Foil ", style = MaterialTheme.typography.labelSmall, color = LorcanaGold)
        Text(PricingService.formatPrice(price), style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
    }
}

@Composable
private fun BarRow(label: String, value: String, fraction: Double, color: Color) {
    Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Row {
            Text(label, style = MaterialTheme.typography.labelMedium, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            Text(value, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        }
        Box(Modifier.fillMaxWidth().height(8.dp).clip(RoundedCornerShape(4.dp)).background(Color.White.copy(alpha = 0.08f))) {
            Box(Modifier.fillMaxWidth(fraction.toFloat().coerceIn(0.02f, 1f)).fillMaxHeight().clip(RoundedCornerShape(4.dp)).background(color))
        }
    }
}

@Composable
private fun RarityDonutCard(counts: Map<CardRarity, Int>) {
    val total = counts.values.sum()
    val entries = CardRarity.entries.mapNotNull { r -> counts[r]?.takeIf { it > 0 }?.let { r to it } }
    StatsCard("Rarity Breakdown", "How your collection splits by rarity") {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(20.dp)) {
            Box(Modifier.size(130.dp), contentAlignment = Alignment.Center) {
                Canvas(Modifier.fillMaxSize()) {
                    var start = -90f
                    val stroke = 22.dp.toPx()
                    for ((rarity, count) in entries) {
                        val sweep = 360f * count / total
                        drawArc(rarity.color, start, sweep - 1.5f, useCenter = false, topLeft = Offset(stroke / 2, stroke / 2), size = Size(size.width - stroke, size.height - stroke), style = Stroke(stroke))
                        start += sweep
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("$total", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
                    Text("cards", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                entries.forEach { (rarity, count) ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(Modifier.size(10.dp).clip(CircleShape).background(rarity.color))
                        Text(" ${rarity.displayName}", style = MaterialTheme.typography.labelMedium, color = Color.White, modifier = Modifier.width(96.dp))
                        Text("$count", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
            }
        }
    }
}

@Composable
private fun CostCurve(counts: Map<Int, Int>) {
    val max = counts.values.maxOrNull() ?: 1
    StatsCard("Cost Curve", "Distribution of ink costs across your collection") {
        Row(Modifier.fillMaxWidth().height(120.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
            for (cost in 0..10) {
                val count = counts[cost] ?: 0
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                    Text(if (count > 0) "$count" else "", style = MaterialTheme.typography.labelSmall, color = Color.Gray, maxLines = 1)
                    Box(Modifier.fillMaxWidth().height(maxOf(3f, 80f * count / max).dp).clip(RoundedCornerShape(3.dp)).background(if (count > 0) LorcanaGold else Color.Gray.copy(alpha = 0.3f)))
                    Text(if (cost == 10) "10+" else "$cost", style = MaterialTheme.typography.labelSmall, color = Color.Gray, maxLines = 1)
                }
            }
        }
    }
}

@Composable
private fun SetCompletionCard() {
    val app = LocalApp.current
    val nav = LocalNav.current
    StatsCard("Set Completion") {
        SetsDataManager.sets.filter { it.isMainSet && !it.isUpcoming() }.forEach { set ->
            val total = SetsDataManager.getCardsForSet(set.name).size.takeIf { it > 0 } ?: set.cardCount
            val progress = app.collection.getSetProgress(set.name, total)
            Column(Modifier.clickable { nav.navigate(Routes.set(set.name)) }, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row {
                    Text(set.name, style = MaterialTheme.typography.labelMedium, color = Color.White, modifier = Modifier.weight(1f))
                    Text("${progress.collected}/${progress.total}", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
                ProgressBar(progress.percentage / 100, 6)
            }
        }
        Spacer(Modifier.height(2.dp))
    }
}
