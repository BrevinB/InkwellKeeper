package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.CardRarity
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

@Composable
fun RarityBadge(rarity: CardRarity, modifier: Modifier = Modifier) {
    Text(
        rarity.displayName,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = Color.White,
        maxLines = 1,
        modifier = modifier.clip(RoundedCornerShape(50)).background(rarity.color.copy(alpha = 0.8f))
            .padding(horizontal = 6.dp, vertical = 2.dp),
    )
}

@Composable
fun VariantBadge(variant: CardVariant, modifier: Modifier = Modifier, short: Boolean = true) {
    Text(
        if (short) variant.shortName else variant.displayName,
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = Color.White,
        modifier = modifier.clip(RoundedCornerShape(4.dp)).background(SystemColors.purple.copy(alpha = 0.8f))
            .padding(horizontal = if (short) 4.dp else 8.dp, vertical = 2.dp),
    )
}
