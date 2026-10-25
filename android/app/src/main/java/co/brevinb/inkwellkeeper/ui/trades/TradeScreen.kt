package co.brevinb.inkwellkeeper.ui.trades

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.scan.CardPickerSheet
import co.brevinb.inkwellkeeper.ui.share.ShareCardChrome
import co.brevinb.inkwellkeeper.ui.share.ShareCardPresenter
import co.brevinb.inkwellkeeper.ui.stats.StatsCard
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlin.math.abs

/** One printing on one side of a trade; price is null until looked up (or if there's none). */
data class TradeLine(val card: LorcanaCard, val quantity: Int, val unitPrice: Double? = null) {
    val total: Double? get() = unitPrice?.let { it * quantity }
}

private fun SnapshotStateList<TradeLine>.add(card: LorcanaCard) {
    val i = indexOfFirst { it.card.variantAwareId == card.variantAwareId }
    if (i >= 0) this[i] = this[i].copy(quantity = this[i].quantity + 1) else add(TradeLine(card, 1))
}

private fun SnapshotStateList<TradeLine>.removeOne(line: TradeLine) {
    val i = indexOf(line)
    if (i < 0) return
    if (line.quantity > 1) this[i] = line.copy(quantity = line.quantity - 1) else removeAt(i)
}

private fun List<TradeLine>.total() = mapNotNull { it.total }.sum()
private fun List<TradeLine>.count() = sumOf { it.quantity }
private fun List<TradeLine>.unpriced() = filter { it.unitPrice == null }.sumOf { it.quantity }

/** Value both halves of a proposed trade against current market prices (Pro, as on iOS). */
@Composable
fun TradeScreen() {
    val nav = LocalNav.current
    val yours = remember { mutableStateListOf<TradeLine>() }
    val theirs = remember { mutableStateListOf<TradeLine>() }
    var adding by remember { mutableStateOf<Boolean?>(null) }
    var confirming by remember { mutableStateOf(false) }
    var sharing by remember { mutableStateOf(false) }
    var pricing by remember { mutableStateOf(false) }
    val difference = theirs.total() - yours.total()

    LaunchedEffect(yours.map { it.card.variantAwareId } + theirs.map { it.card.variantAwareId }) {
        pricing = true
        val prices = try { PricingService.fetchBulkMarketPrices((yours + theirs).map { it.card }) } finally { pricing = false }
        yours.indices.forEach { i -> prices[yours[i].card.variantAwareId]?.let { yours[i] = yours[i].copy(unitPrice = it) } }
        theirs.indices.forEach { i -> prices[theirs[i].card.variantAwareId]?.let { theirs[i] = theirs[i].copy(unitPrice = it) } }
    }

    InkwellScaffold(
        "Trades",
        showBack = true,
        actions = {
            if (yours.isNotEmpty() || theirs.isNotEmpty()) IconButton(onClick = { yours.clear(); theirs.clear() }) { Icon(Icons.Filled.Delete, contentDescription = "Clear") }
        },
    ) { padding ->
        if (!AppSettings.isProUnlocked) {
            EmptyState(Icons.Filled.SwapHoriz, "Know who's ahead before you trade", "Build both sides of a trade and see the market value of each, side by side.", Modifier.padding(padding)) {
                LorcanaPrimaryButton(onClick = { nav.navigate(Routes.paywall("tradeCalculator")) }) {
                    Icon(Icons.Filled.AutoAwesome, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Unlock with Pro")
                }
            }
            return@InkwellScaffold
        }
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            StatsCard("Trade Value") {
                if (yours.isEmpty() && theirs.isEmpty()) {
                    Text("Add cards to each side to compare their value.", color = Color.Gray)
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        TradeTotal("You give", yours, Modifier.weight(1f))
                        Icon(Icons.Filled.SwapHoriz, null, tint = LorcanaGold)
                        TradeTotal("You get", theirs, Modifier.weight(1f), end = true)
                    }
                    val color = if (abs(difference) < 0.01) Color.White else if (difference > 0) SystemColors.green else SystemColors.red
                    Text(
                        if (abs(difference) < 0.01) "Even trade" else if (difference > 0) "You gain ${PricingService.formatPrice(difference)}" else "You lose ${PricingService.formatPrice(-difference)}",
                        style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = color, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center,
                    )
                    val unpriced = yours.unpriced() + theirs.unpriced()
                    if (pricing) CircularProgressIndicator(Modifier.size(20.dp).align(Alignment.CenterHorizontally), color = LorcanaGold, strokeWidth = 2.dp)
                    else if (unpriced > 0) Text("$unpriced card${if (unpriced == 1) " has" else "s have"} no market price and ${if (unpriced == 1) "is" else "are"} not counted.", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
            }
            TradeSideSection("You give", yours, pricing, onAdd = { adding = true })
            TradeSideSection("You get", theirs, pricing, onAdd = { adding = false })
            if (yours.isNotEmpty() && theirs.isNotEmpty()) {
                LorcanaPrimaryButton(onClick = { confirming = true }, modifier = Modifier.fillMaxWidth()) {
                    Icon(Icons.Filled.Verified, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Confirm trade")
                }
            }
        }
    }

    adding?.let { mine ->
        CardPickerSheet(if (mine) "You give" else "You get", onDismiss = { adding = null }) { card ->
            (if (mine) yours else theirs).add(card)
            adding = null
        }
    }
    if (confirming) {
        AlertDialog(
            onDismissRequest = { confirming = false },
            title = { Text("Trade confirmed") },
            text = {
                Text(
                    (if (abs(difference) < 0.01) "An even trade." else if (difference > 0) "You came out ${PricingService.formatPrice(difference)} ahead." else "You gave up ${PricingService.formatPrice(-difference)} in value.") +
                        "\n\nNothing was added to or removed from your collection.",
                )
            },
            confirmButton = { TextButton(onClick = { confirming = false; sharing = true }) { Text("Share this trade") } },
            dismissButton = { TextButton(onClick = { confirming = false }) { Text("Done") } },
        )
        LaunchedEffect(Unit) { Analytics.send("trade.confirmed", mapOf("yours" to "${yours.count()}", "theirs" to "${theirs.count()}")) }
    }
    if (sharing) {
        ShareCardPresenter("Share Trade", "trade", "InkwellKeeper-Trade", onDismiss = { sharing = false }) {
            ShareCardChrome(qrPayload = DeepLinkRouter.PLAY_STORE_URL, height = null) {
                Text("Trade", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = LorcanaGold)
                listOf("Gave" to yours.toList(), "Got" to theirs.toList()).forEach { (label, lines) ->
                    Text("$label · ${PricingService.formatPrice(lines.total())}", style = MaterialTheme.typography.titleSmall, color = Color.White, modifier = Modifier.padding(top = 8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        lines.take(5).forEach { CardImage(it.card, Modifier.size(56.dp, 78.dp).clip(RoundedCornerShape(6.dp))) }
                    }
                }
            }
        }
    }
}

@Composable
private fun TradeTotal(title: String, lines: List<TradeLine>, modifier: Modifier, end: Boolean = false) {
    Column(modifier, horizontalAlignment = if (end) Alignment.End else Alignment.Start) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        Text(PricingService.formatPrice(lines.total()), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = LorcanaGold)
        Text("${lines.count()} card${if (lines.count() == 1) "" else "s"}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}

@Composable
private fun TradeSideSection(title: String, lines: SnapshotStateList<TradeLine>, pricing: Boolean, onAdd: () -> Unit) {
    StatsCard(title) {
        lines.forEach { line ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                CardImage(line.card, Modifier.size(36.dp, 50.dp).clip(RoundedCornerShape(4.dp)))
                Column(Modifier.weight(1f)) {
                    Text(line.card.name, style = MaterialTheme.typography.bodySmall, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("${line.quantity}× · ${line.card.variant.displayName}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
                val total = line.total
                when {
                    total != null -> Text(PricingService.formatPrice(total), style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                    pricing -> CircularProgressIndicator(Modifier.size(16.dp), color = LorcanaGold, strokeWidth = 2.dp)
                    else -> Text("No price", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
                IconButton(onClick = { lines.removeOne(line) }) { Icon(Icons.Filled.RemoveCircle, "Remove ${line.card.name}", tint = SystemColors.red) }
            }
        }
        Row(Modifier.clip(RoundedCornerShape(8.dp)).background(LorcanaGold.copy(alpha = 0.15f)).clickable(onClick = onAdd).padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Add, null, tint = LorcanaGold)
            Text(" Add card", color = LorcanaGold)
        }
    }
}
