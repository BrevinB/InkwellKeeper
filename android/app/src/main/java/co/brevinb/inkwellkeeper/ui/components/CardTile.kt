package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Archive
import androidx.compose.material.icons.filled.FilterNone
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** A card in the collection or wishlist grid. */
@Composable
fun CardTile(
    card: LorcanaCard,
    isWishlist: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    reprintCount: Int? = null,
) {
    val app = LocalApp.current
    val collected = if (isWishlist) null else app.collection.collectedRow(card)
    val tileShape = RoundedCornerShape(16.dp)
    Column(
        modifier.shadow(8.dp, tileShape, ambientColor = card.rarity.color.copy(alpha = 0.3f), spotColor = card.rarity.color.copy(alpha = 0.3f))
            .clip(tileShape).background(LorcanaDark.copy(alpha = 0.8f))
            .border(1.dp, LorcanaGold.copy(alpha = 0.3f), tileShape)
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        val imageShape = RoundedCornerShape(12.dp)
        Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
            Box(Modifier.clip(imageShape).border(2.dp, card.rarity.color, imageShape)) {
                CardImage(card)
            }
            Row(Modifier.fillMaxWidth().align(Alignment.TopCenter).padding(6.dp)) {
                if (reprintCount != null && reprintCount > 1) {
                    Row(
                        Modifier.clip(RoundedCornerShape(50)).background(SystemColors.blue.copy(alpha = 0.9f)).padding(horizontal = 5.dp, vertical = 2.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Filled.FilterNone, null, tint = Color.White, modifier = Modifier.size(10.dp))
                        Text(" $reprintCount", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
                Spacer(Modifier.weight(1f))
                if (collected != null && collected.quantity > 1) {
                    Text(
                        "${collected.quantity}",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold.copy(alpha = 0.9f)).padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
            if (collected != null) {
                val stored = app.storage.storedQuantity(card)
                if (stored > 0) {
                    StorageTileBadge(stored, collected.quantity, Modifier.align(Alignment.BottomStart).padding(6.dp))
                }
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(card.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                RarityBadge(card.rarity)
                if (card.variant != CardVariant.NORMAL) VariantBadge(card.variant)
                Spacer(Modifier.weight(1f))
                card.price?.let {
                    Text(PricingService.formatPrice(it), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LorcanaGold, maxLines = 1)
                }
            }
        }
    }
}

/** Gold when every copy is put away; "stored/owned" when only some are. */
@Composable
fun StorageTileBadge(stored: Int, owned: Int, modifier: Modifier = Modifier) {
    val allStored = stored >= owned
    Row(
        modifier.clip(RoundedCornerShape(50))
            .background(if (allStored) LorcanaGold.copy(alpha = 0.95f) else Color.Black.copy(alpha = 0.7f))
            .padding(horizontal = 5.dp, vertical = 3.dp)
            .semantics { contentDescription = if (allStored) "All copies put away" else "$stored of $owned copies put away" },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val tint = if (allStored) LorcanaDark else Color.White
        Icon(Icons.Filled.Archive, null, tint = tint, modifier = Modifier.size(11.dp))
        if (!allStored) Text(" $stored/$owned", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = tint)
    }
}
