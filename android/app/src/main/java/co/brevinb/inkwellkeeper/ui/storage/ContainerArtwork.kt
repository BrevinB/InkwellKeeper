package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.Paint
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.res.painterResource
import co.brevinb.inkwellkeeper.R
import co.brevinb.inkwellkeeper.storage.StorageCoverColor
import co.brevinb.inkwellkeeper.storage.StorageCoverStyle
import co.brevinb.inkwellkeeper.storage.StorageKind

/** Where a render's parts land, as fractions of the frame (generated on iOS from Blender). */
private data class ArtMetrics(val prefix: String, val lidHinge: Offset? = null, val lidRise: Float = 0f)

private fun metrics(kind: StorageKind) = when (kind) {
    StorageKind.BINDER -> ArtMetrics("binder")
    StorageKind.TROVE -> ArtMetrics("trove", Offset(0.0561f, 0.6416f), 0.3002f)
    StorageKind.DECK_BOX -> ArtMetrics("deckbox", Offset(0.1823f, 0.5825f), 0.3133f)
    StorageKind.STORAGE_BOX -> ArtMetrics("storagebox", Offset(0.0443f, 0.6496f), 0.2751f)
    StorageKind.BULK_BIN -> ArtMetrics("bulkbin")
    StorageKind.OTHER -> ArtMetrics("otherbox", Offset(0.1406f, 0.6172f), 0.3339f)
}

/** Resource ids for one layer's shade + mask pair, e.g. `trove_base_classic`. */
private fun layer(name: String): Pair<Int, Int>? = layerIds[name]

private val layerIds: Map<String, Pair<Int, Int>> = mapOf(
    "binder_base_classic" to (R.drawable.storage_binder_base_classic_shade to R.drawable.storage_binder_base_classic_mask),
    "binder_base_stitched" to (R.drawable.storage_binder_base_stitched_shade to R.drawable.storage_binder_base_stitched_mask),
    "trove_base_classic" to (R.drawable.storage_trove_base_classic_shade to R.drawable.storage_trove_base_classic_mask),
    "trove_base_stitched" to (R.drawable.storage_trove_base_stitched_shade to R.drawable.storage_trove_base_stitched_mask),
    "trove_lid_classic" to (R.drawable.storage_trove_lid_classic_shade to R.drawable.storage_trove_lid_classic_mask),
    "trove_lid_stitched" to (R.drawable.storage_trove_lid_stitched_shade to R.drawable.storage_trove_lid_stitched_mask),
    "deckbox_base_classic" to (R.drawable.storage_deckbox_base_classic_shade to R.drawable.storage_deckbox_base_classic_mask),
    "deckbox_base_stitched" to (R.drawable.storage_deckbox_base_stitched_shade to R.drawable.storage_deckbox_base_stitched_mask),
    "deckbox_lid_classic" to (R.drawable.storage_deckbox_lid_classic_shade to R.drawable.storage_deckbox_lid_classic_mask),
    "deckbox_lid_stitched" to (R.drawable.storage_deckbox_lid_stitched_shade to R.drawable.storage_deckbox_lid_stitched_mask),
    "storagebox_base_classic" to (R.drawable.storage_storagebox_base_classic_shade to R.drawable.storage_storagebox_base_classic_mask),
    "storagebox_base_stitched" to (R.drawable.storage_storagebox_base_stitched_shade to R.drawable.storage_storagebox_base_stitched_mask),
    "storagebox_lid_classic" to (R.drawable.storage_storagebox_lid_classic_shade to R.drawable.storage_storagebox_lid_classic_mask),
    "storagebox_lid_stitched" to (R.drawable.storage_storagebox_lid_stitched_shade to R.drawable.storage_storagebox_lid_stitched_mask),
    "bulkbin_base_classic" to (R.drawable.storage_bulkbin_base_classic_shade to R.drawable.storage_bulkbin_base_classic_mask),
    "bulkbin_base_stitched" to (R.drawable.storage_bulkbin_base_stitched_shade to R.drawable.storage_bulkbin_base_stitched_mask),
    "otherbox_base_classic" to (R.drawable.storage_otherbox_base_classic_shade to R.drawable.storage_otherbox_base_classic_mask),
    "otherbox_base_stitched" to (R.drawable.storage_otherbox_base_stitched_shade to R.drawable.storage_otherbox_base_stitched_mask),
    "otherbox_lid_classic" to (R.drawable.storage_otherbox_lid_classic_shade to R.drawable.storage_otherbox_lid_classic_mask),
    "otherbox_lid_stitched" to (R.drawable.storage_otherbox_lid_stitched_shade to R.drawable.storage_otherbox_lid_stitched_mask),
    "bindercover_base_classic" to (R.drawable.storage_bindercover_base_classic_shade to R.drawable.storage_bindercover_base_classic_mask),
    "bindercover_base_stitched" to (R.drawable.storage_bindercover_base_stitched_shade to R.drawable.storage_bindercover_base_stitched_mask),
    "binderspine_base_classic" to (R.drawable.storage_binderspine_base_classic_shade to R.drawable.storage_binderspine_base_classic_mask),
    "binderspine_base_stitched" to (R.drawable.storage_binderspine_base_stitched_shade to R.drawable.storage_binderspine_base_stitched_mask),
)

private fun finish(style: StorageCoverStyle) = if (style == StorageCoverStyle.LEATHER) "stitched" else "classic"

/**
 * A binder or box drawn from the iOS app's Blender renders: the cover color multiplied over
 * the lit shade inside the leather mask, keeping the render's lighting and gold trim.
 * [lidLift] (0–1) raises a box's lid.
 */
@Composable
fun ContainerArtwork(
    kind: StorageKind,
    color: StorageCoverColor,
    style: StorageCoverStyle,
    modifier: Modifier = Modifier,
    lidLift: Float = 0f,
) {
    val m = metrics(kind)
    val base = layer("${m.prefix}_base_${finish(style)}") ?: return
    val lid = if (m.lidHinge != null) layer("${m.prefix}_lid_${finish(style)}") else null
    val baseShade = painterResource(base.first)
    val baseMask = painterResource(base.second)
    val lidShade = lid?.let { painterResource(it.first) }
    val lidMask = lid?.let { painterResource(it.second) }
    val aspect = baseShade.intrinsicSize.let { if (it.height > 0) it.width / it.height else 0.78f }
    Canvas(modifier.aspectRatio(aspect).graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
        drawTinted(baseShade, baseMask, color, style)
        if (lidShade != null && lidMask != null && m.lidHinge != null) {
            val lift = lidLift.coerceIn(0f, 1f)
            translate(top = -size.height * m.lidRise * lift) {
                rotate(-4f * lift, pivot = Offset(m.lidHinge.x * size.width, m.lidHinge.y * size.height)) {
                    drawTinted(lidShade, lidMask, color, style)
                }
            }
        }
    }
}

/** Just the binder's cover, for the opening animation and bookshelf. */
@Composable
fun BinderCoverArtwork(color: StorageCoverColor, style: StorageCoverStyle, modifier: Modifier = Modifier) {
    val ids = layer("bindercover_base_${finish(style)}") ?: return
    val shade = painterResource(ids.first)
    val mask = painterResource(ids.second)
    val emblem = painterResource(R.drawable.storage_bindercover_emblem)
    val plate = painterResource(R.drawable.storage_bindercover_plate)
    val aspect = shade.intrinsicSize.let { if (it.height > 0) it.width / it.height else 0.75f }
    Canvas(modifier.aspectRatio(aspect).graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
        drawTinted(shade, mask, color, style)
        drawOrnament(plate, 0.3132f, 0.1721f, 0.522f, 0.1593f)
        drawOrnament(emblem, 0.4286f, 0.5057f, 0.2921f, 0.2271f)
    }
}

/** A binder's spine, for the bookshelf. */
@Composable
fun BinderSpineArtwork(color: StorageCoverColor, style: StorageCoverStyle, modifier: Modifier = Modifier) {
    val ids = layer("binderspine_base_${finish(style)}") ?: return
    val shade = painterResource(ids.first)
    val mask = painterResource(ids.second)
    val aspect = shade.intrinsicSize.let { if (it.height > 0) it.width / it.height else 0.2f }
    Canvas(modifier.aspectRatio(aspect).graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }) {
        drawTinted(shade, mask, color, style)
    }
}

private fun DrawScope.drawOrnament(painter: Painter, x: Float, y: Float, w: Float, h: Float) {
    translate(left = x * size.width, top = y * size.height) {
        with(painter) { draw(Size(w * size.width, h * size.height)) }
    }
}

private fun DrawScope.drawTinted(shade: Painter, mask: Painter, color: StorageCoverColor, style: StorageCoverStyle) {
    with(shade) { draw(size) }
    val bounds = Rect(Offset.Zero, size)
    // Multiply the cover color over the shade, only where the leather mask is.
    drawContext.canvas.saveLayer(bounds, Paint().apply { blendMode = BlendMode.Multiply })
    with(mask) { draw(size, colorFilter = ColorFilter.tint(color.highlight, BlendMode.SrcIn)) }
    drawContext.canvas.restore()
    if (style == StorageCoverStyle.STARLIGHT || style == StorageCoverStyle.HOLOFOIL) {
        // The Pro finishes sit on the leather only, never the trim.
        val brush = if (style == StorageCoverStyle.HOLOFOIL) {
            Brush.linearGradient(listOf(Color(0xFFFF6EC7), Color(0xFF64D2FF), Color(0xFFFFD60A), Color(0xFF30D158)))
        } else {
            Brush.radialGradient(listOf(Color.White, Color.Transparent), center = Offset(size.width * 0.3f, size.height * 0.25f), radius = size.minDimension * 0.7f)
        }
        drawContext.canvas.saveLayer(bounds, Paint().apply { blendMode = BlendMode.Screen; alpha = 0.35f })
        with(mask) { draw(size) }
        drawRect(brush, blendMode = BlendMode.SrcIn)
        drawContext.canvas.restore()
    }
}
