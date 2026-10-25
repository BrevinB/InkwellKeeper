package co.brevinb.inkwellkeeper.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.CenterFocusWeak
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.ViewCarousel
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.ui.card.CardDetailScreen
import co.brevinb.inkwellkeeper.ui.collection.CollectionScreen
import co.brevinb.inkwellkeeper.ui.navigation.CardDetailMode
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRoute
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.navigation.openCard
import co.brevinb.inkwellkeeper.ui.search.CardSearchScreen
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first

private data class TopTab(val route: String, val label: String, val icon: ImageVector)

/** The four tabs iOS leads with (collect, scan, build, value), then More. */
private val topTabs = listOf(
    TopTab(Routes.COLLECTION, "Collection", Icons.Filled.GridOn),
    TopTab(Routes.SCAN, "Scan", Icons.Filled.CenterFocusWeak),
    TopTab(Routes.DECKS, "Decks", Icons.Filled.ViewCarousel),
    TopTab(Routes.STATS, "Stats", Icons.Filled.BarChart),
    TopTab(Routes.MORE, "More", Icons.Filled.MoreHoriz),
)

@Composable
fun InkwellApp(pendingDeepLink: DeepLinkRoute?, onDeepLinkHandled: () -> Unit) {
    val nav = rememberNavController()
    val app = LocalApp.current
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showBottomBar = topTabs.any { it.route == currentRoute }
    var deckImport by remember { mutableStateOf<Pair<String, String>?>(null) }
    var showOnboarding by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        if (!AppSettings.hasCompletedOnboarding) {
            showOnboarding = true
        } else if (AppSettings.shouldShowWhatsNew) {
            // Existing users see the changelog once per version, a beat after launch.
            delay(1000)
            nav.navigate(Routes.WHATS_NEW)
        }
    }

    // Deep links wait for the catalog, since deck codes and card ids resolve against it.
    LaunchedEffect(pendingDeepLink) {
        val route = pendingDeepLink ?: return@LaunchedEffect
        SetsDataManager.loaded.first { it }
        when (route) {
            is DeepLinkRoute.Deck -> app.decks.previewShareCode(route.code)?.let { deckImport = route.code to it.name }
            is DeepLinkRoute.Card -> SetsDataManager.card(route.id)?.let { nav.openCard(it, CardDetailMode.SET) }
            is DeepLinkRoute.Set -> nav.navigate(Routes.set(route.name))
        }
        onDeepLinkHandled()
    }

    fun selectTab(route: String) {
        nav.navigate(route) {
            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    CompositionLocalProvider(LocalNav provides nav) {
        Scaffold(
            containerColor = Color.Black,
            // Each screen's top bar handles the status bar so the background runs edge to edge.
            contentWindowInsets = WindowInsets(0),
            bottomBar = {
                if (showBottomBar) {
                    NavigationBar(containerColor = Color(0xF2101018)) {
                        topTabs.forEach { tab ->
                            val selected = backStack?.destination?.hierarchy?.any { it.route == tab.route } == true
                            NavigationBarItem(
                                selected = selected,
                                onClick = { selectTab(tab.route) },
                                icon = { Icon(tab.icon, contentDescription = null) },
                                label = { Text(tab.label) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = LorcanaGold,
                                    selectedTextColor = LorcanaGold,
                                    indicatorColor = LorcanaGold.copy(alpha = 0.15f),
                                    unselectedIconColor = Color.Gray,
                                    unselectedTextColor = Color.Gray,
                                ),
                            )
                        }
                    }
                }
            },
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                NavHost(nav, startDestination = Routes.COLLECTION) {
                    composable(Routes.COLLECTION) { CollectionScreen(onScanTapped = { selectTab(Routes.SCAN) }) }
                    composable(Routes.SCAN) { co.brevinb.inkwellkeeper.ui.scan.ScanScreen() }
                    composable(Routes.DECKS) { co.brevinb.inkwellkeeper.ui.decks.DecksScreen() }
                    composable(Routes.STATS) { co.brevinb.inkwellkeeper.ui.stats.StatsScreen() }
                    composable(Routes.MORE) { MoreScreen() }
                    composable(Routes.BOOKSHELF) { co.brevinb.inkwellkeeper.ui.storage.BookshelfScreen() }
                    composable(Routes.SETS) { co.brevinb.inkwellkeeper.ui.sets.SetsScreen() }
                    composable(Routes.TRADES) { co.brevinb.inkwellkeeper.ui.trades.TradeScreen() }
                    composable(Routes.PLAY) { co.brevinb.inkwellkeeper.ui.play.LoreCounterScreen() }
                    composable(
                        "${Routes.AI_DECK_BUILDER}?deck={deck}&strategy={strategy}",
                        arguments = listOf(
                            navArgument("deck") { type = NavType.StringType; nullable = true; defaultValue = null },
                            navArgument("strategy") { type = NavType.BoolType; defaultValue = false },
                        ),
                    ) { entry -> co.brevinb.inkwellkeeper.ui.decks.AIDeckBuilderScreen(entry.arguments?.getString("deck"), entry.arguments?.getBoolean("strategy") ?: false) }
                    composable(Routes.PAYWALL, arguments = listOf(navArgument("source") { type = NavType.StringType; defaultValue = "general" })) { entry ->
                        co.brevinb.inkwellkeeper.ui.paywall.PaywallScreen(entry.arguments?.getString("source") ?: "general")
                    }
                    composable(Routes.STARTER_DECKS) { co.brevinb.inkwellkeeper.ui.decks.StarterDecksScreen() }
                    composable(Routes.WISHLIST) { co.brevinb.inkwellkeeper.ui.wishlist.WishlistScreen() }
                    composable(Routes.SETTINGS) { co.brevinb.inkwellkeeper.ui.settings.SettingsScreen() }
                    composable(Routes.SUPPORT) { co.brevinb.inkwellkeeper.ui.more.SupportScreen() }
                    composable(Routes.WHATS_NEW) { co.brevinb.inkwellkeeper.ui.more.WhatsNewScreen() }
                    composable(Routes.GLOSSARY) { co.brevinb.inkwellkeeper.ui.more.GlossaryScreen() }
                    composable(Routes.PRICING_INFO) { co.brevinb.inkwellkeeper.ui.more.PricingInfoScreen() }
                    composable(Routes.RULES) { co.brevinb.inkwellkeeper.ui.rules.RulesAssistantScreen() }
                    composable(Routes.IMPORT) { co.brevinb.inkwellkeeper.ui.transfer.ImportScreen() }
                    composable(Routes.EXPORT) { co.brevinb.inkwellkeeper.ui.transfer.ExportScreen() }
                    composable(
                        Routes.SEARCH,
                        arguments = listOf(navArgument("wishlist") { type = NavType.BoolType; defaultValue = false }),
                    ) { entry -> CardSearchScreen(wishlistMode = entry.arguments?.getBoolean("wishlist") == true) }
                    composable(
                        Routes.CARD,
                        arguments = listOf(
                            navArgument("data") { type = NavType.StringType },
                            navArgument("mode") { type = NavType.StringType; defaultValue = CardDetailMode.COLLECTION.name },
                        ),
                    ) { entry ->
                        val card = Routes.decodeCard(entry.arguments?.getString("data"))
                        val mode = runCatching { CardDetailMode.valueOf(entry.arguments?.getString("mode").orEmpty()) }.getOrDefault(CardDetailMode.COLLECTION)
                        if (card != null) CardDetailScreen(card, mode) else PlaceholderScreen("Card")
                    }
                    composable(Routes.SET_DETAIL) { entry -> co.brevinb.inkwellkeeper.ui.sets.SetDetailScreen(entry.arguments?.getString("name").orEmpty()) }
                    composable(Routes.DECK) { entry -> co.brevinb.inkwellkeeper.ui.decks.DeckWorkspaceScreen(entry.arguments?.getString("id").orEmpty()) }
                    composable(Routes.CONTAINER) { entry -> co.brevinb.inkwellkeeper.ui.storage.ContainerScreen(entry.arguments?.getString("id").orEmpty()) }
                }
            }
        }

        deckImport?.let { (code, name) ->
            AlertDialog(
                onDismissRequest = { deckImport = null },
                title = { Text("Import Deck") },
                text = { Text("Add “$name” to your decks?") },
                confirmButton = {
                    TextButton(onClick = {
                        app.decks.importDeck(code)?.let { nav.navigate(Routes.deck(it.id)) }
                        deckImport = null
                    }) { Text("Import") }
                },
                dismissButton = { TextButton(onClick = { deckImport = null }) { Text("Cancel") } },
            )
        }
        if (showOnboarding) {
            co.brevinb.inkwellkeeper.ui.onboarding.OnboardingSheet(
                onFinish = { importNow ->
                    AppSettings.markOnboardingComplete()
                    showOnboarding = false
                    if (importNow) nav.navigate(Routes.IMPORT)
                },
            )
        }
    }
}
