package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Minimal Markdown for AI replies: **bold**, `#` headings, and `-`/`*` bullets. */
fun markdown(text: String): AnnotatedString = buildAnnotatedString {
    text.lines().forEachIndexed { index, raw ->
        if (index > 0) append('\n')
        var line = raw
        val heading = line.trimStart().startsWith("#")
        if (heading) line = line.trimStart().trimStart('#').trimStart()
        val bullet = Regex("^(\\s*)[-*] ").find(line)
        if (bullet != null) line = bullet.groupValues[1] + "• " + line.substring(bullet.value.length)
        line.split("**").forEachIndexed { i, part ->
            if (heading || i % 2 == 1) withStyle(SpanStyle(fontWeight = FontWeight.Bold, color = if (heading) LorcanaGold else Color.Unspecified)) { append(part) }
            else append(part)
        }
    }
}
