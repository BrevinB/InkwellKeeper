package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.material3.LocalTextStyle
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** Gold filled button (the iOS `LorcanaButtonStyle(.primary)`). */
@Composable
fun LorcanaPrimaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(containerColor = LorcanaGold, contentColor = Color.Black),
        contentPadding = PaddingValues(16.dp),
    ) {
        CompositionLocalProvider(LocalTextStyle provides MaterialTheme.typography.titleMedium) { content() }
    }
}

/** Gold outline button (the iOS `LorcanaButtonStyle(.secondary)`). */
@Composable
fun LorcanaSecondaryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    contentPadding: PaddingValues = PaddingValues(16.dp),
    content: @Composable RowScope.() -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(2.dp, LorcanaGold),
        colors = ButtonDefaults.outlinedButtonColors(contentColor = LorcanaGold),
        contentPadding = contentPadding,
    ) {
        CompositionLocalProvider(LocalTextStyle provides MaterialTheme.typography.titleMedium) { content() }
    }
}

/** Grey "bordered" button with a tinted label (the iOS `.bordered` style). */
@Composable
fun BorderedButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tint: Color = SystemColors.red,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.12f), contentColor = tint),
        content = content,
    )
}
