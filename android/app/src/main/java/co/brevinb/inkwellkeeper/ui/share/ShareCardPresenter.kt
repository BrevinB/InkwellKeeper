package co.brevinb.inkwellkeeper.ui.share

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.Icon
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.layer.drawLayer
import androidx.compose.ui.graphics.rememberGraphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import kotlinx.coroutines.launch

/**
 * Previews a branded share card and shares it as an image. The preview itself is what gets
 * captured (the iOS app renders the same SwiftUI view with ImageRenderer).
 */
@Composable
fun ShareCardPresenter(
    title: String,
    analyticsType: String,
    fileName: String,
    onDismiss: () -> Unit,
    shareText: String? = null,
    controls: @Composable ColumnScope.() -> Unit = {},
    card: @Composable () -> Unit,
) {
    val context = LocalContext.current
    val layer = rememberGraphicsLayer()
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }

    FullScreenSheet(title = title, onDismiss = onDismiss, dismissLabel = "Done", snackbarHostState = snackbar) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Box(
                Modifier.drawWithContent {
                    layer.record { this@drawWithContent.drawContent() }
                    drawLayer(layer)
                },
            ) { card() }
            controls()
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                LorcanaSecondaryButton(
                    onClick = {
                        scope.launch {
                            val bitmap = layer.toImageBitmap().asAndroidBitmap()
                            val saved = ShareSupport.saveToGallery(context, bitmap, fileName)
                            snackbar.showSnackbar(if (saved) "Saved to Photos" else "Couldn't save the image")
                            if (saved) Analytics.send("share.completed", mapOf("type" to analyticsType, "destination" to "save"))
                        }
                    },
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Filled.Download, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Save")
                }
                LorcanaPrimaryButton(
                    onClick = {
                        scope.launch {
                            val bitmap = layer.toImageBitmap().asAndroidBitmap()
                            val uri = ShareSupport.writePng(context, bitmap, fileName)
                            ShareSupport.shareImage(context, uri, shareText)
                            Analytics.send("share.completed", mapOf("type" to analyticsType, "destination" to "sheet"))
                        }
                    },
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Filled.IosShare, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Share")
                }
            }
        }
    }
}
