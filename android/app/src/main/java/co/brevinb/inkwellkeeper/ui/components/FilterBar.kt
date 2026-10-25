package co.brevinb.inkwellkeeper.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.outlined.Cancel
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.model.CardFilter
import co.brevinb.inkwellkeeper.model.InkColorFilter
import co.brevinb.inkwellkeeper.model.SortOption
import co.brevinb.inkwellkeeper.model.VariantFilter
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

fun VariantFilter.chipColor(): Color = when (this) {
    VariantFilter.ALL -> Color.Gray
    VariantFilter.NORMAL -> Color.White
    VariantFilter.FOIL -> LorcanaGold
    VariantFilter.ENCHANTED -> SystemColors.purple
    VariantFilter.PROMO -> SystemColors.orange
    VariantFilter.SPECIAL -> SystemColors.cyan
}

/** Collapsible type / ink / variant filters plus a sort menu, as on the iOS Collection tab. */
@Composable
fun FilterBar(
    selectedFilter: CardFilter,
    onFilter: (CardFilter) -> Unit,
    selectedInk: InkColorFilter,
    onInk: (InkColorFilter) -> Unit,
    selectedVariant: VariantFilter,
    onVariant: (VariantFilter) -> Unit,
    sortOption: SortOption,
    onSort: (SortOption) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    var sortMenu by remember { mutableStateOf(false) }
    val activeCount = listOf(selectedFilter != CardFilter.ALL, selectedInk != InkColorFilter.ALL, selectedVariant != VariantFilter.ALL).count { it }
    val hasActive = activeCount > 0

    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.clip(RoundedCornerShape(8.dp)).background(LorcanaDark.copy(alpha = 0.6f))
                    .clickable { expanded = !expanded }.padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                val tint = if (hasActive) LorcanaGold else Color.Gray
                Icon(Icons.Filled.FilterList, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp))
                Text("Filters", style = MaterialTheme.typography.bodyMedium, color = tint, maxLines = 1)
                if (hasActive) {
                    Text(
                        "$activeCount",
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.Bold,
                        color = Color.Black,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 6.dp, vertical = 1.dp),
                    )
                }
                Icon(if (expanded) Icons.Filled.KeyboardArrowUp else Icons.Filled.KeyboardArrowDown, null, tint = tint, modifier = Modifier.size(16.dp))
            }
            Spacer(Modifier.weight(1f))
            Box {
                Row(
                    Modifier.clip(RoundedCornerShape(8.dp)).background(LorcanaDark.copy(alpha = 0.6f))
                        .clickable { sortMenu = true }.padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Icon(Icons.Filled.SwapVert, contentDescription = "Sort", tint = LorcanaGold, modifier = Modifier.size(16.dp))
                    Text(sortOption.displayName, style = MaterialTheme.typography.labelMedium, color = LorcanaGold, maxLines = 1)
                }
                DropdownMenu(expanded = sortMenu, onDismissRequest = { sortMenu = false }) {
                    SortOption.entries.forEach { option ->
                        DropdownMenuItem(
                            text = { Text(option.displayName) },
                            trailingIcon = { if (option == sortOption) Icon(Icons.Filled.Check, null) },
                            onClick = {
                                onSort(option)
                                sortMenu = false
                            },
                        )
                    }
                }
            }
        }

        if (!expanded && hasActive) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (selectedFilter != CardFilter.ALL) ActivePill(selectedFilter.displayName, SystemColors.blue) { onFilter(CardFilter.ALL) }
                if (selectedInk != InkColorFilter.ALL) ActivePill(selectedInk.displayName, selectedInk.color) { onInk(InkColorFilter.ALL) }
                if (selectedVariant != VariantFilter.ALL) ActivePill(selectedVariant.displayName, selectedVariant.chipColor()) { onVariant(VariantFilter.ALL) }
            }
        }

        AnimatedVisibility(expanded) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterRow("Type") {
                    CardFilter.entries.forEach { GoldChip(it.displayName, selectedFilter == it, { onFilter(it) }) }
                }
                FilterRow("Color") {
                    InkColorFilter.entries.forEach { ink ->
                        TintedChip(ink.icon, if (ink == InkColorFilter.ALL) null else ink.displayName, ink.color, selectedInk == ink, { onInk(ink) }, contentDescription = "All colors")
                    }
                }
                FilterRow("Variant") {
                    VariantFilter.entries.forEach { v ->
                        TintedChip(v.icon, if (v == VariantFilter.ALL) null else v.displayName, v.chipColor(), selectedVariant == v, { onVariant(v) }, contentDescription = "All variants")
                    }
                }
                if (hasActive) {
                    TextButton(
                        onClick = {
                            onFilter(CardFilter.ALL)
                            onInk(InkColorFilter.ALL)
                            onVariant(VariantFilter.ALL)
                        },
                        modifier = Modifier.align(Alignment.CenterHorizontally),
                    ) {
                        Icon(Icons.Outlined.Cancel, null, tint = SystemColors.red.copy(alpha = 0.8f), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Clear All Filters", style = MaterialTheme.typography.labelMedium, color = SystemColors.red.copy(alpha = 0.8f))
                    }
                }
            }
        }
    }
}

@Composable
private fun FilterRow(label: String, content: @Composable () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text("$label:", style = MaterialTheme.typography.labelMedium, color = Color.Gray, modifier = Modifier.width(52.dp))
        Row(Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            content()
        }
    }
}

@Composable
private fun ActivePill(text: String, color: Color, onRemove: () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        Modifier.clip(shape).background(color.copy(alpha = 0.2f)).border(1.dp, color.copy(alpha = 0.5f), shape)
            .clickable(onClick = onRemove).padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.Medium, color = color, maxLines = 1)
        Icon(Icons.Filled.Cancel, contentDescription = "Remove $text filter", tint = color, modifier = Modifier.size(14.dp))
    }
}
