package co.brevinb.inkwellkeeper.ui.decks

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.Style
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.Deck
import co.brevinb.inkwellkeeper.decks.OpeningHandSimulator
import co.brevinb.inkwellkeeper.ui.components.CardImage
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.components.LorcanaSecondaryButton
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold
import co.brevinb.inkwellkeeper.ui.theme.SystemColors

/** Deal sample 7-card hands and try the alteration (mulligan). */
@Composable
fun OpeningHandSheet(deck: Deck, onDismiss: () -> Unit) {
    val simulator = remember(deck.id) { OpeningHandSimulator.create(deck.cards) }
    var version by remember { mutableIntStateOf(0) }
    var selected by remember { mutableStateOf(setOf<Int>()) }
    FullScreenSheet(title = "Opening Hand", onDismiss = onDismiss, dismissLabel = "Done") { padding ->
        if (simulator == null) {
            EmptyState(Icons.Filled.Style, "Not Enough Cards", "Add at least ${OpeningHandSimulator.HAND_SIZE} cards to draw an opening hand.", Modifier.padding(padding))
            return@FullScreenSheet
        }
        version
        Column(Modifier.padding(padding).padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(
                "${simulator.inkableCount} of ${simulator.hand.size} inkable",
                style = MaterialTheme.typography.titleMedium,
                color = if (simulator.inkableCount >= 3) SystemColors.green else SystemColors.orange,
            )
            LazyVerticalGrid(GridCells.Fixed(4), Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                itemsIndexed(simulator.hand) { index, card ->
                    val isSelected = index in selected
                    CardImage(
                        card,
                        Modifier.clip(RoundedCornerShape(6.dp))
                            .border(if (isSelected) 3.dp else 0.dp, if (isSelected) LorcanaGold else Color.Transparent, RoundedCornerShape(6.dp))
                            .alpha(if (isSelected) 0.6f else 1f)
                            .clickable(enabled = !simulator.hasMulliganed) { selected = if (isSelected) selected - index else selected + index },
                    )
                }
            }
            Text(
                when {
                    simulator.hasMulliganed -> "Hand altered"
                    selected.isEmpty() -> "Tap cards to set aside, then alter your hand"
                    else -> "${selected.size} selected to put back"
                },
                style = MaterialTheme.typography.labelMedium, color = Color.Gray, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                LorcanaSecondaryButton(
                    onClick = { simulator.mulligan(selected); selected = emptySet(); version++ },
                    enabled = !simulator.hasMulliganed && selected.isNotEmpty(),
                    modifier = Modifier.weight(1f),
                ) {
                    Icon(Icons.Filled.Shuffle, null)
                    Spacer(Modifier.width(6.dp))
                    Text("Alter")
                }
                LorcanaPrimaryButton(onClick = { simulator.drawNewHand(); selected = emptySet(); version++ }, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.Refresh, null)
                    Spacer(Modifier.width(6.dp))
                    Text("New Hand")
                }
            }
        }
    }
}
