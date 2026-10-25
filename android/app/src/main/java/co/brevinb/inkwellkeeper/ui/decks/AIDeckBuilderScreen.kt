package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ai.AIDeckFeedbackReason
import co.brevinb.inkwellkeeper.ai.AIDeckService
import co.brevinb.inkwellkeeper.ai.AIDeckSuggestion
import co.brevinb.inkwellkeeper.ai.OpenAIService
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.model.DeckArchetype
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FormTextField
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.components.markdown
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.scan.CardPickerSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

private val quickIdeas = listOf(
    "A fast aggro deck that wins by questing with low-cost characters",
    "A control deck that removes threats and wins late game",
    "A deck built around the Shift mechanic with strong midrange characters",
    "A ramp deck that plays expensive powerful cards earlier than usual",
)

/** Routes to the builder (no deck), the completer, or the strategy guide for a deck. */
@Composable
fun AIDeckBuilderScreen(deckId: String?, strategy: Boolean) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val deck = deckId?.let { app.decks.deck(it) }
    val title = when {
        strategy -> "AI Strategy Guide"
        deck != null -> "AI Complete Deck"
        else -> "AI Deck Builder"
    }
    InkwellScaffold(title, showBack = true) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            when {
                !AppSettings.isProUnlocked -> EmptyState(Icons.Filled.AutoAwesome, title, "Describe a deck and let AI build, complete, or explain it — included with Pro.") {
                    LorcanaPrimaryButton(onClick = { nav.navigate(Routes.paywall("deckBuilder")) }) { Text("Unlock with Pro") }
                }
                !OpenAIService.isConfigured -> EmptyState(Icons.Filled.Warning, "AI Unavailable", "The AI service is temporarily unavailable. Please try again later.")
                strategy && deck != null -> StrategyView(deck)
                deck != null -> CompleterView(deck)
                else -> BuilderView()
            }
        }
    }
}

// MARK: - Builder

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun BuilderView() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val ai = app.aiDecks
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var format by remember { mutableStateOf(DeckFormat.CORE_CONSTRUCTED) }
    var inks by remember { mutableStateOf(setOf<InkColor>()) }
    var archetype by remember { mutableStateOf<DeckArchetype?>(null) }
    var collectionOnly by remember { mutableStateOf(false) }
    var prompt by remember { mutableStateOf("") }
    var excluded by remember { mutableStateOf(setOf<InkColor>()) }
    var generated by remember { mutableStateOf(false) }
    var job by remember { mutableStateOf<Job?>(null) }
    var confirmCreate by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { ai.reset() }

    fun generate(feedback: AIDeckFeedbackReason? = null) {
        generated = true
        Analytics.send("aiDeck.generated", mapOf("ink" to if (inks.isEmpty()) "auto" else inks.map { it.rawValue }.sorted().joinToString("/")))
        val owned = if (collectionOnly) app.collection.collectedCardQuantities else emptyMap()
        job = scope.launch { ai.generateDeck(prompt, format, inks.toList(), archetype, collectionOnly, owned, excluded, feedback) }
    }

    if (generated) {
        ResultsView(
            ai = ai,
            primaryLabel = "Create Deck",
            onPrimary = { confirmCreate = true },
            onStartOver = { ai.reset(); generated = false; excluded = emptySet() },
            onRetry = { generate(it) },
            onCancel = { job?.cancel(); ai.reset(); generated = false },
            onTryDifferentInks = if (ai.inksChosenByAI) {
                {
                    val used = ai.declaredInkColors.toSet()
                    excluded = if (InkColor.entries.size - (excluded + used).size >= format.maxInkColors) excluded + used else used
                    generate()
                }
            } else null,
        )
        if (confirmCreate) {
            val total = ai.suggestions.filter { it.matchedCard != null }.sumOf { it.quantity }
            AlertDialog(
                onDismissRequest = { confirmCreate = false },
                title = { Text("Create Deck?") },
                text = { Text("This will create \"${name.ifBlank { "AI Deck" }}\" with ${ai.matchedCount} matched cards ($total total).") },
                confirmButton = {
                    TextButton(onClick = {
                        confirmCreate = false
                        val deck = app.decks.createDeck(name.ifBlank { "AI Deck" }, prompt, ai.resultFormat, ai.declaredInkColors, archetype)
                        ai.applySuggestions(deck, app.decks)
                        Analytics.send("aiDeck.created")
                        nav.popBackStack()
                        nav.navigate(Routes.deck(deck.id))
                    }) { Text("Create") }
                },
                dismissButton = { TextButton(onClick = { confirmCreate = false }) { Text("Cancel") } },
            )
        }
        return
    }

    Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(40.dp))
            Text("AI Deck Builder", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
            Text("Describe the deck you want and AI will build it for you", color = Color.Gray, textAlign = TextAlign.Center)
        }
        FormSection("Deck Name") { FormTextField(name, { name = it }, "My AI Deck") }
        FormSection("Format") {
            MenuPickerRow("Format", DeckFormat.entries.filter { it != DeckFormat.COCONUT }, format, { format = it; if (inks.size > it.maxInkColors) inks = inks.take(it.maxInkColors).toSet() }, { it.rawValue })
        }
        FormSection("Ink Colors · optional · up to ${format.maxInkColors}", footer = if (inks.isEmpty()) "Leave empty and AI picks the inks that fit your idea best." else null) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                InkColor.entries.forEach { ink ->
                    val selected = ink in inks
                    InkToggle(ink, selected, enabled = selected || inks.size < format.maxInkColors, modifier = Modifier.fillMaxWidth(0.48f)) {
                        inks = if (selected) inks - ink else inks + ink
                    }
                }
            }
        }
        FormSection("Archetype · optional") {
            MenuPickerRow("Archetype", listOf<DeckArchetype?>(null) + DeckArchetype.entries, archetype, { archetype = it }, { it?.rawValue ?: "Any" })
        }
        FormSection("Card Source", footer = if (collectionOnly) "${app.collection.collectedCards.size} cards in your collection" else null) {
            SegmentedPicker(listOf(false, true), collectionOnly, { collectionOnly = it }, { if (it) "My Collection" else "All Cards" })
        }
        FormSection("Describe your deck") {
            OutlinedTextField(
                prompt, { prompt = it }, Modifier.fillMaxWidth().heightIn(min = 110.dp),
                placeholder = { Text("e.g., A fast aggro deck focused on questing with low-cost characters...") },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LorcanaGold),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Quick Ideas", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
            quickIdeas.forEach { idea ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(LorcanaDark.copy(alpha = 0.6f)).clickable { prompt = idea }.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(14.dp))
                    Text(idea, color = Color.White, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f).padding(horizontal = 8.dp))
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.Gray)
                }
            }
        }
        LorcanaPrimaryButton(onClick = { generate() }, enabled = prompt.isNotBlank() && !ai.isLoading, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.AutoAwesome, null)
            Spacer(Modifier.width(6.dp))
            Text("Generate Deck")
        }
        RemainingLabel(ai.remainingToday)
    }
}

@Composable
private fun RemainingLabel(remaining: Int) {
    Text(
        "$remaining AI generation${if (remaining == 1) "" else "s"} left today",
        style = MaterialTheme.typography.labelSmall, color = Color.Gray, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center,
    )
}

// MARK: - Shared results

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ResultsView(
    ai: AIDeckService,
    primaryLabel: String,
    onPrimary: () -> Unit,
    onStartOver: () -> Unit,
    onRetry: (AIDeckFeedbackReason?) -> Unit,
    onCancel: () -> Unit,
    onTryDifferentInks: (() -> Unit)? = null,
    loadingText: String = "Building your deck...",
) {
    var replacing by remember { mutableStateOf<AIDeckSuggestion?>(null) }
    var adding by remember { mutableStateOf(false) }
    var feedbackOpen by remember(ai.generation) { mutableStateOf(false) }

    if (ai.isLoading) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            CircularProgressIndicator(color = LorcanaGold)
            Text(loadingText, style = MaterialTheme.typography.titleMedium, color = Color.White)
            if (ai.streaming.isNotEmpty()) Text(markdown(ai.streaming.substringBefore("[DECKLIST]").substringBefore("[SWAPS]")), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
            TextButton(onClick = onCancel) { Text("Cancel", color = LorcanaGold) }
        }
        return
    }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        ai.errorMessage?.let { error ->
            Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SystemColors.red.copy(alpha = 0.15f)).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.Warning, null, tint = SystemColors.red)
                Text(error, color = Color.White, modifier = Modifier.weight(1f).padding(horizontal = 8.dp), style = MaterialTheme.typography.bodySmall)
                TextButton(onClick = { onRetry(null) }) { Text("Try Again", color = LorcanaGold) }
            }
        }
        if (ai.inksChosenByAI && ai.declaredInkColors.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("AI chose", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                ai.declaredInkColors.forEach { InkChip(it) }
                Spacer(Modifier.weight(1f))
                onTryDifferentInks?.let { TextButton(onClick = it) { Text("Try different inks", color = LorcanaGold) } }
            }
        }
        val strategy = ai.strategyText.ifEmpty { if (ai.swaps.isNotEmpty()) ai.rawResponse.substringBefore("[SWAPS]").trim() else "" }
        if (strategy.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(14.dp)) {
                Text("Strategy", style = MaterialTheme.typography.labelLarge, color = LorcanaGold)
                Text(markdown(strategy), color = Color.White, style = MaterialTheme.typography.bodyMedium)
            }
        }
        ai.colorConstraintNote?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = SystemColors.orange) }
        ai.ruleReport?.let { report ->
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(if (report.isLegal) Icons.Filled.CheckCircle else Icons.Filled.Warning, null, tint = if (report.isLegal) SystemColors.green else SystemColors.orange, modifier = Modifier.size(16.dp))
                    Text(if (report.isLegal) "  Follows deck rules" else "  Needs attention", color = Color.White, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.weight(1f))
                    Text("${report.totalCards} cards · ${report.inkableCards} inkable", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
                report.violations.forEach { Text("• $it", style = MaterialTheme.typography.labelSmall, color = SystemColors.orange) }
                report.warnings.forEach { Text("• $it", style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
            }
        }
        if (ai.swaps.isNotEmpty()) {
            Text("Suggested Swaps", style = MaterialTheme.typography.titleMedium, color = Color.White)
            Text("Toggle any swap off, then apply the rest.", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            ai.swaps.forEach { swap ->
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(LorcanaDark.copy(alpha = 0.7f)).clickable { ai.toggleSwap(swap.id) }.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(swap.isAccepted, { ai.toggleSwap(swap.id) }, colors = CheckboxDefaults.colors(checkedColor = LorcanaGold))
                    Column(Modifier.weight(1f)) {
                        Text("− ${swap.removeQuantity}x ${swap.removeName}", color = SystemColors.red, style = MaterialTheme.typography.bodySmall)
                        Text("+ ${swap.add.quantity}x ${swap.add.cardName}", color = SystemColors.green, style = MaterialTheme.typography.bodySmall)
                    }
                    swap.add.matchedCard?.let { CardImage(it, Modifier.size(34.dp, 48.dp).clip(RoundedCornerShape(4.dp))) }
                }
            }
        }
        if (ai.suggestions.isNotEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("Deck List", style = MaterialTheme.typography.titleMedium, color = Color.White, modifier = Modifier.weight(1f))
                TextButton(onClick = { adding = true }) { Icon(Icons.Filled.Add, null, tint = LorcanaGold); Text("Add Card", color = LorcanaGold) }
            }
            if (ai.unmatchedCount > 0) Text("${ai.unmatchedCount} cards could not be matched. Tap a card to replace it.", style = MaterialTheme.typography.labelSmall, color = SystemColors.orange)
            ai.suggestions.sortedBy { it.matchedCard?.cost ?: 99 }.forEach { s -> SuggestionRow(s, onTap = { replacing = s }, onRemove = { ai.remove(s.id) }) }
        }
        if (ai.suggestions.isNotEmpty() || ai.swaps.isNotEmpty()) {
            if (!feedbackOpen) {
                TextButton(onClick = { feedbackOpen = true }, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Not quite right?", color = Color.Gray) }
            } else {
                Text("What was off?", style = MaterialTheme.typography.labelLarge, color = Color.White)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    AIDeckFeedbackReason.entries.forEach { reason ->
                        Text(
                            reason.title, style = MaterialTheme.typography.labelMedium, color = LorcanaGold,
                            modifier = Modifier.clip(RoundedCornerShape(50)).border(1.dp, LorcanaGold.copy(alpha = 0.4f), RoundedCornerShape(50))
                                .clickable { Analytics.send("aiDeck.feedback", mapOf("reason" to reason.name)); onRetry(reason) }.padding(horizontal = 12.dp, vertical = 6.dp),
                        )
                    }
                }
            }
            LorcanaPrimaryButton(onClick = onPrimary, enabled = ai.matchedCount > 0 || ai.swaps.any { it.isAccepted }, modifier = Modifier.fillMaxWidth()) { Text(primaryLabel) }
        }
        LorcanaSecondaryButton(onClick = onStartOver, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.Refresh, null)
            Spacer(Modifier.width(6.dp))
            Text("Start Over")
        }
    }

    replacing?.let { s ->
        CardPickerSheet(if (s.matchedCard == null) "Replace ${s.cardName}" else "Replace Card", onDismiss = { replacing = null }) { card ->
            ai.replace(s.id, card, s.quantity)
            replacing = null
        }
    }
    if (adding) {
        CardPickerSheet("Add Card", onDismiss = { adding = false }) { card ->
            ai.add(card, 1)
            adding = false
        }
    }
}

@Composable
private fun SuggestionRow(s: AIDeckSuggestion, onTap: () -> Unit, onRemove: () -> Unit) {
    val card = s.matchedCard
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(if (card == null) SystemColors.orange.copy(alpha = 0.12f) else LorcanaDark.copy(alpha = 0.7f)).clickable(onClick = onTap).padding(8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (card != null) CardImage(card, Modifier.size(34.dp, 48.dp).clip(RoundedCornerShape(4.dp)))
        else Icon(Icons.Filled.Warning, null, tint = SystemColors.orange, modifier = Modifier.size(34.dp))
        Column(Modifier.weight(1f)) {
            Text("${s.quantity}x ${card?.name ?: s.cardName}", color = Color.White, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            if (card != null) Text("Cost ${card.cost} · ${card.type}" + (card.inkColor?.let { " · $it" } ?: ""), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            else Text("Card not found — tap to replace", style = MaterialTheme.typography.labelSmall, color = SystemColors.orange)
        }
        IconButton(onClick = onRemove) { Icon(Icons.Filled.RemoveCircle, "Remove", tint = SystemColors.red.copy(alpha = 0.8f)) }
    }
}

// MARK: - Completer

@Composable
private fun CompleterView(deck: Deck) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val ai = app.aiDecks
    val scope = rememberCoroutineScope()
    var notes by remember { mutableStateOf("") }
    var collectionOnly by remember { mutableStateOf(false) }
    var started by remember { mutableStateOf(false) }
    var job by remember { mutableStateOf<Job?>(null) }
    var confirm by remember { mutableStateOf(false) }
    val full = deck.totalCards >= 60
    LaunchedEffect(Unit) { ai.reset() }

    fun run(feedback: AIDeckFeedbackReason? = null) {
        started = true
        val owned = if (collectionOnly) app.collection.collectedCardQuantities else emptyMap()
        job = scope.launch {
            if (full) ai.improveDeck(deck.cards.toList(), deck.deckFormat, deck.deckInkColors, deck.deckArchetype, notes, feedback)
            else ai.completeDeck(deck.cards.toList(), deck.deckFormat, deck.deckInkColors, deck.deckArchetype, notes, collectionOnly, owned, feedback)
        }
    }

    if (started) {
        ResultsView(
            ai = ai,
            primaryLabel = if (full) "Apply ${ai.swaps.count { it.isAccepted }} Swap${if (ai.swaps.count { it.isAccepted } == 1) "" else "s"}" else "Add to Deck",
            onPrimary = { if (full) { ai.applySwaps(deck, app.decks); nav.popBackStack() } else confirm = true },
            onStartOver = { ai.reset(); started = false },
            onRetry = { run(it) },
            onCancel = { job?.cancel(); ai.reset(); started = false },
            loadingText = "Analyzing your deck...",
        )
        if (confirm) {
            val total = ai.suggestions.filter { it.matchedCard != null }.sumOf { it.quantity }
            AlertDialog(
                onDismissRequest = { confirm = false },
                title = { Text("Add Cards?") },
                text = { Text("This will add $total cards to \"${deck.name}\".") },
                confirmButton = { TextButton(onClick = { confirm = false; ai.applySuggestions(deck, app.decks); nav.popBackStack() }) { Text("Add") } },
                dismissButton = { TextButton(onClick = { confirm = false }) { Text("Cancel") } },
            )
        }
        return
    }

    Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(40.dp))
            Text("Complete Your Deck", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
            Text("AI will analyze your current cards and suggest additions", color = Color.Gray, textAlign = TextAlign.Center)
        }
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(deck.name, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("${deck.totalCards}/60 cards · ${deck.deckFormat.rawValue}", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
            InkDots(deck.deckInkColors)
        }
        when {
            deck.deckFormat == DeckFormat.COCONUT -> Text("Coconut beta decks aren't supported by AI completion yet — the singleton rules need special handling.", color = SystemColors.orange, style = MaterialTheme.typography.bodySmall)
            full -> Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.SwapHoriz, null, tint = LorcanaGold)
                Text("  Your deck is full — AI will suggest swaps to strengthen it.", color = Color.White, style = MaterialTheme.typography.bodySmall)
            }
        }
        FormSection("Additional Notes (optional)") {
            OutlinedTextField(
                notes, { notes = it }, Modifier.fillMaxWidth().heightIn(min = 90.dp),
                placeholder = { Text("e.g., I want to focus more on questing, add more removal...") },
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LorcanaGold),
            )
        }
        if (!full) {
            FormSection("Card Source", footer = if (collectionOnly) "${app.collection.collectedCards.size} cards in your collection" else null) {
                SegmentedPicker(listOf(false, true), collectionOnly, { collectionOnly = it }, { if (it) "My Collection" else "All Cards" })
            }
        }
        LorcanaPrimaryButton(onClick = { run() }, enabled = deck.deckFormat != DeckFormat.COCONUT, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Filled.AutoAwesome, null)
            Spacer(Modifier.width(6.dp))
            Text(if (full) "Suggest Swaps" else "Complete Deck")
        }
        RemainingLabel(ai.remainingToday)
    }
}

// MARK: - Strategy

@Composable
private fun StrategyView(deck: Deck) {
    val app = LocalApp.current
    val ai = app.aiDecks
    val scope = rememberCoroutineScope()
    LaunchedEffect(deck.id) { if ((ai.strategyResponse.isEmpty() || ai.strategyDeckId != deck.id) && !ai.strategyLoading) ai.generateStrategy(deck) }

    Column(Modifier.verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Psychology, null, tint = LorcanaGold)
            Column(Modifier.weight(1f).padding(horizontal = 10.dp)) {
                Text(deck.name, color = Color.White, fontWeight = FontWeight.SemiBold)
                Text("${deck.totalCards} cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
            InkDots(deck.deckInkColors)
        }
        val text = if (ai.strategyDeckId == deck.id) ai.strategyStreaming.ifEmpty { ai.strategyResponse } else ""
        if (ai.strategyLoading && text.isEmpty()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(Modifier.size(18.dp), color = LorcanaGold, strokeWidth = 2.dp)
                Text("  Analyzing your deck...", color = Color.Gray)
            }
        }
        if (text.isNotEmpty()) Text(markdown(text), color = Color.White, style = MaterialTheme.typography.bodyMedium)
        ai.strategyError?.let { Text(it, color = SystemColors.red) }
        if (!ai.strategyLoading) {
            LorcanaSecondaryButton(onClick = { scope.launch { ai.generateStrategy(deck) } }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.Refresh, null)
                Spacer(Modifier.width(6.dp))
                Text(if (ai.strategyError != null) "Try Again" else "Regenerate")
            }
            RemainingLabel(ai.remainingToday)
        }
    }
}
