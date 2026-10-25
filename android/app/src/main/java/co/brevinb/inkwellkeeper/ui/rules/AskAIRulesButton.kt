package co.brevinb.inkwellkeeper.ui.rules

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.model.LorcanaCard
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Opens the AI Rules Assistant pre-seeded with a card. */
@Composable
fun AskAIRulesButton(card: LorcanaCard, source: String, modifier: Modifier = Modifier) {
    val nav = LocalNav.current
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier.fillMaxWidth().clip(shape).background(LorcanaDark.copy(alpha = 0.8f))
            .border(1.5.dp, Brush.linearGradient(listOf(LorcanaGold.copy(alpha = 0.7f), LorcanaGold.copy(alpha = 0.25f))), shape)
            .clickable {
                Analytics.send("rulesAssistant.opened", mapOf("source" to source))
                RulesAssistantSeed.card = card
                nav.navigate(co.brevinb.inkwellkeeper.ui.navigation.Routes.RULES)
            }
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Ask About This Card", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Bold, color = Color.White)
                if (!AppSettings.isProUnlocked) ProPill()
            }
            Text("Instant AI answers — rulings, interactions, strategy", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = LorcanaGold.copy(alpha = 0.6f), modifier = Modifier.size(18.dp))
    }
}

/** Small badge marking a Pro-gated feature. */
@Composable
fun ProPill() {
    Text(
        "PRO",
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = Color.Black,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 6.dp, vertical = 1.dp),
    )
}

/** Hands a card to the Rules Assistant screen when opened from a card surface. */
object RulesAssistantSeed {
    var card: LorcanaCard? = null
    /** A question to prefill (e.g. from the keyword glossary). */
    var question: String? = null
}
