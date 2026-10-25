package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import kotlin.random.Random

val LorcanaGradient = Brush.linearGradient(
    colors = listOf(Color(0.05f, 0.1f, 0.2f), Color(0.1f, 0.05f, 0.15f), Color(0.05f, 0.1f, 0.2f)),
    start = Offset.Zero,
    end = Offset.Infinite,
)

private data class Sparkle(val x: Float, val y: Float, val radius: Float, val alpha: Float, val phase: Float)

/** Navy→plum gradient with softly twinkling gold sparkles, as on iOS. */
@Composable
fun LorcanaBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit = {}) {
    val sparkles = remember {
        val random = Random(42)
        List(20) {
            Sparkle(
                x = random.nextFloat(),
                y = random.nextFloat(),
                radius = 1f + random.nextFloat() * 2f,
                alpha = 0.1f + random.nextFloat() * 0.2f,
                phase = random.nextFloat(),
            )
        }
    }
    val transition = rememberInfiniteTransition(label = "sparkles")
    val twinkle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(3500), RepeatMode.Reverse),
        label = "twinkle",
    )
    Box(modifier.fillMaxSize().background(LorcanaGradient)) {
        Canvas(Modifier.fillMaxSize()) {
            for (s in sparkles) {
                val pulse = 0.5f + 0.5f * kotlin.math.sin((twinkle + s.phase) * Math.PI.toFloat() * 2)
                drawCircle(
                    color = LorcanaGold.copy(alpha = s.alpha * (0.6f + 0.4f * pulse)),
                    radius = s.radius * density,
                    center = Offset(s.x * size.width, s.y * size.height),
                )
            }
        }
        content()
    }
}
