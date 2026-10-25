package co.brevinb.inkwellkeeper.ui.transfer

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.ContentPaste
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Link
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.transfer.ImportService
import co.brevinb.inkwellkeeper.transfer.InkwellBackup
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors
import kotlinx.coroutines.launch

private enum class ImportMethod { FILE, PASTE, OFFICIAL }

/** Bulk import from a file, pasted text, or an official Lorcana app backup link. */
@Composable
fun ImportScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var method by remember { mutableStateOf<ImportMethod?>(null) }
    var text by remember { mutableStateOf("") }
    var fileName by remember { mutableStateOf<String?>(null) }
    var link by remember { mutableStateOf("") }
    var format by remember { mutableStateOf(ImportService.Format.DREAMBORN) }
    var importing by remember { mutableStateOf(false) }
    var progress by remember { mutableStateOf(ImportService.Progress()) }
    var result by remember { mutableStateOf<ImportService.Result?>(null) }
    var storageNote by remember { mutableStateOf<String?>(null) }
    var error by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching { context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } }.getOrNull()?.let {
            text = it
            fileName = uri.lastPathSegment?.substringAfterLast('/')
            format = ImportService.detectFormat(it)
            result = null
        } ?: run { error = "Couldn't read that file." }
    }

    fun runImport(content: String) {
        importing = true
        result = null
        error = null
        storageNote = null
        scope.launch {
            val r = ImportService.importAndAdd(context, content, format, onCardMatched = { card, qty ->
                app.collection.addCard(card, qty, bulkImport = true, source = "import")
            }, onProgress = { progress = it })
            app.collection.finalizeBulkImport()
            if (format == ImportService.Format.INKWELL_BACKUP) {
                InkwellBackup.decode(content)?.storage?.takeIf { it.isNotEmpty() }?.let { saved ->
                    val summary = app.storage.restore(saved.map { it.toContainer() }) { id -> app.decks.deck(id) != null }
                    if (summary.containers > 0) storageNote = "Restored ${summary.containers} binders and boxes with ${summary.cards} cards in place."
                }
            }
            app.storage.reconcileAll()
            Analytics.send("import.completed", mapOf("format" to format.name, "cards" to "${r.totalCardsCount}"))
            result = r
            importing = false
        }
    }

    InkwellScaffold("Bulk Import", showBack = true) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.Download, null, tint = LorcanaGold, modifier = Modifier.size(56.dp))
                Text("Import Your Collection", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White)
                Text(
                    "Bring cards in from Dreamborn.ink, Collectr, Lorcana.gg, a text list, the official Disney Lorcana app, or an Inkwell Keeper backup from iPhone or Android.",
                    style = MaterialTheme.typography.bodyMedium, color = Color.Gray, textAlign = TextAlign.Center,
                )
            }
            MethodButton(Icons.Filled.FolderOpen, "Choose a File", "CSV, TXT or JSON export", method == ImportMethod.FILE) {
                method = ImportMethod.FILE
                picker.launch(arrayOf("text/*", "application/json", "application/octet-stream", "*/*"))
            }
            MethodButton(Icons.Filled.ContentPaste, "Paste Text", "One card per line, or a whole CSV", method == ImportMethod.PASTE) { method = ImportMethod.PASTE }
            MethodButton(Icons.Filled.Link, "Official Lorcana App", "Paste a backup link from Collection backup → Backup now", method == ImportMethod.OFFICIAL) {
                method = ImportMethod.OFFICIAL
                format = ImportService.Format.OFFICIAL_BACKUP
            }

            when (method) {
                ImportMethod.FILE -> if (fileName != null) {
                    FormSection("Selected File") {
                        Text(fileName ?: "", color = Color.White)
                        Text("${text.lines().size} lines", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                }
                ImportMethod.PASTE -> OutlinedTextField(
                    text, { text = it; format = ImportService.detectFormat(it) },
                    placeholder = { Text("4 Elsa - Snow Queen\n2x Mickey Mouse - True Friend (Foil)") },
                    textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                    modifier = Modifier.fillMaxWidth().heightIn(min = 160.dp),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LorcanaGold, cursorColor = LorcanaGold),
                )
                ImportMethod.OFFICIAL -> OutlinedTextField(
                    link, { link = it }, singleLine = true,
                    placeholder = { Text("https://…ravensburger.com/…") },
                    modifier = Modifier.fillMaxWidth(),
                    colors = OutlinedTextFieldDefaults.colors(focusedBorderColor = LorcanaGold, cursorColor = LorcanaGold),
                )
                null -> {}
            }

            if (method == ImportMethod.FILE || method == ImportMethod.PASTE) {
                if (text.isNotBlank()) {
                    FormSection("Format", footer = "Detected automatically — change it if the import looks wrong.") {
                        MenuPickerRow("Format", ImportService.Format.entries, format, { format = it }, { it.description })
                    }
                }
            }

            if (method != null) {
                val ready = when (method) {
                    ImportMethod.OFFICIAL -> link.isNotBlank()
                    else -> text.isNotBlank()
                }
                LorcanaPrimaryButton(
                    onClick = {
                        if (method == ImportMethod.OFFICIAL) {
                            scope.launch {
                                runCatching { ImportService.fetchOfficialBackup(link) }
                                    .onSuccess { runImport(it) }
                                    .onFailure { error = it.message }
                            }
                        } else {
                            runImport(text)
                        }
                    },
                    enabled = ready && !importing,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text(if (importing) "Importing…" else "Import Cards") }
            }

            if (importing) {
                FormSection("Importing") {
                    LinearProgressIndicator(progress = { progress.progress.toFloat() }, color = LorcanaGold, modifier = Modifier.fillMaxWidth())
                    Text("${progress.totalCards} cards (${progress.normalCards} normal, ${progress.foilCards} foil) · ${progress.failedCards} not found", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
            }

            error?.let {
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(SystemColors.red.copy(alpha = 0.15f)).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Error, null, tint = SystemColors.red)
                    Text("  $it", color = Color.White, style = MaterialTheme.typography.bodySmall)
                }
            }

            result?.let { r ->
                FormSection("Import Complete") {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, null, tint = SystemColors.green)
                        Text("  Imported ${r.totalCardsCount} cards (${r.uniqueCardsCount} unique)", color = Color.White, style = MaterialTheme.typography.titleSmall)
                    }
                    storageNote?.let { Text(it, style = MaterialTheme.typography.labelMedium, color = LorcanaGold) }
                    if (r.failed.isNotEmpty()) {
                        Text("${r.failed.size} lines couldn't be matched:", style = MaterialTheme.typography.labelMedium, color = SystemColors.orange)
                        r.failed.take(30).forEach { Text("• ${it.reason}", style = MaterialTheme.typography.labelSmall, color = Color.Gray) }
                        if (r.failed.size > 30) Text("…and ${r.failed.size - 30} more", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                    }
                    LorcanaPrimaryButton(onClick = { nav.popBackStack() }, modifier = Modifier.fillMaxWidth()) { Text("Done") }
                }
            }

            FormSection("How to export from Dreamborn") {
                Text("1. On dreamborn.ink, open your collection\n2. Choose Export → CSV\n3. Save the file, then pick it here", style = MaterialTheme.typography.bodySmall, color = Color.Gray)
            }
        }
    }
}

@Composable
private fun MethodButton(icon: ImageVector, title: String, subtitle: String, selected: Boolean, onClick: () -> Unit) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        Modifier.fillMaxWidth().clip(shape).background(if (selected) LorcanaGold.copy(alpha = 0.15f) else LorcanaDark.copy(alpha = 0.8f))
            .border(1.dp, if (selected) LorcanaGold else LorcanaGold.copy(alpha = 0.25f), shape).clickable(onClick = onClick).padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, null, tint = LorcanaGold, modifier = Modifier.size(28.dp))
        Spacer(Modifier.width(14.dp))
        Column {
            Text(title, style = MaterialTheme.typography.titleSmall, color = Color.White)
            Text(subtitle, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        }
    }
}
