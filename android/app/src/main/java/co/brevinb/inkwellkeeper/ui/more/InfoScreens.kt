package co.brevinb.inkwellkeeper.ui.more

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.NewReleases
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import co.brevinb.inkwellkeeper.BuildConfig
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.rules.ProPill
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.material.icons.filled.ManageAccounts
import co.brevinb.inkwellkeeper.billing.SubscriptionManager
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton

@Composable
private fun Card(content: @Composable () -> Unit) {
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) { content() }
}

@Composable
private fun LinkRow(icon: ImageVector, title: String, subtitle: String? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = LorcanaGold)
        Column(Modifier.weight(1f).padding(horizontal = 12.dp)) {
            Text(title, color = Color.White)
            subtitle?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = Color.Gray) }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
    }
}

// MARK: - Support

/** Support / Pro hub. */
@Composable
fun SupportScreen() {
    val context = LocalContext.current
    val nav = LocalNav.current
    InkwellScaffold("Support", showBack = true) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.Favorite, null, tint = LorcanaGold, modifier = Modifier.size(44.dp))
                Text("Thank You!", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = Color.White)
                Text("Ink Well Keeper is built with passion by an independent developer. Your support helps keep the app running and growing.", color = Color.Gray, textAlign = TextAlign.Center)
            }
            Card {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold)
                    Text("  Inkwell Keeper Pro", style = MaterialTheme.typography.titleMedium, color = Color.White, modifier = Modifier.weight(1f))
                    ProPill()
                }
                listOf(
                    "AI Rules Assistant — instant rulings with exact card text",
                    "AI Deck Builder, Completer & Strategy Guides",
                    "Trade calculator with live market values",
                    "Premium binder covers: Starlight & Holofoil",
                ).forEach { Text("• $it", color = Color.White, style = MaterialTheme.typography.bodySmall) }
                if (AppSettings.isProUnlocked) {
                    Text("You're subscribed — thank you!", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                    if (SubscriptionManager.isSubscribed) LinkRow(Icons.Filled.ManageAccounts, "Manage Subscription") {
                        context.startActivity(Intent(Intent.ACTION_VIEW, "https://play.google.com/store/account/subscriptions?package=${context.packageName}".toUri()))
                    }
                } else {
                    LorcanaPrimaryButton(onClick = { nav.navigate(Routes.paywall("general")) }, modifier = Modifier.fillMaxWidth()) { Text("See Pro Plans") }
                }
                if (BuildConfig.DEBUG) ToggleRow("Premium Override (debug)", AppSettings.isProUnlocked, { AppSettings.updateProUnlocked(it) })
            }
            Card {
                Text("Share with Friends", style = MaterialTheme.typography.titleSmall, color = Color.White)
                LinkRow(Icons.Filled.Share, "Share App", "Tell other Lorcana players about Inkwell Keeper!") {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "Track your Disney Lorcana collection with Inkwell Keeper: ${DeepLinkRouter.PLAY_STORE_URL}")
                    context.startActivity(Intent.createChooser(send, "Share Inkwell Keeper"))
                }
            }
            Card {
                Text("Help & Resources", style = MaterialTheme.typography.titleSmall, color = Color.White)
                LinkRow(Icons.Filled.NewReleases, "What's New") { nav.navigate(Routes.WHATS_NEW) }
                LinkRow(Icons.AutoMirrored.Filled.MenuBook, "Keyword Glossary") { nav.navigate(Routes.GLOSSARY) }
                LinkRow(Icons.Filled.Sell, "About Pricing") { nav.navigate(Routes.PRICING_INFO) }
            }
            Card {
                Text("Feedback", style = MaterialTheme.typography.titleSmall, color = Color.White)
                LinkRow(Icons.Filled.Email, "Send Feedback", "Have a suggestion or found a bug? Let me know!") {
                    val mail = Intent(Intent.ACTION_SENDTO, "mailto:".toUri())
                        .putExtra(Intent.EXTRA_SUBJECT, "Inkwell Keeper Android ${BuildConfig.VERSION_NAME} Feedback")
                    runCatching { context.startActivity(mail) }
                }
                LinkRow(Icons.Filled.Star, "Rate on Google Play") {
                    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, DeepLinkRouter.PLAY_STORE_URL.toUri())) }
                }
            }
        }
    }
}

// MARK: - What's New

@Composable
fun WhatsNewScreen() {
    LaunchedEffect(Unit) { AppSettings.markWhatsNewSeen() }
    InkwellScaffold("What's New", showBack = true) { padding ->
        LazyColumn(Modifier.padding(padding).fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            items(changelogEntries, key = { it.version }) { entry ->
                Card {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Version ${entry.version}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White, modifier = Modifier.weight(1f))
                        Text(entry.date, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                    Group("✨ New Features", entry.features, SystemColors.green)
                    Group("🔧 Improvements", entry.improvements, SystemColors.blue)
                    Group("🐛 Bug Fixes", entry.bugFixes, SystemColors.orange)
                    Group("🚧 In Progress", entry.inProgress, SystemColors.yellow)
                }
            }
        }
    }
}

@Composable
private fun Group(title: String, items: List<String>, color: Color) {
    if (items.isEmpty()) return
    Text(title, style = MaterialTheme.typography.labelLarge, color = color, modifier = Modifier.padding(top = 4.dp))
    items.forEach { Text("• $it", style = MaterialTheme.typography.bodySmall, color = Color.White) }
}

// MARK: - Glossary

@Composable
fun GlossaryScreen() {
    val nav = LocalNav.current
    InkwellScaffold("Keyword Glossary", showBack = true) { padding ->
        LazyColumn(Modifier.padding(padding).fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            item { Text("Keywords", style = MaterialTheme.typography.titleSmall, color = LorcanaGold) }
            items(LorcanaGlossary.keywords, key = { it.title }) { GlossaryRow(it) { q -> nav.navigate(Routes.RULES); co.brevinb.inkwellkeeper.ui.rules.RulesAssistantSeed.question = q } }
            item { Text("Core Concepts", style = MaterialTheme.typography.titleSmall, color = LorcanaGold, modifier = Modifier.padding(top = 12.dp)) }
            items(LorcanaGlossary.concepts, key = { it.title }) { GlossaryRow(it) { q -> nav.navigate(Routes.RULES); co.brevinb.inkwellkeeper.ui.rules.RulesAssistantSeed.question = q } }
        }
    }
}

@Composable
private fun GlossaryRow(entry: GlossaryEntry, onAsk: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).clickable { expanded = !expanded }.padding(14.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(entry.title, color = Color.White, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
            Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, null, tint = Color.Gray)
        }
        if (expanded) {
            Text(entry.definition, color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(top = 6.dp))
            Row(Modifier.padding(top = 8.dp).clickable { onAsk("How does ${entry.title.substringBefore(" N").substringBefore(" +N")} work?") }, verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(14.dp))
                Text(" Ask the Rules Assistant", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                Spacer(Modifier.width(6.dp))
                if (!AppSettings.isProUnlocked) ProPill()
            }
        }
    }
}

// MARK: - Pricing info

@Composable
fun PricingInfoScreen() {
    val sections = listOf(
        "Where prices come from" to "Inkwell Keeper pulls live market data from Cardmarket — the largest Lorcana marketplace, used primarily in Europe. Prices are served by a backend we run that pre-aggregates Cardmarket listings, with a direct API fallback when a card isn't in the cache yet.",
        "Why not TCGPlayer?" to "TCGPlayer doesn't offer public API access for indie apps, so we can't pull their North American prices directly. We've intentionally avoided unreliable scraping and don't substitute prices from elsewhere. If TCGPlayer opens up access in the future, it'll be added as a source.",
        "Why some cards show “—”" to "If a card has no listings on Cardmarket — common for very new releases, certain promos, and obscure variants — Inkwell Keeper shows a dash instead of a price. We never fabricate or estimate a value; an empty result is more honest than a guess.",
        "Work in progress" to "Pricing coverage is improving with every update. If a card you own consistently shows no price, please report it from Settings → Report an Issue and we'll work to add coverage.",
        "Refreshing prices" to "Tap the refresh icon at the top of the Stats tab to re-fetch prices for every card in your collection. Refreshes are rate-limited so they may take a moment for large collections.",
    )
    InkwellScaffold("About Pricing", showBack = true) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Sell, null, tint = LorcanaGold)
                Text("  How collection value works", style = MaterialTheme.typography.titleLarge, color = Color.White)
            }
            Text("A quick rundown of where the numbers in your Stats tab come from — and why some cards don't have one.", color = Color.Gray)
            sections.forEach { (title, body) ->
                Card {
                    Text(title, style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                    Text(body, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}
