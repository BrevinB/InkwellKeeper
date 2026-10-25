package co.brevinb.inkwellkeeper.ui.card

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddPhotoAlternate
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import co.brevinb.inkwellkeeper.data.PhotoStore
import co.brevinb.inkwellkeeper.ui.components.SectionCard
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import java.io.File

/** "My Card Photos": the collector's own photos of a card (e.g. a graded slab or a signature). */
@Composable
fun CardPhotosSection(
    photos: List<String>,
    onAdd: (List<String>) -> Unit,
    onRemove: (String) -> Unit,
    modifier: Modifier = Modifier,
    title: String = "My Card Photos",
) {
    val context = LocalContext.current
    var pendingCapture by remember { mutableStateOf<File?>(null) }
    var viewing by remember { mutableStateOf<String?>(null) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickMultipleVisualMedia(5)) { uris: List<Uri> ->
        onAdd(uris.mapNotNull { PhotoStore.importImage(context, it) })
    }
    val camera = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { saved ->
        val file = pendingCapture
        if (saved && file != null && file.length() > 0) onAdd(listOf(file.absolutePath)) else file?.delete()
        pendingCapture = null
    }

    SectionCard(modifier, title = title) {
        if (photos.isEmpty()) {
            Text("Add photos of your physical card — a graded slab, a signature, or its condition.", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
        } else {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(photos) { path ->
                    Box {
                        AsyncImage(
                            model = File(path),
                            contentDescription = "Card photo",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(90.dp, 120.dp).clip(RoundedCornerShape(8.dp)).clickable { viewing = path },
                        )
                        IconButton(
                            onClick = { onRemove(path) },
                            modifier = Modifier.align(Alignment.TopEnd).padding(2.dp).size(24.dp).background(Color.Black.copy(alpha = 0.6f), CircleShape),
                        ) { Icon(Icons.Filled.Close, contentDescription = "Remove photo", tint = Color.White, modifier = Modifier.size(14.dp)) }
                    }
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            TextButton(onClick = {
                val (file, uri) = PhotoStore.newCaptureTarget(context)
                pendingCapture = file
                camera.launch(uri)
            }) {
                Icon(Icons.Filled.CameraAlt, null, tint = LorcanaGold)
                Text(" Take Photo", color = LorcanaGold)
            }
            TextButton(onClick = { picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }) {
                Icon(Icons.Filled.AddPhotoAlternate, null, tint = LorcanaGold)
                Text(" Choose Photos", color = LorcanaGold)
            }
        }
    }

    viewing?.let { path ->
        Dialog(onDismissRequest = { viewing = null }, properties = DialogProperties(usePlatformDefaultWidth = false)) {
            Box(Modifier.fillMaxSize().background(Color.Black).clickable { viewing = null }, contentAlignment = Alignment.Center) {
                AsyncImage(model = File(path), contentDescription = "Card photo", contentScale = ContentScale.Fit, modifier = Modifier.fillMaxSize())
            }
        }
    }
}
