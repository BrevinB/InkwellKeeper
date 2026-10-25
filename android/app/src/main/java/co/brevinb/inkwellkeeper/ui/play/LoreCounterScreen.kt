package co.brevinb.inkwellkeeper.ui.play

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.RestartAlt
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import co.brevinb.inkwellkeeper.model.CoconutLeaders
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import java.util.UUID

private enum class LoreGameMode(val label: String, val target: Int, val subtitle: String) {
    STANDARD("Standard", 20, "Play to 20 lore"),
    COCONUT("Coconut", 25, "Multiplayer beta — play to 25 lore"),
}

private data class PlayerLore(val id: String = UUID.randomUUID().toString(), val name: String, val lore: Int = 0, val ink: InkColor, val leader: String? = null)

private data class LoreHistoryEntry(val playerName: String, val from: Int, val to: Int)

private val defaultInks = listOf(InkColor.AMBER, InkColor.SAPPHIRE, InkColor.RUBY, InkColor.EMERALD)

/** Lore counter for 2–4 players: pick a mode, choose inks, then a full-screen table view. */
@Composable
fun LoreCounterScreen() {
    var mode by remember { mutableStateOf(LoreGameMode.STANDARD) }
    var setupPlayers by remember { mutableStateOf<List<PlayerLore>?>(null) }
    var gamePlayers by remember { mutableStateOf<List<PlayerLore>?>(null) }

    InkwellScaffold("Play", showBack = true) { padding ->
        val players = setupPlayers
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(24.dp), verticalArrangement = Arrangement.spacedBy(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            if (players == null) {
                Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(44.dp))
                Text("Lore Counter", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Color.White)
                Text("Track lore for your game", color = Color.White.copy(alpha = 0.6f))
                SegmentedPicker(LoreGameMode.entries, mode, { mode = it }, { it.label })
                Text(mode.subtitle, style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.6f))
                listOf(Triple(2, "2 Players", Icons.Filled.People), Triple(3, "3 Players", Icons.Filled.Groups), Triple(4, "4 Players", Icons.Filled.Groups)).forEach { (count, label, icon) ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
                            .background(Brush.horizontalGradient(listOf(LorcanaDark.copy(alpha = 0.9f), LorcanaDark.copy(alpha = 0.7f))))
                            .border(1.dp, Brush.horizontalGradient(listOf(LorcanaGold.copy(alpha = 0.4f), LorcanaGold.copy(alpha = 0.1f))), RoundedCornerShape(16.dp))
                            .clickable { setupPlayers = List(count) { i -> PlayerLore(name = "Player ${i + 1}", ink = defaultInks[i % defaultInks.size]) } }
                            .padding(20.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(icon, null, tint = LorcanaGold)
                        Text("  $label", style = MaterialTheme.typography.titleMedium, color = Color.White, modifier = Modifier.weight(1f))
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Color.White.copy(alpha = 0.4f))
                    }
                }
            } else {
                Row(Modifier.fillMaxWidth()) { TextButton(onClick = { setupPlayers = null }) { Text("‹ Back", color = LorcanaGold) } }
                Text("Choose Your Ink", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = Color.White)
                Text("Select a color for each player", color = Color.White.copy(alpha = 0.6f))
                players.forEachIndexed { index, player ->
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(LorcanaDark.copy(alpha = 0.8f)).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        OutlinedTextField(player.name, { v -> setupPlayers = players.toMutableList().also { it[index] = player.copy(name = v) } }, singleLine = true, modifier = Modifier.fillMaxWidth())
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            InkColor.entries.forEach { ink ->
                                Box(
                                    Modifier.size(36.dp).clip(CircleShape).background(ink.color)
                                        .then(if (player.ink == ink) Modifier.border(3.dp, Color.White, CircleShape) else Modifier)
                                        .clickable { setupPlayers = players.toMutableList().also { it[index] = player.copy(ink = ink) } },
                                )
                            }
                        }
                        if (mode == LoreGameMode.COCONUT) {
                            MenuPickerRow("Leader", listOf<String?>(null) + CoconutLeaders.all.map { it.name }, player.leader, { name ->
                                val leader = CoconutLeaders.leader(name)
                                setupPlayers = players.toMutableList().also { it[index] = player.copy(leader = name, ink = leader?.ink ?: player.ink) }
                            }, { it ?: "Choose a Coconut leader" })
                        }
                    }
                }
                LorcanaPrimaryButton(onClick = { gamePlayers = players }, modifier = Modifier.fillMaxWidth()) { Text("Start Game") }
            }
        }
    }

    gamePlayers?.let { players -> LoreGame(players, mode.target, onExit = { gamePlayers = null }) }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun LoreGame(initial: List<PlayerLore>, target: Int, onExit: () -> Unit) {
    val nav = LocalNav.current
    val haptics = LocalHapticFeedback.current
    val players = remember { mutableStateListOf(*initial.toTypedArray()) }
    val history = remember { mutableStateListOf<LoreHistoryEntry>() }
    var menu by remember { mutableStateOf(false) }
    var dialog by remember { mutableStateOf<String?>(null) }
    var customFor by remember { mutableStateOf<Int?>(null) }

    fun set(index: Int, value: Int) {
        val p = players[index]
        val clamped = value.coerceIn(0, 99)
        if (clamped == p.lore) return
        history.add(0, LoreHistoryEntry(p.name, p.lore, clamped))
        players[index] = p.copy(lore = clamped)
        haptics.performHapticFeedback(if (clamped >= target) HapticFeedbackType.LongPress else HapticFeedbackType.TextHandleMove)
    }

    Dialog(onDismissRequest = onExit, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Box(Modifier.fillMaxSize().background(LorcanaDark)) {
            Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                val rows = if (players.size <= 2) players.indices.map { listOf(it) } else players.indices.chunked(2)
                rows.forEachIndexed { rowIndex, row ->
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        row.forEach { index ->
                            // Players across the table read their counter upside down.
                            val flipped = rowIndex == 0 && rows.size > 1
                            PlayerPanel(
                                player = players[index],
                                target = target,
                                modifier = Modifier.weight(1f).fillMaxSize().rotate(if (flipped) 180f else 0f),
                                onMinus = { set(index, players[index].lore - 1) },
                                onPlus = { set(index, players[index].lore + 1) },
                                onLongPress = { customFor = index },
                            )
                        }
                    }
                }
            }
            Box(Modifier.align(Alignment.Center)) {
                IconButton(onClick = { menu = true }, modifier = Modifier.size(48.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.7f))) {
                    Icon(Icons.Filled.MoreVert, contentDescription = "Game menu", tint = LorcanaGold)
                }
                DropdownMenu(menu, { menu = false }) {
                    DropdownMenuItem(text = { Text("Rules Assistant") }, leadingIcon = { Icon(Icons.AutoMirrored.Filled.MenuBook, null) }, onClick = { menu = false; onExit(); nav.navigate(Routes.RULES) })
                    DropdownMenuItem(text = { Text("History") }, leadingIcon = { Icon(Icons.Filled.History, null) }, onClick = { menu = false; dialog = "history" })
                    DropdownMenuItem(text = { Text("Reset All") }, leadingIcon = { Icon(Icons.Filled.RestartAlt, null) }, onClick = { menu = false; dialog = "reset" })
                    DropdownMenuItem(text = { Text("Exit Game") }, leadingIcon = { Icon(Icons.Filled.Close, null) }, onClick = { menu = false; onExit() })
                }
            }
        }
    }

    when (dialog) {
        "reset" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("Reset All?") },
            text = { Text("All lore counters will be set to 0 and history will be cleared.") },
            confirmButton = { TextButton(onClick = { players.indices.forEach { players[it] = players[it].copy(lore = 0) }; history.clear(); dialog = null }) { Text("Reset") } },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text("Cancel") } },
        )
        "history" -> AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text("History") },
            text = {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    if (history.isEmpty()) Text("No history yet")
                    history.forEach { Text("${it.playerName}: ${it.from} → ${it.to}") }
                }
            },
            confirmButton = { TextButton(onClick = { dialog = null }) { Text("Done") } },
            dismissButton = { TextButton(onClick = { history.clear() }) { Text("Clear") } },
        )
    }
    customFor?.let { index ->
        var value by remember(index) { mutableStateOf(players[index].lore.toFloat()) }
        AlertDialog(
            onDismissRequest = { customFor = null },
            title = { Text("Set Lore Value") },
            text = {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${value.toInt()}", fontSize = 48.sp, fontWeight = FontWeight.Bold)
                    Slider(value, { value = it }, valueRange = 0f..target.toFloat() + 5, steps = target + 4)
                }
            },
            confirmButton = { TextButton(onClick = { set(index, value.toInt()); customFor = null }) { Text("Apply") } },
            dismissButton = { TextButton(onClick = { customFor = null }) { Text("Cancel") } },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PlayerPanel(player: PlayerLore, target: Int, modifier: Modifier, onMinus: () -> Unit, onPlus: () -> Unit, onLongPress: () -> Unit) {
    val won = player.lore >= target
    Box(
        modifier.clip(RoundedCornerShape(24.dp))
            .background(Brush.verticalGradient(listOf(player.ink.color.copy(alpha = 0.85f), player.ink.color.copy(alpha = 0.45f))))
            .then(if (won) Modifier.border(4.dp, LorcanaGold, RoundedCornerShape(24.dp)) else Modifier),
    ) {
        Row(Modifier.fillMaxSize()) {
            Box(Modifier.weight(1f).fillMaxSize().combinedClickable(onClick = onMinus, onLongClick = onLongPress), contentAlignment = Alignment.CenterStart) {
                Text("−", fontSize = 40.sp, color = Color.White.copy(alpha = 0.6f), modifier = Modifier.padding(start = 24.dp))
            }
            Box(Modifier.weight(1f).fillMaxSize().combinedClickable(onClick = onPlus, onLongClick = onLongPress), contentAlignment = Alignment.CenterEnd) {
                Text("+", fontSize = 40.sp, color = Color.White.copy(alpha = 0.6f), modifier = Modifier.padding(end = 24.dp))
            }
        }
        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(if (player.leader != null) Icons.Filled.EmojiEvents else Icons.Filled.Person, null, tint = Color.White, modifier = Modifier.size(16.dp))
                Text(" ${player.name}", style = MaterialTheme.typography.titleMedium, color = Color.White, fontWeight = FontWeight.SemiBold)
            }
            Text("${player.lore}", fontSize = 96.sp, fontWeight = FontWeight.Black, color = Color.White)
            if (won) Text("VICTORY", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Black, color = LorcanaGold)
            else Text("${target - player.lore} to win", style = MaterialTheme.typography.labelMedium, color = Color.White.copy(alpha = 0.8f))
            player.leader?.let { Text(it, style = MaterialTheme.typography.labelSmall, color = Color.White.copy(alpha = 0.8f)) }
        }
    }
}

