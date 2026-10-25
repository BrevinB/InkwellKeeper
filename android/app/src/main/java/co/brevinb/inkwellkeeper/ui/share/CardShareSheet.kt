package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.model.color
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.navigation.DeepLinkRouter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import java.io.File

/** "Card flex": a hero image of one card, using the collector's own photo when they have one. */
@Composable
fun CardShareSheet(card: LorcanaCard, ownedQuantity: Int, photoPath: String?, onDismiss: () -> Unit) {
    var useUserPhoto by remember { mutableStateOf(photoPath != null) }
    var price by remember { mutableStateOf<Double?>(null) }
    LaunchedEffect(card.variantAwareId) { price = PricingService.getMarketPrice(card) }
    val includePrices = AppSettings.shareIncludePrices

    ShareCardPresenter(
        title = "Share Card",
        analyticsType = "cardFlex",
        fileName = "InkwellKeeper-${card.name}",
        onDismiss = onDismiss,
        controls = {
            if (photoPath != null) {
                SegmentedPicker(listOf(true, false), useUserPhoto, { useUserPhoto = it }, { if (it) "My Photo" else "Catalog" })
            }
            ToggleRow("Include price", includePrices, { AppSettings.updateShareIncludePrices(it) })
        },
    ) {
        ShareCardChrome(qrPayload = DeepLinkRouter.cardQrPayload(card.id)) {
            Column(Modifier.fillMaxWidth().weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)) {
                Box(Modifier.heightIn(max = 230.dp).shadow(14.dp, RoundedCornerShape(12.dp), ambientColor = card.rarity.color, spotColor = card.rarity.color)) {
                    if (useUserPhoto && photoPath != null) {
                        AsyncImage(File(photoPath), card.name, contentScale = ContentScale.Fit, modifier = Modifier.heightIn(max = 230.dp).clip(RoundedCornerShape(12.dp)))
                    } else {
                        CardImage(card, Modifier.heightIn(max = 230.dp).clip(RoundedCornerShape(12.dp)))
                    }
                    if (ownedQuantity > 1) {
                        Text("×$ownedQuantity", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.Bold, color = Color.White, modifier = Modifier.align(Alignment.TopEnd).padding(8.dp))
                    }
                }
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(card.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = Color.White, textAlign = TextAlign.Center, maxLines = 2)
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Canvas(Modifier.size(8.dp)) { drawCircle(card.rarity.color) }
                        Text(card.rarity.displayName, style = MaterialTheme.typography.labelMedium, color = Color.White)
                        if (card.variant != CardVariant.NORMAL) Text(card.variant.displayName, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LorcanaGold)
                        val p = price
                        if (includePrices && p != null) Text(PricingService.formatPrice(p), style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Bold, color = LorcanaGold)
                    }
                    Text(card.setName, style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                }
                Spacer(Modifier)
            }
        }
    }
}
