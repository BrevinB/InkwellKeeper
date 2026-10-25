package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil3.compose.SubcomposeAsyncImage
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard

/** Standard Lorcana card proportions (63×88 mm). */
const val CARD_ASPECT = 0.716f

/**
 * Card art from the catalog URL (disk-cached by Coil). Foil copies get the rainbow sheen the
 * iOS app draws over the same art; [animatedFoil] adds the slow light sweep.
 */
@Composable
fun CardImage(
    card: LorcanaCard,
    modifier: Modifier = Modifier,
    contentScale: ContentScale = ContentScale.Fit,
    animatedFoil: Boolean = false,
) {
    val foil = card.variant == CardVariant.FOIL
    SubcomposeAsyncImage(
        model = card.bestImageUrl,
        contentDescription = card.name,
        contentScale = contentScale,
        modifier = modifier.then(if (foil) Modifier.foilEffect(animatedFoil) else Modifier),
        loading = { CardPlaceholder() },
        error = { CardPlaceholder(showIcon = true) },
    )
}

@Composable
fun CardPlaceholder(modifier: Modifier = Modifier, showIcon: Boolean = false) {
    Box(
        modifier.fillMaxSize().aspectRatio(CARD_ASPECT, matchHeightConstraintsFirst = true)
            .background(Color.Gray.copy(alpha = 0.3f)),
        contentAlignment = Alignment.Center,
    ) {
        if (showIcon) Icon(Icons.Outlined.Image, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(32.dp))
    }
}

/** Static rainbow + shine overlay; optionally with a moving highlight band. */
@Composable
fun Modifier.foilEffect(animated: Boolean = false): Modifier {
    val shift = if (animated) {
        val transition = rememberInfiniteTransition(label = "foil")
        val value by transition.animateFloat(
            initialValue = -1f,
            targetValue = 2f,
            animationSpec = infiniteRepeatable(tween(4000, easing = LinearEasing), RepeatMode.Restart),
            label = "foilShift",
        )
        value
    } else {
        0.5f
    }
    return this.drawWithContent {
        drawContent()
        drawRect(
            brush = Brush.linearGradient(
                listOf(Color.Transparent, Color(0x33BF5AF2), Color(0x3364D2FF), Color(0x33FFD60A), Color.Transparent),
                start = Offset.Zero,
                end = Offset(size.width, size.height),
            ),
            blendMode = BlendMode.Screen,
        )
        val bandCenter = shift * size.width
        drawRect(
            brush = Brush.linearGradient(
                listOf(Color.Transparent, Color.White.copy(alpha = if (animated) 0.28f else 0.15f), Color.Transparent),
                start = Offset(bandCenter - size.width * 0.4f, 0f),
                end = Offset(bandCenter + size.width * 0.4f, size.height),
            ),
            blendMode = BlendMode.Screen,
        )
    }
}
