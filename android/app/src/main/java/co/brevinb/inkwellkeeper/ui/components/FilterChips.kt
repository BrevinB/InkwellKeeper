package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Gold capsule chip: filled when selected, outlined otherwise. */
@Composable
fun GoldChip(title: String, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val shape = RoundedCornerShape(50)
    Text(
        title,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Medium,
        color = if (selected) Color.Black else LorcanaGold,
        modifier = modifier.clip(shape).background(if (selected) LorcanaGold else Color.Transparent)
            .border(1.dp, LorcanaGold, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp),
    )
}

/** Icon chip tinted with its own color when selected (ink and variant filters). */
@Composable
fun TintedChip(
    icon: ImageVector,
    label: String?,
    color: Color,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    contentDescription: String? = label,
) {
    val shape = RoundedCornerShape(16.dp)
    val tint = if (selected) color else Color.Gray
    Row(
        modifier.clip(shape)
            .background(if (selected) color.copy(alpha = 0.3f) else LorcanaDark.copy(alpha = 0.6f))
            .border(2.dp, if (selected) color else Color.Transparent, shape)
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(icon, contentDescription = if (label == null) contentDescription else null, tint = tint, modifier = Modifier.size(14.dp))
        if (label != null) Text(label, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Medium, color = tint)
    }
}
