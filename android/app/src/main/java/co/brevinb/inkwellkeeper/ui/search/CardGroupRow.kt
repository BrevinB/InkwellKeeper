package co.brevinb.inkwellkeeper.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.FilterNone
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.data.SpoilerSettings
import co.brevinb.inkwellkeeper.model.CardGroup
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.RarityBadge
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** A search result row: art, name, rarity, set, reprint count, optional wishlist star. */
@Composable
fun CardGroupRow(group: CardGroup, onTap: () -> Unit, onWishlist: (() -> Unit)? = null) {
    val card = group.primaryCard
    if (SpoilerSettings.isHidden(card)) {
        SpoilerPlaceholderRow(card)
        return
    }
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onTap).background(LorcanaDark.copy(alpha = 0.6f)).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        CardImage(card, Modifier.size(60.dp, 84.dp).clip(RoundedCornerShape(8.dp)).border(1.dp, card.rarity.color, RoundedCornerShape(8.dp)))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(group.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 2, overflow = TextOverflow.Ellipsis)
            RarityBadge(card.rarity)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(card.setName, style = MaterialTheme.typography.labelMedium, color = Color.Gray, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (group.isReprint) {
                    Row(
                        Modifier.clip(RoundedCornerShape(50)).background(SystemColors.blue.copy(alpha = 0.8f)).padding(horizontal = 5.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Filled.FilterNone, null, tint = Color.White, modifier = Modifier.size(10.dp))
                        Text(" ${group.cards.size} sets", style = MaterialTheme.typography.labelSmall, color = Color.White)
                    }
                }
            }
        }
        if (onWishlist != null) {
            IconButton(onClick = onWishlist) { Icon(Icons.Filled.Star, contentDescription = "Add to wishlist", tint = SystemColors.yellow) }
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = LorcanaGold.copy(alpha = 0.6f))
    }
}

/** Stand-in for a result from an upcoming set: just the set and release date. Tap to reveal. */
@Composable
fun SpoilerPlaceholderRow(card: LorcanaCard) {
    val release = SetsDataManager.getSet(card.setName)?.releaseDateFormatted
    Row(
        Modifier.fillMaxWidth().clickable { SpoilerSettings.reveal(card) }.background(LorcanaDark.copy(alpha = 0.6f)).padding(horizontal = 16.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(60.dp, 84.dp).clip(RoundedCornerShape(6.dp)).background(LorcanaDark).border(1.dp, LorcanaGold.copy(alpha = 0.4f), RoundedCornerShape(6.dp)),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.Filled.VisibilityOff, null, tint = LorcanaGold) }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("Spoiler from ${card.setName}", style = MaterialTheme.typography.titleSmall, color = Color.White, maxLines = 2)
            if (release != null) Text("Releases $release", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            Text("Tap to reveal", style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LorcanaGold)
        }
    }
}
