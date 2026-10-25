package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/**
 * The Android stand-in for an iOS page sheet with a navigation bar: full screen, a leading
 * dismiss button, an optional trailing confirm button, and the Lorcana background.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FullScreenSheet(
    title: String,
    onDismiss: () -> Unit,
    dismissLabel: String = "Cancel",
    confirmLabel: String? = null,
    confirmEnabled: Boolean = true,
    onConfirm: () -> Unit = {},
    leadingAction: (@Composable () -> Unit)? = null,
    trailingActions: (@Composable () -> Unit)? = null,
    snackbarHostState: SnackbarHostState = remember { SnackbarHostState() },
    content: @Composable (PaddingValues) -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        LorcanaBackground(Modifier.fillMaxSize()) {
            Scaffold(
                modifier = Modifier.systemBarsPadding().imePadding(),
                containerColor = Color.Transparent,
                contentWindowInsets = WindowInsets(0),
                snackbarHost = { SnackbarHost(snackbarHostState) },
                topBar = {
                    TopAppBar(
                        title = { Text(title, style = MaterialTheme.typography.titleMedium, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                        navigationIcon = {
                            leadingAction?.invoke() ?: TextButton(onClick = onDismiss) { Text(dismissLabel, color = LorcanaGold) }
                        },
                        actions = {
                            trailingActions?.invoke()
                            if (confirmLabel != null) {
                                TextButton(onClick = onConfirm, enabled = confirmEnabled) {
                                    Text(confirmLabel, color = if (confirmEnabled) LorcanaGold else Color.Gray, fontWeight = FontWeight.Bold)
                                }
                            }
                        },
                        colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.Transparent, titleContentColor = Color.White),
                    )
                },
                content = content,
            )
        }
    }
}

/** Groups form rows like an iOS inset-grouped `Section`. */
@Composable
fun FormSection(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (header != null) {
            Text(header.uppercase(), style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.padding(start = 16.dp))
        }
        SectionCard(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 12.dp), cornerRadius = 12.dp, background = FormRowBackground) {
            content()
        }
        if (footer != null) {
            Text(footer, style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.padding(horizontal = 16.dp))
        }
    }
}

val FormRowBackground = Color(0xFF1C1C26)
