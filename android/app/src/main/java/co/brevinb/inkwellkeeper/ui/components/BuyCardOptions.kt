package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.pricing.AffiliateLinks
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** "Check Prices" links to TCGPlayer, Cardmarket, and eBay. */
@Composable
fun BuyCardOptions(card: LorcanaCard, modifier: Modifier = Modifier) {
    val uriHandler = LocalUriHandler.current
    Column(modifier, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Check Prices", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
        AffiliateLinks.buyOptions(card).forEach { option ->
            val shape = RoundedCornerShape(10.dp)
            Row(
                Modifier.fillMaxWidth().clip(shape).background(LorcanaDark.copy(alpha = 0.6f))
                    .border(1.dp, LorcanaGold.copy(alpha = 0.3f), shape)
                    .clickable {
                        Analytics.send("affiliate.click", mapOf("platform" to option.platform))
                        uriHandler.openUri(option.url)
                    }
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(option.platform, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.White)
                    Text("View Prices →", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                }
                Spacer(Modifier.padding(4.dp))
                Icon(Icons.AutoMirrored.Filled.OpenInNew, contentDescription = "Open ${option.platform}", tint = LorcanaGold)
            }
        }
    }
}
