package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** Red minus / count / green plus, as in the iOS quantity editors. */
@Composable
fun QuantityStepper(
    value: Int,
    onDecrement: () -> Unit,
    onIncrement: () -> Unit,
    modifier: Modifier = Modifier,
    decrementEnabled: Boolean = value > 0,
    buttonSize: Dp = 32.dp,
    plusColor: Color = SystemColors.green.copy(alpha = 0.8f),
    plusContent: Color = Color.White,
    label: String = "quantity",
) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(
            onClick = onDecrement,
            enabled = decrementEnabled,
            modifier = Modifier.size(buttonSize),
            colors = IconButtonDefaults.iconButtonColors(
                containerColor = SystemColors.red.copy(alpha = 0.8f),
                contentColor = Color.White,
                disabledContainerColor = SystemColors.red.copy(alpha = 0.3f),
                disabledContentColor = Color.White.copy(alpha = 0.5f),
            ),
        ) { Icon(Icons.Filled.Remove, contentDescription = "Decrease $label") }
        Box(Modifier.widthIn(min = 32.dp), contentAlignment = Alignment.Center) {
            Text("$value", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center)
        }
        IconButton(
            onClick = onIncrement,
            modifier = Modifier.size(buttonSize),
            colors = IconButtonDefaults.iconButtonColors(containerColor = plusColor, contentColor = plusContent),
        ) { Icon(Icons.Filled.Add, contentDescription = "Increase $label") }
    }
}
