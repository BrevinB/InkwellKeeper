package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.text.InlineTextContent
import androidx.compose.foundation.text.appendInlineContent
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.FlashOn
import androidx.compose.material.icons.filled.Hexagon
import androidx.compose.material.icons.filled.Opacity
import androidx.compose.material.icons.filled.RotateRight
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.Placeholder
import androidx.compose.ui.text.PlaceholderVerticalAlign
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.unit.em

/** A game symbol embedded in card text as a `{X}` token. */
enum class CardTextSymbol(val token: String, val spokenName: String, val icon: ImageVector) {
    EXERT("E", "exert", Icons.Filled.RotateRight),
    INK("I", "ink", Icons.Filled.Hexagon),
    STRENGTH("S", "strength", Icons.Filled.FlashOn),
    WILLPOWER("W", "willpower", Icons.Filled.Shield),
    LORE("L", "lore", Icons.Filled.Diamond),
    INKWELL("IW", "inkwell", Icons.Filled.Opacity);

    companion object {
        fun fromToken(token: String) = entries.firstOrNull { it.token == token }
    }
}

sealed interface CardTextSegment {
    data class Literal(val text: String) : CardTextSegment
    data class Symbol(val symbol: CardTextSymbol) : CardTextSegment
    data class InkCost(val amount: Int) : CardTextSegment
}

object CardTextParser {
    /** Splits card text into literal runs and `{X}` tokens; unknown tokens stay literal. */
    fun parse(text: String): List<CardTextSegment> {
        val segments = mutableListOf<CardTextSegment>()
        val current = StringBuilder()
        var i = 0
        while (i < text.length) {
            val open = text.indexOf('{', i)
            val close = if (open >= 0) text.indexOf('}', open) else -1
            if (open < 0 || close < 0) break
            val token = text.substring(open + 1, close)
            val replacement = CardTextSymbol.fromToken(token)?.let { CardTextSegment.Symbol(it) }
                ?: token.toIntOrNull()?.let { CardTextSegment.InkCost(it) }
            if (replacement != null) {
                current.append(text, i, open)
                if (current.isNotEmpty()) {
                    segments += CardTextSegment.Literal(current.toString())
                    current.clear()
                }
                segments += replacement
            } else {
                current.append(text, i, close + 1)
            }
            i = close + 1
        }
        current.append(text.substring(i))
        if (current.isNotEmpty()) segments += CardTextSegment.Literal(current.toString())
        return segments
    }

    fun spokenText(text: String): String = parse(text).joinToString("") {
        when (it) {
            is CardTextSegment.Literal -> it.text
            is CardTextSegment.Symbol -> it.symbol.spokenName
            is CardTextSegment.InkCost -> "${it.amount} ink"
        }
    }
}

/** Card rules text with game symbols rendered inline. */
@Composable
fun CardTextView(text: String, modifier: Modifier = Modifier, style: TextStyle = LocalTextStyle.current, color: Color = Color.Unspecified) {
    val tint = if (color == Color.Unspecified) LocalContentColor.current else color
    val annotated = buildAnnotatedString {
        for (segment in CardTextParser.parse(text)) {
            when (segment) {
                is CardTextSegment.Literal -> append(segment.text)
                is CardTextSegment.Symbol -> appendInlineContent(segment.symbol.name, segment.symbol.spokenName)
                is CardTextSegment.InkCost -> {
                    append("${segment.amount}")
                    appendInlineContent(CardTextSymbol.INK.name, "ink")
                }
            }
        }
    }
    val inline = CardTextSymbol.entries.associate { symbol ->
        symbol.name to InlineTextContent(Placeholder(1.1.em, 1.1.em, PlaceholderVerticalAlign.TextCenter)) {
            Icon(symbol.icon, contentDescription = null, tint = tint, modifier = Modifier.fillMaxSize())
        }
    }
    Text(
        annotated,
        inlineContent = inline,
        style = style,
        color = tint,
        modifier = modifier.semantics { contentDescription = CardTextParser.spokenText(text) },
    )
}
