package co.brevinb.inkwellkeeper.ui.rules

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Stop
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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ai.OpenAIService
import co.brevinb.inkwellkeeper.ai.RulesAssistant
import co.brevinb.inkwellkeeper.ai.RulesMessage
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.ui.LocalApp
import coil3.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.markdown
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.scan.CardPickerSheet
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.delay

/** Chat with the AI rules assistant; cards can be attached so answers use exact card text. */
@Composable
fun RulesAssistantScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val service = app.rules
    var input by remember { mutableStateOf("") }
    val attached = remember { mutableStateListOf<LorcanaCard>() }
    var picking by remember { mutableStateOf(false) }
    var showHistory by remember { mutableStateOf(false) }
    var suggested by remember { mutableStateOf<LorcanaCard?>(null) }
    val listState = rememberLazyListState()

    LaunchedEffect(Unit) {
        RulesAssistantSeed.card?.let { if (attached.none { a -> a.id == it.id }) attached += it }
        RulesAssistantSeed.card = null
        RulesAssistantSeed.question?.let { input = it }
        RulesAssistantSeed.question = null
    }
    LaunchedEffect(input) {
        delay(400)
        suggested = RulesAssistant.suggestion(input)?.takeIf { s -> attached.none { it.name == s.name } }
    }
    val itemCount = service.messages.size + if (service.isLoading) 1 else 0
    LaunchedEffect(itemCount) { if (itemCount > 0) listState.animateScrollToItem(itemCount - 1) }

    fun submit(text: String) {
        service.send(text, attached.toList())
        input = ""
        attached.clear()
        suggested = null
    }

    InkwellScaffold(
        "Rules Assistant",
        showBack = true,
        actions = {
            IconButton(onClick = { showHistory = true }) { Icon(Icons.Filled.History, contentDescription = "Recent Chats") }
            IconButton(onClick = { service.newChat() }, enabled = service.messages.isNotEmpty()) { Icon(Icons.Filled.Edit, contentDescription = "New Chat") }
        },
    ) { padding ->
        when {
            !AppSettings.isProUnlocked -> {
                EmptyState(Icons.AutoMirrored.Filled.MenuBook, "Lorcana Rules Assistant", "Instant AI answers to rulings, keywords, and card interactions — included with Pro.", Modifier.padding(padding)) {
                    LorcanaPrimaryButton(onClick = { nav.navigate(Routes.paywall("rulesTab")) }) { Text("Unlock with Pro") }
                }
            }
            !OpenAIService.isConfigured -> {
                EmptyState(Icons.AutoMirrored.Filled.MenuBook, "Service Unavailable", "The Rules Assistant is temporarily unavailable. Please try again later.\n\nIn the meantime, you can find the official rules at disneylorcana.com.", Modifier.padding(padding))
            }
            else -> Column(Modifier.padding(padding).fillMaxSize().imePadding()) {
                LazyColumn(Modifier.weight(1f), state = listState, contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (service.messages.isEmpty() && !service.isLoading) {
                        item { WelcomeHeader(onAsk = ::submit, onAttach = { picking = true }) }
                    }
                    items(service.messages, key = { it.id }) { message ->
                        MessageBubble(message)
                        val isLastAssistant = !message.isUser && !message.isError && message == service.messages.lastOrNull()
                        if (isLastAssistant) {
                            val cards = service.messages.lastOrNull { it.isUser }?.attachedCards.orEmpty()
                            if (cards.isNotEmpty()) FollowUpChips(RulesAssistant.followUps(cards)) { q -> service.send(q, emptyList()) }
                        }
                    }
                    if (service.isLoading) {
                        item {
                            if (service.streaming.isEmpty()) Row(verticalAlignment = Alignment.CenterVertically) {
                                CircularProgressIndicator(Modifier.size(16.dp), color = LorcanaGold, strokeWidth = 2.dp)
                                Text("  Thinking…", color = Color.Gray)
                            } else MessageBubble(RulesMessage(id = "streaming", content = service.streaming, isUser = false))
                        }
                    }
                    if (service.lastSendFailed && !service.isLoading) {
                        item {
                            TextButton(onClick = { service.retryLast() }) {
                                Icon(Icons.Filled.Refresh, null, tint = LorcanaGold)
                                Text(" Retry", color = LorcanaGold)
                            }
                        }
                    }
                }
                InputBar(
                    input = input,
                    onInput = { input = it },
                    attached = attached,
                    suggested = suggested,
                    remaining = service.remainingToday,
                    isLoading = service.isLoading,
                    onAttach = { picking = true },
                    onAcceptSuggestion = { s -> if (attached.size < 4) attached += s; suggested = null },
                    onDismissSuggestion = { suggested = null },
                    onSend = { submit(input) },
                    onStop = { service.stop() },
                )
            }
        }
    }

    if (picking) {
        CardPickerSheet("Attach a Card", onDismiss = { picking = false }) { card ->
            if (attached.size < 4 && attached.none { it.id == card.id }) attached += card
            picking = false
        }
    }
    if (showHistory) ChatHistorySheet(service) { showHistory = false }
}

@Composable
private fun WelcomeHeader(onAsk: (String) -> Unit, onAttach: () -> Unit) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Icon(Icons.AutoMirrored.Filled.MenuBook, null, tint = LorcanaGold, modifier = Modifier.size(52.dp))
        Text("Lorcana Rules Assistant", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
        Text("Ask about rules, keywords, or card interactions", color = Color.Gray, textAlign = TextAlign.Center)
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaGold.copy(alpha = 0.12f))
                .border(1.dp, LorcanaGold.copy(alpha = 0.3f), RoundedCornerShape(12.dp)).clickable(onClick = onAttach).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.AddCircle, null, tint = LorcanaGold)
            Column(Modifier.padding(start = 12.dp)) {
                Text("Ask about specific cards", fontWeight = FontWeight.SemiBold, color = Color.White)
                Text("Attach up to 4 cards from your collection or search", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
        }
        Text("Try asking:", style = MaterialTheme.typography.labelLarge, color = Color.Gray, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        RulesAssistant.suggestedQuestions.forEach { q ->
            Text(
                q, color = Color.White,
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(LorcanaDark.copy(alpha = 0.8f)).clickable { onAsk(q) }.padding(12.dp),
            )
        }
    }
}

@Composable
private fun MessageBubble(message: RulesMessage) {
    val bg = when {
        message.isUser -> LorcanaGold.copy(alpha = 0.22f)
        message.isError -> SystemColors.red.copy(alpha = 0.18f)
        else -> LorcanaDark.copy(alpha = 0.9f)
    }
    Column(Modifier.fillMaxWidth(), horizontalAlignment = if (message.isUser) Alignment.End else Alignment.Start) {
        message.attachedCards?.takeIf { it.isNotEmpty() }?.let { cards ->
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(bottom = 4.dp)) {
                cards.forEach { AsyncImage(it.imageUrl, it.name, Modifier.size(32.dp, 45.dp).clip(RoundedCornerShape(4.dp)), contentScale = ContentScale.Crop) }
            }
        }
        Box(Modifier.widthIn(max = 320.dp).clip(RoundedCornerShape(16.dp)).background(bg).padding(12.dp)) {
            if (message.isUser) Text(message.content, color = Color.White)
            else Text(markdown(message.content), color = Color.White, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun FollowUpChips(suggestions: List<String>, onTap: (String) -> Unit) {
    Row(Modifier.horizontalScroll(rememberScrollState()).padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        suggestions.forEach { s ->
            Text(
                s, style = MaterialTheme.typography.labelMedium, color = LorcanaGold,
                modifier = Modifier.clip(RoundedCornerShape(50)).border(1.dp, LorcanaGold.copy(alpha = 0.4f), RoundedCornerShape(50)).clickable { onTap(s) }.padding(horizontal = 12.dp, vertical = 6.dp),
            )
        }
    }
}

@Composable
private fun InputBar(
    input: String,
    onInput: (String) -> Unit,
    attached: List<LorcanaCard>,
    suggested: LorcanaCard?,
    remaining: Int,
    isLoading: Boolean,
    onAttach: () -> Unit,
    onAcceptSuggestion: (LorcanaCard) -> Unit,
    onDismissSuggestion: () -> Unit,
    onSend: () -> Unit,
    onStop: () -> Unit,
) {
    Column(Modifier.fillMaxWidth().background(LorcanaDark.copy(alpha = 0.95f)).navigationBarsPadding().padding(horizontal = 12.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        suggested?.let { card ->
            Row(Modifier.clip(RoundedCornerShape(10.dp)).background(LorcanaGold.copy(alpha = 0.12f)).clickable { onAcceptSuggestion(card) }.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                CardImage(card, Modifier.size(24.dp, 34.dp).clip(RoundedCornerShape(3.dp)))
                Text(buildAnnotatedString { append("  Talking about "); withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(card.name) }; append("?") }, style = MaterialTheme.typography.labelMedium, color = Color.White, modifier = Modifier.weight(1f))
                IconButton(onClick = onDismissSuggestion, modifier = Modifier.size(24.dp)) { Icon(Icons.Filled.Close, "Dismiss", tint = Color.Gray) }
            }
        }
        if (attached.isNotEmpty()) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                attached.forEach { card ->
                    Row(Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 10.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(card.name, style = MaterialTheme.typography.labelSmall, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 160.dp))
                        Icon(Icons.Filled.Close, "Remove ${card.name}", tint = Color.Gray, modifier = Modifier.padding(start = 4.dp).size(14.dp).clickable { (attached as? MutableList<LorcanaCard>)?.remove(card) })
                    }
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onAttach, enabled = attached.size < 4) { Icon(Icons.Filled.AddCircle, "Attach card", tint = LorcanaGold) }
            OutlinedTextField(
                input, onInput, Modifier.weight(1f),
                placeholder = { Text("Ask a rules question…") },
                maxLines = 4,
                shape = RoundedCornerShape(20.dp),
                colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LorcanaGold, unfocusedBorderColor = Color.White.copy(alpha = 0.15f)),
            )
            if (isLoading) IconButton(onClick = onStop) { Icon(Icons.Filled.Stop, "Stop", tint = LorcanaGold) }
            else IconButton(onClick = onSend, enabled = input.isNotBlank() && remaining > 0) { Icon(Icons.AutoMirrored.Filled.Send, "Send", tint = if (input.isNotBlank()) LorcanaGold else Color.Gray) }
        }
        Text("$remaining question${if (remaining == 1) "" else "s"} left today", style = MaterialTheme.typography.labelSmall, color = Color.Gray, modifier = Modifier.align(Alignment.CenterHorizontally))
    }
}

@Composable
private fun ChatHistorySheet(service: RulesAssistant, onDismiss: () -> Unit) {
    FullScreenSheet(title = "Recent Chats", onDismiss = onDismiss, dismissLabel = "Done") { padding ->
        if (service.savedChats.isEmpty()) {
            EmptyState(Icons.Filled.History, "No Saved Chats", "Your conversations will appear here", Modifier.padding(padding))
            return@FullScreenSheet
        }
        LazyColumn(Modifier.padding(padding), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(service.savedChats, key = { it.id }) { chat ->
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).clickable { service.load(chat); onDismiss() }.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (chat.isPinned) Icon(Icons.Filled.PushPin, null, tint = LorcanaGold, modifier = Modifier.size(14.dp))
                    Column(Modifier.weight(1f).padding(start = 6.dp)) {
                        Text(chat.title, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Text("${chat.messages.size} messages", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                    IconButton(onClick = { service.togglePin(chat) }) { Icon(Icons.Filled.PushPin, if (chat.isPinned) "Unpin" else "Pin", tint = if (chat.isPinned) LorcanaGold else Color.Gray) }
                    IconButton(onClick = { service.delete(chat) }) { Icon(Icons.Filled.Delete, "Delete", tint = SystemColors.red) }
                }
            }
        }
    }
}
