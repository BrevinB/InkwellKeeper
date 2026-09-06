package co.brevinb.inkwellkeeper

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import kotlin.math.max

import co.brevinb.inkwellkeeper.model.CardVariant

internal fun CardVariant.isHolographic(): Boolean = when (this) {
    CardVariant.Foil,
    CardVariant.Enchanted,
    CardVariant.Epic,
    CardVariant.Iconic -> true
    else -> false
}

@Composable
internal fun FoilCardOverlay(
    variant: CardVariant,
    modifier: Modifier = Modifier
) {
    if (!variant.isHolographic()) return

    val transition = rememberInfiniteTransition(label = "foil shimmer")
    val shimmerPosition by transition.animateFloat(
        initialValue = -1.2f,
        targetValue = 1.2f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 4_000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "foil shimmer position"
    )
    var touchPosition by remember { mutableStateOf(Offset.Unspecified) }
    val intensity = if (variant == CardVariant.Foil) 0.82f else 1.12f
    val sparkleCount = if (variant == CardVariant.Foil) 20 else 35

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragStart = { touchPosition = it },
                    onDragEnd = { touchPosition = Offset.Unspecified },
                    onDragCancel = { touchPosition = Offset.Unspecified },
                    onDrag = { change, _ ->
                        change.consume()
                        touchPosition = change.position
                    }
                )
            }
    ) {
        val diagonalTravel = (size.width + size.height) * shimmerPosition
        val shimmerStart = Offset(diagonalTravel - size.width, 0f)
        val shimmerEnd = Offset(diagonalTravel + size.height, size.height)

        // Soft color shift underneath the bright moving band.
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    Color.Transparent,
                    Color(0xFF35E8FF).copy(alpha = 0.16f * intensity),
                    Color(0xFFB45CFF).copy(alpha = 0.19f * intensity),
                    Color(0xFF2378FF).copy(alpha = 0.16f * intensity),
                    Color(0xFFFFD95C).copy(alpha = 0.10f * intensity),
                    Color.Transparent
                ),
                start = Offset(0f, 0f),
                end = Offset(size.width, size.height)
            )
        )
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    Color.Transparent,
                    Color(0xFF4BE8FF).copy(alpha = 0.12f * intensity),
                    Color.White.copy(alpha = 0.42f * intensity),
                    Color(0xFFB35CFF).copy(alpha = 0.22f * intensity),
                    Color.Transparent
                ),
                start = shimmerStart,
                end = shimmerEnd
            )
        )

        // Finger-driven spotlight, equivalent to the iOS tilt highlight in an emulator.
        if (touchPosition != Offset.Unspecified) {
            val spotlight = Offset(
                touchPosition.x.coerceIn(0f, size.width),
                touchPosition.y.coerceIn(0f, size.height)
            )
            drawRect(
                brush = Brush.radialGradient(
                    colors = listOf(
                        Color.White.copy(alpha = 0.36f * intensity),
                        Color(0xFF66DFFF).copy(alpha = 0.14f * intensity),
                        Color.Transparent
                    ),
                    center = spotlight,
                    radius = max(size.width, size.height) * 0.92f
                )
            )
        }

        // Deterministic sparkle positions keep the overlay stable while the card recomposes.
        repeat(sparkleCount) { index ->
            val x = ((index * 47 + 13) % 101) / 100f
            val y = ((index * 71 + 29) % 101) / 100f
            val proximity = if (touchPosition != Offset.Unspecified) {
                val dx = x * size.width - touchPosition.x
                val dy = y * size.height - touchPosition.y
                (1f - ((dx * dx + dy * dy) / (size.width * size.width + size.height * size.height))).coerceIn(0f, 1f)
            } else {
                0.35f
            }
            val alpha = proximity * 0.72f * intensity
            if (alpha > 0.04f) {
                drawCircle(
                    color = Color.White.copy(alpha = alpha),
                    radius = if (variant == CardVariant.Foil) 1.4f else 1.9f,
                    center = Offset(x * size.width, y * size.height)
                )
            }
        }
    }
}
