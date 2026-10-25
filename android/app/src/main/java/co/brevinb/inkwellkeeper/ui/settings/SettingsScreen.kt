package co.brevinb.inkwellkeeper.ui.settings

import android.content.Intent
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.AttachMoney
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Backup
import androidx.compose.material.icons.filled.BugReport
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FrontHand
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil3.SingletonImageLoader
import co.brevinb.inkwellkeeper.BuildConfig
import co.brevinb.inkwellkeeper.R
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LabeledRow
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.launch
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape

@Composable
fun SettingsScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val context = LocalContext.current
    val uri = LocalUriHandler.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    var dialog by remember { mutableStateOf<String?>(null) }
    var refreshProgress by remember { mutableStateOf<String?>(null) }

    InkwellScaffold("Settings", large = true, showBack = true, snackbarHostState = snackbar) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            FormSection {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Image(painterResource(R.drawable.app_icon_art), null, Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)))
                    Column {
                        Text("Ink Well Keeper", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White)
                        Text("Unofficial Lorcana Collection Tracker", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
                LabeledRow("Version", "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})")
                SettingsLink("What's New", Icons.Filled.AutoAwesome, badge = AppSettings.shouldShowWhatsNew) { nav.navigate(Routes.WHATS_NEW) }
            }

            FormSection("Preferences", footer = "When off, cards from sets that haven't released yet stay hidden until release day, or until you choose to see a set.") {
                MenuPickerRow("Currency", listOf("USD", "EUR"), AppSettings.preferredCurrency, {
                    AppSettings.updatePreferredCurrency(it)
                    PricingService.clearCache()
                }, { if (it == "USD") "USD ($)" else "EUR (€)" })
                ToggleRow("Show Spoilers for Upcoming Sets", AppSettings.showAllSpoilers, { AppSettings.updateShowAllSpoilers(it) })
            }

            FormSection("Collection") {
                LabeledRow("Total Cards", "${app.collection.collectedCards.size}")
                LabeledRow("Wishlist", "${app.collection.wishlistCards.size}")
                LabeledRow("Total Value", PricingService.formatPrice(app.collection.collectedRows.sumOf { it.price ?: 0.0 }), valueColor = LorcanaGold)
            }

            FormSection("Backup & Transfer", footer = "JSON backups use the same format as the iPhone app, so you can move your collection, binders and boxes between devices.") {
                SettingsLink("Import Cards or Backup", Icons.Filled.Backup) { nav.navigate(Routes.IMPORT) }
                SettingsLink("Export Collection", Icons.Filled.Share) { nav.navigate(Routes.EXPORT) }
            }

            FormSection("Legal") {
                SettingsLink("About Pricing", Icons.Filled.LocalOffer) { nav.navigate(Routes.PRICING_INFO) }
                SettingsLink("Disclaimer", Icons.Filled.Warning) { dialog = "disclaimer" }
                SettingsLink("Privacy Policy", Icons.Filled.FrontHand) { dialog = "privacy" }
            }

            FormSection("Help & Feedback") {
                SettingsLink("Contact Support", Icons.Filled.Email) { uri.openUri("mailto:brevbot2@gmail.com?subject=Ink%20Well%20Keeper%20Android%20Support") }
                SettingsLink("Report an Issue", Icons.Filled.BugReport) { uri.openUri("mailto:brevbot2@gmail.com?subject=Ink%20Well%20Keeper%20Android%20-%20Issue%20Report") }
                SettingsLink("Share App", Icons.Filled.Share) {
                    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, "Track your Disney Lorcana collection with Ink Well Keeper: ${DeepLinkRouter.PLAY_STORE_URL}")
                    }, null))
                }
            }

            FormSection(footer = "Ink Well Keeper is free with no ads. Consider leaving a tip to support development!") {
                SettingsLink("Support Development", Icons.Filled.Favorite, tint = SystemColors.pink) { nav.navigate(Routes.SUPPORT) }
            }

            FormSection("Data Management") {
                Row(Modifier.fillMaxWidth().clickable(enabled = refreshProgress == null) {
                    scope.launch {
                        refreshProgress = "Starting…"
                        app.collection.refreshAllPrices { done, total -> refreshProgress = "$done / $total" }
                        refreshProgress = null
                        snackbar.showSnackbar("Prices refreshed")
                    }
                }.padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Refresh, null, tint = LorcanaGold)
                    Text("  Refresh All Prices", color = Color.White, modifier = Modifier.weight(1f))
                    refreshProgress?.let {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp, color = LorcanaGold)
                        Text("  $it", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                }
                SettingsLink("Clear Image Cache", Icons.Filled.Layers) {
                    SingletonImageLoader.get(context).let { loader ->
                        loader.memoryCache?.clear()
                        loader.diskCache?.clear()
                    }
                    scope.launch { snackbar.showSnackbar("Image cache cleared") }
                }
                SettingsLink("Reset Onboarding", Icons.Filled.RestartAlt) {
                    AppSettings.resetOnboarding()
                    scope.launch { snackbar.showSnackbar("Onboarding will show next launch") }
                }
                SettingsLink("Delete All Data", Icons.Filled.Delete, tint = SystemColors.red) { dialog = "delete" }
            }

            if (BuildConfig.DEBUG) {
                FormSection("Debug Options") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.WorkspacePremium, null, tint = SystemColors.orange)
                        Column(Modifier.weight(1f).padding(start = 12.dp)) {
                            ToggleRow("Premium Override", AppSettings.isProUnlocked, { AppSettings.updateProUnlocked(it) })
                        }
                    }
                }
            }

            FormSection("Legal Attribution") {
                Text("Community Code Policy", style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                Text("This app uses trademarks and/or copyrights associated with Disney Lorcana TCG, under Ravensburger's Community Code Policy.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                Text("Official Disclaimer", style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                Text("This app is not published, endorsed, or specifically approved by Disney or Ravensburger.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                Text("The developer is expressly prohibited from charging you to use or access this content.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                SettingsLink("Disney Lorcana Official Website", Icons.AutoMirrored.Filled.OpenInNew) { uri.openUri("https://www.disneylorcana.com/") }
                SettingsLink("Community Code Policy Document", Icons.Filled.Description) { uri.openUri("https://cdn.ravensburger.com/lorcana/community-code-en") }
            }

            FormSection("About") {
                Text("Ink Well Keeper is an unofficial, fan-made collection tracking app for Disney Lorcana.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                Text("This app is not affiliated with, endorsed by, or sponsored by Disney or Ravensburger.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                Text("All card images, names, and game elements are property of their respective owners.", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
                Text("Made with ❤️ for the Lorcana community", style = MaterialTheme.typography.bodySmall, color = LorcanaGold)
            }
        }
    }

    when (dialog) {
        "delete" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("Delete All Data?") },
            text = { Text("This will permanently delete all your collected cards, wishlist, decks, and all associated data. This action cannot be undone.") },
            confirmButton = {
                TextButton(onClick = {
                    app.collection.deleteAllData()
                    dialog = null
                    scope.launch { snackbar.showSnackbar("All data deleted") }
                }) { Text("Delete All", color = SystemColors.red) }
            },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text("Cancel") } },
        )
        "disclaimer" -> LegalDialog("⚠️ Important Disclaimer", LegalText.disclaimer) { dialog = null }
        "privacy" -> LegalDialog("Privacy Policy", LegalText.privacy) { dialog = null }
    }
}

@Composable
private fun SettingsLink(title: String, icon: ImageVector, tint: Color = LorcanaGold, badge: Boolean = false, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = tint)
        Text("  $title", color = Color.White, modifier = Modifier.weight(1f))
        if (badge) Box(Modifier.size(8.dp).background(LorcanaGold, CircleShape))
    }
}

@Composable
private fun LegalDialog(title: String, sections: List<Pair<String, String>>, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                sections.forEach { (heading, body) ->
                    Text(heading, style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                    Text(body, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } },
    )
}

object LegalText {
    val disclaimer = listOf(
        "Unofficial Application" to "Ink Well Keeper is an unofficial, fan-made application and is not affiliated with, endorsed by, or sponsored by The Walt Disney Company or Ravensburger AG.\n\nThis app is provided for informational and organizational purposes only to help fans track and manage their personal Disney Lorcana trading card collections.",
        "Intellectual Property" to "Disney Lorcana is a trademark of The Walt Disney Company. All card images, character names, artwork, game mechanics, and related intellectual property are owned by The Walt Disney Company and Ravensburger AG.\n\nAll trademarks, service marks, trade names, product names, and logos are the property of their respective owners.",
        "Fair Use" to "This app uses card data and information under the doctrine of fair use for the purpose of:\n• Personal collection organization\n• Educational reference\n• Commentary and criticism\n• Transformative use (collection tracking tool)\n\nNo copyright infringement is intended. This app does not compete with official Disney Lorcana products or services.",
        "Liability" to "Ink Well Keeper is provided \"as is\" without warranties of any kind. The developers are not responsible for:\n• Accuracy of card data or pricing information\n• Loss of data\n• Any damages arising from use of this app\n\nPricing information is sourced from third-party marketplaces and may not reflect actual market values. Cards without available market data will not display a price.",
    )

    val privacy = listOf(
        "Introduction" to "Ink Well Keeper (\"the app\") is built to keep your data yours. This policy explains what is collected, what isn't, and where your information goes.",
        "Your Collection Data" to "Cards, decks, wishlists, binders, photos you attach, and stats are stored on your device. On Android there is no cloud sync; use JSON backups to move your data. Uninstalling the app removes it.\n\nWe do not require account creation or login.",
        "Camera" to "The camera is used only to recognize trading cards. Recognition happens on your device; scan images are not uploaded anywhere. Photos you deliberately attach to a card stay in your collection data. You can revoke camera access anytime in Android Settings.",
        "Analytics" to "The Android app does not send analytics.",
        "AI Features (Pro)" to "When you use the Rules Assistant or AI Deck Builder, the text of your question and relevant card names are sent through Ink Well Keeper's server to OpenAI to generate a response. The server checks your subscription and daily limit using your anonymous RevenueCat ID and does not store your questions. Don't include personal information in prompts. Your collection is not uploaded wholesale.",
        "Subscriptions" to "Ink Well Keeper Pro purchases are processed by Google Play and managed through RevenueCat, which handles subscription status using anonymous identifiers. We never see your payment details.",
        "Prices & Purchase Links" to "Card prices come from public market data; requests contain card identifiers, not personal data. \"Buy\" buttons are affiliate links to third-party marketplaces (e.g. TCGplayer, Cardmarket) with their own privacy policies; the app may earn a commission at no cost to you and receives no information about your purchases.",
        "Contact" to "Questions? Email brevbot2@gmail.com.",
    )
}
