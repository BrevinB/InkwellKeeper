package co.brevinb.inkwellkeeper.billing

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.LibraryBooks
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.AddToPhotos
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.AutoFixHigh
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.SwapHorizontalCircle
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.VerticalAlignTop
import androidx.compose.ui.graphics.vector.ImageVector

/** One thing Pro unlocks, as shown on the paywall (iOS PaywallFeature). */
data class PaywallFeature(val id: String, val icon: ImageVector, val title: String, val description: String) {
    companion object {
        val valueHistory = PaywallFeature("valueHistory", Icons.AutoMirrored.Filled.ShowChart, "Collection Value History", "Watch what your collection is worth rise and fall, day by day")
        val movers = PaywallFeature("movers", Icons.Filled.SwapVert, "Biggest Movers", "See which of your cards gained and lost the most each week")
        val highsAndLows = PaywallFeature("highsAndLows", Icons.Filled.VerticalAlignTop, "Highs & Lows", "Spot the cards sitting at the top or bottom of their price range")
        val costBasis = PaywallFeature("costBasis", Icons.Filled.Sell, "Cost vs Value", "Record what you paid and track the gain or loss on every card")
        val foilPremium = PaywallFeature("foilPremium", Icons.Filled.AutoAwesome, "Foil Premium", "Compare what your foils are worth against everything else")
        val tradeCalculator = PaywallFeature("tradeCalculator", Icons.Filled.SwapHoriz, "Trade Calculator", "Value both sides of a trade — scan cards straight in — and share the result")
        val unlimitedStorage = PaywallFeature("unlimitedStorage", Icons.AutoMirrored.Filled.LibraryBooks, "Unlimited Binders & Boxes", "Mirror every binder, trove and box you own, with premium cover finishes")
        val setBinders = PaywallFeature("setBinders", Icons.Filled.GridOn, "Set Binders", "A pocket for every card in a set, with ghosts showing the ones you're missing")
        val rulesExpert = PaywallFeature("rulesExpert", Icons.Filled.AutoAwesome, "AI Rules Expert", "Ask any rules question and get an answer with rule citations")
        val deckBuilder = PaywallFeature("deckBuilder", Icons.Filled.AutoFixHigh, "AI Deck Builder", "Generate a deck from a description, or finish one you started")
        val cardAnalysis = PaywallFeature("cardAnalysis", Icons.Filled.AddToPhotos, "Card Analysis", "Attach up to 4 cards to ask about a specific interaction")
        val strategyGuides = PaywallFeature("strategyGuides", Icons.Filled.Map, "AI Strategy Guides", "Get a game plan for any deck — matchups, mulligans, win conditions")
        val shareRulings = PaywallFeature("shareRulings", Icons.Filled.Share, "Share Rulings", "Turn any answer into an image and settle the debate in the group chat")
        val chatHistory = PaywallFeature("chatHistory", Icons.Filled.Forum, "Chat History", "Save, pin, and revisit your past conversations")

        /** Everything Pro includes, in the order used when no context applies. */
        val all = listOf(
            valueHistory, movers, highsAndLows, costBasis, foilPremium,
            tradeCalculator, unlimitedStorage, setBinders, rulesExpert, deckBuilder, cardAnalysis,
            strategyGuides, shareRulings, chatHistory,
        )
    }
}

/**
 * What the paywall leads with, based on where it was opened from (iOS PaywallContext). Each
 * context leads with what the reader just reached for, then lists the rest of Pro.
 */
data class PaywallContext(
    val source: String,
    val heroIcon: ImageVector,
    val headline: String,
    val subheadline: String,
    val leadFeatures: List<PaywallFeature>,
) {
    val supportingFeatures: List<PaywallFeature>
        get() = PaywallFeature.all.filter { feature -> leadFeatures.none { it.id == feature.id } }

    companion object {
        fun forSource(source: String): PaywallContext = when (source) {
            "portfolioHistory" -> portfolio
            "tradeCalculator" -> trades
            "deckBuilder", "deckCompleter", "deckStrategy" -> deckBuilding
            "rulesTab", "cardAsk" -> rules
            "storageLimit", "storageTheme", "storageSetBinder", "storageScan" -> storage
            else -> general
        }

        val portfolio = PaywallContext(
            "portfolioHistory", Icons.AutoMirrored.Filled.ShowChart,
            "Know what your collection is worth",
            "Track its value over time, see what moved this week, and what you're up on.",
            listOf(PaywallFeature.valueHistory, PaywallFeature.movers, PaywallFeature.costBasis),
        )
        val trades = PaywallContext(
            "tradeCalculator", Icons.Filled.SwapHorizontalCircle,
            "Never lose a trade again",
            "Value both sides before you agree, then share the result.",
            listOf(PaywallFeature.tradeCalculator, PaywallFeature.valueHistory, PaywallFeature.highsAndLows),
        )
        val deckBuilding = PaywallContext(
            "deckBuilder", Icons.Filled.AutoFixHigh,
            "Build better decks, faster",
            "Describe a deck and get one back — or let AI finish the one you started.",
            listOf(PaywallFeature.deckBuilder, PaywallFeature.strategyGuides, PaywallFeature.rulesExpert),
        )
        val rules = PaywallContext(
            "rulesTab", Icons.AutoMirrored.Filled.MenuBook,
            "Settle any rules question",
            "Instant answers with rule citations, so the game keeps moving.",
            listOf(PaywallFeature.rulesExpert, PaywallFeature.cardAnalysis, PaywallFeature.shareRulings),
        )
        val storage = PaywallContext(
            "storageLimit", Icons.AutoMirrored.Filled.LibraryBooks,
            "Organize every card you own",
            "Unlimited binders and boxes, set checklists, and covers that look the part.",
            listOf(PaywallFeature.unlimitedStorage, PaywallFeature.setBinders, PaywallFeature.valueHistory),
        )
        val general = PaywallContext(
            "general", Icons.Filled.AutoAwesome,
            "Inkwell Pro",
            "Everything you need to track what you own and play your best.",
            listOf(PaywallFeature.valueHistory, PaywallFeature.tradeCalculator, PaywallFeature.rulesExpert),
        )
    }
}
