package co.brevinb.inkwellkeeper.ui.transfer

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.filled.CheckBox
import androidx.compose.material.icons.filled.CheckBoxOutlineBlank
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Save
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHostState
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.CollectedCard
import co.brevinb.inkwellkeeper.transfer.ExportService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.share.ShareSupport
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlinx.coroutines.launch
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private enum class ExportScope(val label: String) { COLLECTION("My Collection"), WISHLIST("Wishlist"), SETS("Specific Sets") }

/** Export the collection, wishlist, or chosen sets as CSV, text, or a JSON backup. */
@Composable
fun ExportScreen() {
    val app = LocalApp.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    var exportScope by remember { mutableStateOf(ExportScope.COLLECTION) }
    var format by remember { mutableStateOf(ExportService.Format.DREAMBORN) }
    var fields by remember { mutableStateOf(ExportService.Field.entries.filter { it.defaultOn }.toSet()) }
    var sets by remember { mutableStateOf(setOf<String>()) }
    var pendingContent by remember { mutableStateOf("") }

    val collected = app.collection.collectedRows
    val wishlist = remember(app.collection.revision) { app.collection.wishlistCards }
    val rows: List<CollectedCard> = when (exportScope) {
        ExportScope.COLLECTION -> collected
        ExportScope.SETS -> collected.filter { it.setName in sets }
        ExportScope.WISHLIST -> wishlist.map { CollectedCard.from(it, 1, wishlisted = true) }
    }
    val content = remember(rows, format, fields, app.storage.revision) { ExportService.generate(format, rows, fields, app) }
    val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
    val fileName = "ink_well_keeper_export_$stamp.${format.extension}"

    val saver = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument(if (format.extension == "json") "application/json" else "text/csv")) { uri: Uri? ->
        uri ?: return@rememberLauncherForActivityResult
        runCatching { context.contentResolver.openOutputStream(uri)?.use { it.write(pendingContent.toByteArray()) } }
            .onSuccess { scope.launch { snackbar.showSnackbar("Saved") } }
        Analytics.send("export.completed", mapOf("format" to format.extension))
    }

    InkwellScaffold("Export Collection", showBack = true, snackbarHostState = snackbar) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            FormSection("What to Export") {
                SegmentedPicker(ExportScope.entries, exportScope, { exportScope = it }, { it.label })
                Text("${rows.sumOf { it.quantity }} cards", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                if (exportScope == ExportScope.SETS) {
                    collected.map { it.setName }.distinct().sorted().forEach { set ->
                        CheckRow(set, set in sets, "${collected.filter { it.setName == set }.sumOf { it.quantity }} cards") {
                            sets = if (set in sets) sets - set else sets + set
                        }
                    }
                }
            }
            FormSection("Export Format") {
                ExportService.Format.entries.forEach { f ->
                    val selected = f == format
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp)).background(if (selected) LorcanaGold.copy(alpha = 0.2f) else LorcanaDark.copy(alpha = 0.4f))
                            .clickable { format = f }.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(if (selected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = LorcanaGold)
                        Column(Modifier.padding(start = 12.dp)) {
                            Text("${f.label}  .${f.extension}", style = MaterialTheme.typography.bodyMedium, color = Color.White)
                            Text(f.description, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                        }
                    }
                }
            }
            if (format == ExportService.Format.CUSTOM_CSV) {
                FormSection("Export Fields", footer = "${fields.size} selected") {
                    ExportService.Field.entries.forEach { field ->
                        CheckRow(field.label, field in fields) { fields = if (field in fields) fields - field else fields + field }
                    }
                }
            }
            FormSection("Export Preview") {
                Box(Modifier.fillMaxWidth().heightIn(max = 220.dp).clip(RoundedCornerShape(8.dp)).background(Color.Black.copy(alpha = 0.4f))
                    .border(1.dp, Color.White.copy(alpha = 0.1f), RoundedCornerShape(8.dp)).verticalScroll(rememberScrollState()).padding(10.dp)) {
                    Text(content.lines().take(40).joinToString("\n"), fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.labelSmall, color = Color.White)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                LorcanaSecondaryButton(onClick = { pendingContent = content; saver.launch(fileName) }, modifier = Modifier.weight(1f), enabled = rows.isNotEmpty()) {
                    Icon(Icons.Filled.Save, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Save")
                }
                LorcanaPrimaryButton(onClick = {
                    val file = File(File(context.cacheDir, "shared").apply { mkdirs() }, fileName)
                    file.writeText(content)
                    ShareSupport.shareFile(context, file, if (format.extension == "json") "application/json" else "text/csv")
                    Analytics.send("export.completed", mapOf("format" to format.extension))
                }, modifier = Modifier.weight(1f), enabled = rows.isNotEmpty()) {
                    Icon(Icons.Filled.IosShare, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Share")
                }
            }
        }
    }
}

@Composable
private fun CheckRow(label: String, checked: Boolean, detail: String? = null, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(if (checked) Icons.Filled.CheckBox else Icons.Filled.CheckBoxOutlineBlank, null, tint = LorcanaGold, modifier = Modifier.size(22.dp))
        Text("  $label", color = Color.White, modifier = Modifier.weight(1f))
        if (detail != null) Text(detail, style = MaterialTheme.typography.labelSmall, color = Color.Gray)
    }
}
