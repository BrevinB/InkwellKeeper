package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.decks.DeckListTextCodec
import co.brevinb.inkwellkeeper.decks.DeckManager
import co.brevinb.inkwellkeeper.model.CoconutLeaders
import co.brevinb.inkwellkeeper.model.DeckArchetype
import co.brevinb.inkwellkeeper.model.DeckFormat
import co.brevinb.inkwellkeeper.model.InkColor
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FormTextField
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.share.ShareSupport
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

private val sheetFieldColors
    @Composable get() = OutlinedTextFieldDefaults.colors(
        focusedBorderColor = LorcanaGold,
        unfocusedBorderColor = LorcanaGold.copy(alpha = 0.3f),
        cursorColor = LorcanaGold,
        focusedContainerColor = LorcanaDark.copy(alpha = 0.8f),
        unfocusedContainerColor = LorcanaDark.copy(alpha = 0.8f),
    )

/** Picks inks first; the workspace browser then filters to them. */
@Composable
fun NewDeckSheet(onDismiss: () -> Unit, onCreated: (Deck) -> Unit) {
    val app = LocalApp.current
    var name by remember { mutableStateOf("") }
    var format by remember { mutableStateOf(DeckFormat.CASUAL) }
    var colors by remember { mutableStateOf(setOf<InkColor>()) }
    var leader by remember { mutableStateOf<String?>(null) }

    FullScreenSheet(
        title = "New Deck",
        onDismiss = onDismiss,
        confirmLabel = "Start Building",
        onConfirm = {
            val deck = app.decks.createDeck(
                name = name.trim().ifEmpty { "New Deck" },
                format = format,
                inkColors = colors.sortedBy { it.rawValue },
                coconutLeader = if (format == DeckFormat.COCONUT) leader else null,
            )
            onDismiss()
            onCreated(deck)
        },
    ) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("DECK NAME", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                OutlinedTextField(name, { name = it }, placeholder = { Text("New Deck") }, singleLine = true, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp), colors = sheetFieldColors)
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("FORMAT", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                SegmentedPicker(DeckFormat.creatable, format, { newFormat ->
                    format = newFormat
                    colors = colors.take(newFormat.maxInkColors).toSet()
                }, { it.shortName })
                if (format == DeckFormat.COCONUT) Text(DeckFormat.COCONUT.description, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
            if (format == DeckFormat.COCONUT) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("LEADER", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                    CoconutLeaderPicker(leader) { picked ->
                        leader = picked
                        CoconutLeaders.leader(picked)?.let { l ->
                            if (l.ink !in colors) colors = (if (colors.size >= format.maxInkColors) colors.drop(1).toSet() else colors) + l.ink
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row {
                    Text("INK COLORS", style = MaterialTheme.typography.labelMedium, color = LorcanaGold, modifier = Modifier.weight(1f))
                    Text("${colors.size}/${format.maxInkColors}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                }
                Text("The card browser will filter to just these colors.", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                InkColor.entries.chunked(2).forEach { pair ->
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        pair.forEach { ink ->
                            InkToggle(ink, ink in colors, enabled = ink in colors || colors.size < format.maxInkColors, Modifier.weight(1f)) {
                                colors = if (ink in colors) colors - ink else colors + ink
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun InkToggle(ink: InkColor, selected: Boolean, enabled: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier.clip(shape).background(if (selected) ink.color.copy(alpha = 0.25f) else LorcanaDark.copy(alpha = 0.6f))
            .border(2.dp, if (selected) ink.color else Color.Transparent, shape)
            .clickable(enabled = enabled, onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Box(Modifier.size(24.dp).clip(CircleShape).background(if (enabled) ink.color else ink.color.copy(alpha = 0.4f)))
        Text(ink.rawValue, color = if (enabled) Color.White else Color.Gray, modifier = Modifier.weight(1f))
        if (selected) Icon(Icons.Filled.CheckCircle, null, tint = LorcanaGold)
    }
}

/** The 18 Format [Coconut] beta leaders, by ink. */
@Composable
fun CoconutLeaderPicker(selection: String?, onSelect: (String) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        InkColor.entries.forEach { ink ->
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(12.dp).clip(CircleShape).background(ink.color))
                CoconutLeaders.leaders(ink).forEach { leader ->
                    val selected = leader.name == selection
                    Text(
                        leader.name.substringBefore(" – "),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (selected) Color.Black else Color.White,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(if (selected) LorcanaGold else ink.color.copy(alpha = 0.25f))
                            .clickable { onSelect(leader.name) }.padding(horizontal = 12.dp, vertical = 6.dp),
                    )
                }
            }
        }
        CoconutLeaders.leader(selection)?.let { leader ->
            Column(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaGold.copy(alpha = 0.1f)).padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.EmojiEvents, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                    Text(" ${leader.name}", style = MaterialTheme.typography.titleSmall, color = LorcanaGold)
                }
                Text(leader.abilityText, style = MaterialTheme.typography.bodySmall, color = Color.White)
                Text("4 copies allowed: ${leader.fourOfCardNames.joinToString()}", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
        }
    }
}

@Composable
fun EditDeckSheet(deck: Deck, onDismiss: () -> Unit) {
    val app = LocalApp.current
    var name by remember { mutableStateOf(deck.name) }
    var description by remember { mutableStateOf(deck.deckDescription) }
    var format by remember { mutableStateOf(deck.deckFormat) }
    var colors by remember { mutableStateOf(deck.deckInkColors.toSet()) }
    var archetype by remember { mutableStateOf(deck.deckArchetype) }
    var leader by remember { mutableStateOf(deck.coconutLeader) }
    val canSave = name.isNotEmpty() && colors.size <= format.maxInkColors

    FullScreenSheet(
        title = "Edit Deck",
        onDismiss = onDismiss,
        confirmLabel = "Save",
        confirmEnabled = canSave,
        onConfirm = {
            deck.name = name
            deck.deckDescription = description
            deck.deckFormat = format
            deck.deckInkColors = colors.toList()
            deck.deckArchetype = archetype
            deck.coconutLeader = if (format == DeckFormat.COCONUT) leader else null
            app.decks.updateDeck(deck)
            onDismiss()
        },
    ) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            FormSection("Basic Info") {
                FormTextField(name, { name = it }, "Deck Name")
                FormTextField(description, { description = it }, "Description (optional)")
            }
            FormSection("Format", footer = "Min ${format.minimumCards} cards, max ${format.maxInkColors} ink colors") {
                MenuPickerRow("Format", DeckFormat.entries, format, { f ->
                    format = f
                    colors = colors.take(f.maxInkColors).toSet()
                }, { it.rawValue })
                Text(format.description, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
            if (format == DeckFormat.COCONUT) {
                FormSection("Coconut Leader", footer = "Singleton deck — only your leader's associated cards may run 4 copies, and one deck ink must match your leader.") {
                    CoconutLeaderPicker(leader) { picked ->
                        leader = picked
                        CoconutLeaders.leader(picked)?.let { l ->
                            if (l.ink !in colors) colors = (if (colors.size >= format.maxInkColors) colors.drop(1).toSet() else colors) + l.ink
                        }
                    }
                }
            }
            FormSection("Ink Colors (max ${format.maxInkColors})", footer = "Optional — auto-detected from the cards you add.") {
                InkColor.entries.forEach { ink ->
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            colors = if (ink in colors) colors - ink else if (colors.size < format.maxInkColors) colors + ink else colors
                        }.padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.size(20.dp).clip(CircleShape).background(ink.color))
                        Text("  ${ink.rawValue}", color = Color.White, modifier = Modifier.weight(1f))
                        if (ink in colors) Icon(Icons.Filled.Check, null, tint = LorcanaGold)
                    }
                }
            }
            FormSection("Archetype (optional)") {
                MenuPickerRow("Archetype", listOf<DeckArchetype?>(null) + DeckArchetype.entries, archetype, { archetype = it }, { it?.rawValue ?: "None" })
            }
        }
    }
}

/** Standard (community `4 Name`) or Detailed text export with copy. */
@Composable
fun ExportDeckSheet(standardText: String, detailedText: String, onDismiss: () -> Unit) {
    val clipboard = LocalClipboardManager.current
    var detailed by remember { mutableStateOf(false) }
    var copied by remember { mutableStateOf(false) }
    val text = if (detailed) detailedText else standardText
    FullScreenSheet(title = "Export Deck", onDismiss = onDismiss, dismissLabel = "Done") { padding ->
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            SegmentedPicker(listOf(false, true), detailed, { detailed = it; copied = false }, { if (it) "Detailed" else "Standard" })
            if (!detailed) Text("Pastes directly into Dreamborn, inkdecks, and other deck sites.", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            Box(Modifier.weight(1f).fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).verticalScroll(rememberScrollState()).padding(16.dp)) {
                Text(text, fontFamily = FontFamily.Monospace, color = Color.White, style = MaterialTheme.typography.bodyMedium)
            }
            LorcanaPrimaryButton(onClick = { clipboard.setText(AnnotatedString(text)); copied = true }, modifier = Modifier.fillMaxWidth()) {
                Icon(if (copied) Icons.Filled.Check else Icons.Filled.ContentCopy, null)
                Spacer(Modifier.width(8.dp))
                Text(if (copied) "Copied!" else "Copy to Clipboard")
            }
        }
    }
}

/** Share link (hero), copy link, image, or text list. */
@Composable
fun DeckShareSheet(deck: Deck, onShareImage: () -> Unit, onDismiss: () -> Unit) {
    val app = LocalApp.current
    val context = LocalContext.current
    val code = remember(deck.id, app.decks.revision) { app.decks.generateShareCode(deck) }
    val link = DeepLinkRouter.deckShareLink(code)
    val listText = app.decks.exportCommunityDeckList(deck)
    var copiedLink by remember { mutableStateOf(false) }
    var copiedList by remember { mutableStateOf(false) }
    FullScreenSheet(title = "Share Deck", onDismiss = onDismiss, dismissLabel = "Done") { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Send, null, tint = LorcanaGold, modifier = Modifier.size(48.dp))
                Text("Share \"${deck.name}\"", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
                Text(
                    "Anyone can open this link — it launches Ink Well Keeper if they have it, or shows the deck right in their browser.",
                    style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center,
                )
            }
            LorcanaPrimaryButton(onClick = { ShareSupport.shareText(context, link, deck.name) }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.Link, null)
                Spacer(Modifier.width(8.dp))
                Text("Share Link")
            }
            LorcanaSecondaryButton(onClick = { ShareSupport.copyToClipboard(context, link); copiedLink = true }, modifier = Modifier.fillMaxWidth()) {
                Icon(if (copiedLink) Icons.Filled.Check else Icons.Filled.ContentCopy, null)
                Spacer(Modifier.width(8.dp))
                Text(if (copiedLink) "Link Copied!" else "Copy Link")
            }
            Text("MORE WAYS TO SHARE", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
            ShareOptionRow(Icons.Filled.Image, "Share as Image", "A picture of the deck for social media, with a QR code") { onShareImage() }
            ShareOptionRow(if (copiedList) Icons.Filled.Check else Icons.AutoMirrored.Filled.List, if (copiedList) "Deck List Copied!" else "Copy Deck List", "Plain text for Dreamborn, inkdecks, or Discord") {
                ShareSupport.copyToClipboard(context, listText)
                copiedList = true
            }
        }
    }
}

@Composable
private fun ShareOptionRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, subtitle: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.8f)).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = LorcanaGold)
        Column {
            Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.White)
            Text(subtitle, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        }
    }
}

/** Paste a deck link, `IWK2:` code, or a text list from Dreamborn and friends. */
@Composable
fun ImportDeckSheet(onDismiss: () -> Unit, onImported: (Deck) -> Unit) {
    val app = LocalApp.current
    val clipboard = LocalClipboardManager.current
    var pasted by remember { mutableStateOf("") }
    var name by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var success by remember { mutableStateOf<Pair<Deck, String>?>(null) }
    val isShareCode = DeckManager.extractShareCode(pasted) != null
    val clip = clipboard.getText()?.text

    FullScreenSheet(title = "Import Deck", onDismiss = onDismiss) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Download, null, tint = LorcanaGold, modifier = Modifier.size(48.dp))
                Text("Import a Deck", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
                Text(
                    "Paste a deck link or share code from Ink Well Keeper, or a text deck list from Dreamborn or anywhere else — one card per line, like \"4 Elsa - Snow Queen\".",
                    style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center,
                )
            }
            Text("Deck Link, Code, or Card List", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            OutlinedTextField(
                pasted, { pasted = it },
                textStyle = MaterialTheme.typography.labelSmall.copy(fontFamily = FontFamily.Monospace),
                modifier = Modifier.fillMaxWidth().heightIn(min = 140.dp),
                shape = RoundedCornerShape(12.dp),
                colors = sheetFieldColors,
            )
            if (pasted.isNotEmpty() && !isShareCode) {
                Text("Deck Name", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                OutlinedTextField(name, { name = it }, placeholder = { Text("Imported Deck") }, singleLine = true, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(12.dp), colors = sheetFieldColors)
            }
            if (pasted.isEmpty() && clip != null && (DeckManager.extractShareCode(clip) != null || DeckListTextCodec.looksLikeDeckList(clip))) {
                TextButton(onClick = { pasted = clip }) {
                    Icon(Icons.Filled.ContentPaste, null, tint = LorcanaGold)
                    Text(" Paste from Clipboard", color = LorcanaGold)
                }
            }
            LorcanaPrimaryButton(
                onClick = {
                    if (isShareCode) {
                        val deck = app.decks.importDeck(pasted)
                        if (deck != null) success = deck to "" else error = "The deck link or code is invalid. Make sure you copied the whole thing — codes start with \"IWK2:\" or \"IWK:\"."
                    } else {
                        val result = app.decks.importDeck(fromText = pasted, name = name.trim().ifEmpty { "Imported Deck" })
                        if (result == null) {
                            error = "No cards were recognized. Each line should look like \"4 Elsa - Snow Queen\"."
                        } else {
                            val shown = result.unmatched.take(6).joinToString("\n") { "• ${it.text}" }
                            val more = result.unmatched.size - 6
                            success = result.deck to (shown + if (more > 0) "\n…and $more more" else "")
                        }
                    }
                },
                enabled = pasted.isNotEmpty(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Import Deck") }
        }
    }
    error?.let {
        AlertDialog(onDismissRequest = { error = null }, title = { Text("Import Failed") }, text = { Text(it) }, confirmButton = { TextButton(onClick = { error = null }) { Text("OK") } })
    }
    success?.let { (deck, unmatched) ->
        AlertDialog(
            onDismissRequest = {},
            title = { Text("Deck Imported!") },
            text = { Text("\"${deck.name}\" has been added to your decks." + if (unmatched.isNotEmpty()) "\n\nCouldn't find:\n$unmatched" else "") },
            confirmButton = { TextButton(onClick = { success = null; onDismiss(); onImported(deck) }) { Text("OK") } },
        )
    }
}
