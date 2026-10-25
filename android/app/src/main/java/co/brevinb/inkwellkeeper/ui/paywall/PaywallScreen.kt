package co.brevinb.inkwellkeeper.ui.paywall

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.LocalActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.billing.PaywallContext
import co.brevinb.inkwellkeeper.billing.PaywallFeature
import co.brevinb.inkwellkeeper.billing.SubscriptionManager
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import com.revenuecat.purchases.models.Period
import kotlinx.coroutines.launch

const val PRIVACY_POLICY_URL = "https://inkwellkeeper.app/privacy"

/**
 * Subscription paywall (iOS RulesPaywallView). What it leads with depends on [source] — see
 * PaywallContext — and the price and Subscribe button stay pinned below the scrolling pitch.
 */
@Composable
fun PaywallScreen(source: String) {
    val context = PaywallContext.forSource(source)
    val nav = LocalNav.current
    val activity = LocalActivity.current
    val androidContext = LocalContext.current
    val scope = rememberCoroutineScope()
    var selected by remember { mutableStateOf<Package?>(null) }
    var purchasing by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<Pair<String, String>?>(null) }

    LaunchedEffect(Unit) {
        SubscriptionManager.loadOfferings()
        if (selected == null) selected = SubscriptionManager.currentOffering?.availablePackages?.firstOrNull()
    }
    // Leave as soon as Pro is active, so the reader lands back on what they reached for.
    LaunchedEffect(AppSettings.isProUnlocked) {
        if (AppSettings.isProUnlocked) nav.popBackStack()
    }

    InkwellScaffold("Inkwell Pro", showBack = true) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            Column(
                Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp, vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(22.dp),
            ) {
                Icon(context.heroIcon, null, tint = LorcanaGold, modifier = Modifier.size(62.dp))
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(context.headline, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                    Text(context.subheadline, color = Color.Gray, textAlign = TextAlign.Center)
                }
                Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    context.leadFeatures.forEach { FeatureRow(it) }
                }
                SupportingFeatures(context.supportingFeatures)
                Text(
                    "Read the Official Rules",
                    color = Color.Gray,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.clickable {
                        androidContext.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://www.disneylorcana.com/en-US/resources#checks-and-balances")))
                    },
                )
            }
            PurchaseFooter(
                selected = selected,
                purchasing = purchasing,
                onSelect = { selected = it },
                onSubscribe = {
                    val pkg = selected ?: return@PurchaseFooter
                    val host = activity ?: return@PurchaseFooter
                    scope.launch {
                        purchasing = true
                        try {
                            SubscriptionManager.purchase(host, pkg)
                        } catch (_: Exception) {
                            message = "Error" to (SubscriptionManager.error ?: "An unknown error occurred.")
                        } finally {
                            purchasing = false
                        }
                    }
                },
                onRestore = {
                    scope.launch {
                        purchasing = true
                        try {
                            SubscriptionManager.restorePurchases()
                            // Restoring nothing is the common case and used to look like the button was dead.
                            message = "Restore Purchases" to if (SubscriptionManager.isSubscribed) "Your subscription has been restored." else "No previous purchases were found for this Google account."
                        } catch (_: Exception) {
                            message = "Error" to (SubscriptionManager.error ?: "An unknown error occurred.")
                        } finally {
                            purchasing = false
                        }
                    }
                },
                onPrivacyPolicy = { androidContext.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(PRIVACY_POLICY_URL))) },
            )
        }
    }

    message?.let { (title, body) ->
        AlertDialog(
            onDismissRequest = { message = null; SubscriptionManager.error = null },
            title = { Text(title) },
            text = { Text(body) },
            confirmButton = { TextButton(onClick = { message = null; SubscriptionManager.error = null }) { Text("OK") } },
        )
    }
}

@Composable
private fun FeatureRow(feature: PaywallFeature) {
    Row(verticalAlignment = Alignment.Top) {
        Icon(feature.icon, null, tint = LorcanaGold, modifier = Modifier.width(28.dp))
        Column(Modifier.padding(start = 14.dp)) {
            Text(feature.title, style = MaterialTheme.typography.titleSmall, color = Color.White)
            Text(feature.description, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}

/** The rest of Pro, compact — the pitch is tailored but the value on offer is not. */
@Composable
private fun SupportingFeatures(features: List<PaywallFeature>) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Also included", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            features.forEach { feature ->
                Row(Modifier.width(150.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(feature.icon, null, tint = LorcanaGold.copy(alpha = 0.85f), modifier = Modifier.size(16.dp))
                    Text(feature.title, style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.85f), maxLines = 2, modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}

/** Pricing and the subscribe button, pinned below the pitch so the price is never below the fold. */
@Composable
private fun PurchaseFooter(
    selected: Package?,
    purchasing: Boolean,
    onSelect: (Package) -> Unit,
    onSubscribe: () -> Unit,
    onRestore: () -> Unit,
    onPrivacyPolicy: () -> Unit,
) {
    val offering = SubscriptionManager.currentOffering
    Column(
        Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.92f)).navigationBarsPadding().padding(horizontal = 24.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        when {
            !SubscriptionManager.isConfigured ->
                Text("Subscriptions aren't available in this build.", color = Color.Gray, style = MaterialTheme.typography.bodySmall)
            offering == null && SubscriptionManager.isLoading ->
                CircularProgressIndicator(color = LorcanaGold, modifier = Modifier.padding(8.dp))
            offering == null ->
                Text("Unable to load subscription options. Please try again.", color = Color.Gray, style = MaterialTheme.typography.bodySmall, textAlign = TextAlign.Center)
            else -> offering.availablePackages.forEach { pkg ->
                SubscriptionOptionCard(pkg, selected?.identifier == pkg.identifier) { onSelect(pkg) }
            }
        }
        LorcanaPrimaryButton(onClick = onSubscribe, enabled = selected != null && !purchasing, modifier = Modifier.fillMaxWidth()) {
            if (purchasing) CircularProgressIndicator(Modifier.size(20.dp), color = Color.Black, strokeWidth = 2.dp)
            else Text("Subscribe Now", fontWeight = FontWeight.Bold)
        }
        Row(horizontalArrangement = Arrangement.Center) {
            TextButton(onClick = onRestore, enabled = !purchasing && SubscriptionManager.isConfigured, modifier = Modifier.heightIn(min = 44.dp)) {
                Text("Restore", color = LorcanaGold.copy(alpha = 0.85f), style = MaterialTheme.typography.labelMedium)
            }
            TextButton(onClick = onPrivacyPolicy, modifier = Modifier.heightIn(min = 44.dp)) {
                Text("Privacy Policy", color = LorcanaGold.copy(alpha = 0.85f), style = MaterialTheme.typography.labelMedium)
            }
        }
        Text(
            "Auto-renews until cancelled. Cancel anytime in Google Play → Subscriptions.",
            style = MaterialTheme.typography.labelSmall, color = Color.Gray.copy(alpha = 0.8f), textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun SubscriptionOptionCard(pkg: Package, isSelected: Boolean, onTap: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(LorcanaDark.copy(alpha = 0.4f))
            .border(if (isSelected) 2.dp else 1.dp, if (isSelected) LorcanaGold else LorcanaGold.copy(alpha = 0.2f), shape)
            .clickable(onClick = onTap).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(periodLabel(pkg), style = MaterialTheme.typography.titleMedium, color = Color.White)
            introText(pkg)?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = LorcanaGold) }
        }
        if (isSelected) Icon(Icons.Filled.CheckCircle, null, tint = LorcanaGold, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(pkg.product.price.formatted, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = LorcanaGold)
    }
}

private fun periodLabel(pkg: Package): String = when (pkg.packageType) {
    PackageType.WEEKLY -> "Weekly"
    PackageType.MONTHLY -> "Monthly"
    PackageType.TWO_MONTH -> "2 Months"
    PackageType.THREE_MONTH -> "3 Months"
    PackageType.SIX_MONTH -> "6 Months"
    PackageType.ANNUAL -> "Yearly"
    PackageType.LIFETIME -> "Lifetime"
    else -> pkg.product.period?.let(::periodTitle) ?: "Subscription"
}

private fun periodTitle(period: Period): String = when (period.unit) {
    Period.Unit.DAY -> if (period.value == 7) "Weekly" else "${period.value}-Day"
    Period.Unit.WEEK -> if (period.value == 1) "Weekly" else "${period.value}-Week"
    Period.Unit.MONTH -> when (period.value) {
        1 -> "Monthly"
        2, 3, 6 -> "${period.value} Months"
        else -> "${period.value}-Month"
    }
    Period.Unit.YEAR -> if (period.value == 1) "Yearly" else "${period.value}-Year"
    else -> "Subscription"
}

private fun introText(pkg: Package): String? {
    val option = pkg.product.defaultOption ?: return null
    return when {
        option.freePhase != null -> "Free trial included"
        option.introPhase != null -> "Special introductory price"
        else -> null
    }
}
