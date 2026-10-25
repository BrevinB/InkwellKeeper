package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.ui.components.LorcanaBackground
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

object ShareCardLayout {
    /** 4:5 social canvas; rendered at 3x this yields 1080×1350px. */
    val width = 360.dp
    val height = 450.dp
    val cornerRadius = 28.dp
    val contentPadding = 20.dp
}

/** The branded frame every share image uses: background, gold edge, wordmark and QR footer. */
@Composable
fun ShareCardChrome(
    qrPayload: String,
    tagline: String = "Track your Lorcana collection",
    height: Dp? = ShareCardLayout.height,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(ShareCardLayout.cornerRadius)
    Box(
        Modifier.width(ShareCardLayout.width)
            .then(if (height != null) Modifier.height(height) else Modifier.heightIn(min = ShareCardLayout.height))
            .clip(shape)
            .border(1.5.dp, LorcanaGold.copy(alpha = 0.55f), shape),
    ) {
        LorcanaBackground(Modifier.matchParentSize())
        Column(Modifier.padding(ShareCardLayout.contentPadding), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.fillMaxWidth().then(if (height != null) Modifier.weight(1f) else Modifier), content = content)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.AutoAwesome, null, tint = LorcanaGold, modifier = Modifier.size(16.dp))
                        Text(" Ink Well Keeper", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, color = LorcanaGold)
                    }
                    Text(tagline, style = MaterialTheme.typography.labelSmall, color = LorcanaGold)
                }
                Spacer(Modifier.weight(1f))
                Box(Modifier.clip(RoundedCornerShape(8.dp)).background(Color.White.copy(alpha = 0.06f)).padding(4.dp)) {
                    QrCode(qrPayload, Modifier.size(52.dp))
                }
            }
        }
    }
}
