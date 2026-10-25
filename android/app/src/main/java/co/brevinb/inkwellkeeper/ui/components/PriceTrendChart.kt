package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import java.time.LocalDate
import java.time.format.DateTimeFormatter

/** Line + area chart of daily prices with min/max labels, like the iOS Swift Charts view. */
@Composable
fun PriceTrendChart(points: List<Pair<LocalDate, Double>>, modifier: Modifier = Modifier, lineColor: Color = LorcanaGold) {
    if (points.size < 2) return
    val prices = points.map { it.second }
    val min = prices.min()
    val max = prices.max()
    val formatter = DateTimeFormatter.ofPattern("MMM d")
    Column(modifier) {
        Row(Modifier.fillMaxWidth()) {
            Text(PricingService.formatPrice(max), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
        Canvas(Modifier.fillMaxWidth().height(140.dp)) {
            val span = (max - min).takeIf { it > 0 } ?: 1.0
            val stepX = size.width / (points.size - 1)
            fun y(price: Double) = (size.height - ((price - min) / span * size.height * 0.9 + size.height * 0.05)).toFloat()
            val line = Path()
            points.forEachIndexed { index, (_, price) ->
                val point = Offset(index * stepX, y(price))
                if (index == 0) line.moveTo(point.x, point.y) else line.lineTo(point.x, point.y)
            }
            val area = Path().apply {
                addPath(line)
                lineTo(size.width, size.height)
                lineTo(0f, size.height)
                close()
            }
            drawPath(area, Brush.verticalGradient(listOf(lineColor.copy(alpha = 0.35f), Color.Transparent)))
            drawPath(line, lineColor, style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
            drawCircle(lineColor, radius = 3.dp.toPx(), center = Offset(size.width, y(prices.last())))
        }
        Row(Modifier.fillMaxWidth()) {
            Text(PricingService.formatPrice(min), style = MaterialTheme.typography.labelSmall, color = Color.Gray, modifier = Modifier.weight(1f))
        }
        Row(Modifier.fillMaxWidth()) {
            Text(points.first().first.format(formatter), style = MaterialTheme.typography.labelSmall, color = Color.Gray, modifier = Modifier.weight(1f))
            Text(points.last().first.format(formatter), style = MaterialTheme.typography.labelSmall, color = Color.Gray)
        }
    }
}
