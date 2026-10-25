package co.brevinb.inkwellkeeper.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val InkwellColors = darkColorScheme(
    primary = LorcanaGold,
    onPrimary = Color.Black,
    secondary = LorcanaPurple,
    onSecondary = Color.White,
    tertiary = LorcanaBlue,
    background = LorcanaDark,
    onBackground = Color.White,
    surface = Color(0xFF1C1B26),
    onSurface = Color.White,
    surfaceVariant = Color(0xFF26243A),
    onSurfaceVariant = Color(0xFFB8B6C8),
    surfaceContainer = Color(0xFF1C1B26),
    surfaceContainerHigh = Color(0xFF242233),
    surfaceContainerHighest = Color(0xFF2C2A3D),
    surfaceContainerLow = Color(0xFF17161F),
    outline = Color(0xFF4A4860),
    error = SystemColors.red,
)

/** The iOS app is dark-only (`preferredColorScheme(.dark)`), so Android is too. */
@Composable
fun InkwellTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = InkwellColors, content = content)
}
