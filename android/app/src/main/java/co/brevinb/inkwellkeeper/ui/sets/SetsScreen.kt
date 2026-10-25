package co.brevinb.inkwellkeeper.ui.sets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.data.SpoilerSettings
import co.brevinb.inkwellkeeper.model.LorcanaSet
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

@Composable
fun SetsScreen() {
    val nav = LocalNav.current
    var spoilerPrompt by remember { mutableStateOf<LorcanaSet?>(null) }
    InkwellScaffold(title = "Card Sets", large = true, showBack = true) { padding ->
        if (!SetsDataManager.isDataLoaded) {
            Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = LorcanaGold) }
        } else {
            LazyVerticalGrid(
                GridCells.Adaptive(320.dp),
                Modifier.padding(padding).fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                items(SetsDataManager.sets, key = { it.id }) { set ->
                    SetProgressCard(set) {
                        if (SpoilerSettings.isHidden(set.name)) spoilerPrompt = set else nav.navigate(Routes.set(set.name))
                    }
                }
            }
        }
    }
    spoilerPrompt?.let { set ->
        AlertDialog(
            onDismissRequest = { spoilerPrompt = null },
            title = { Text("Show spoilers for ${set.name}?") },
            text = { Text("${set.name} releases ${set.releaseDateFormatted}. Its cards are hidden until then unless you choose to see them.") },
            confirmButton = {
                TextButton(onClick = {
                    SpoilerSettings.reveal(set.name)
                    spoilerPrompt = null
                    nav.navigate(Routes.set(set.name))
                }) { Text("Show Spoilers") }
            },
            dismissButton = { TextButton(onClick = { spoilerPrompt = null }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun SetProgressCard(set: LorcanaSet, onTap: () -> Unit) {
    val app = LocalApp.current
    val shape = RoundedCornerShape(12.dp)
    val base = Modifier.fillMaxWidth().clip(shape).background(LorcanaDark.copy(alpha = 0.8f)).border(1.dp, LorcanaGold.copy(alpha = 0.3f), shape).clickable(onClick = onTap).padding(16.dp)
    if (SpoilerSettings.isHidden(set.name)) {
        Row(base, verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(set.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White)
                UpcomingBadge(set)
                Text("${SetsDataManager.getCardsForSet(set.name).size} cards revealed so far", style = MaterialTheme.typography.bodyMedium, color = Color.Gray)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Filled.VisibilityOff, null, tint = LorcanaGold)
                Text("Spoilers hidden", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
            }
        }
        return
    }
    val total = if (SetsDataManager.hasLocalCards(set.name)) SetsDataManager.getCardsForSet(set.name).size else set.cardCount
    val progress = app.collection.getSetProgress(set.name, total)
    Column(base, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(set.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = Color.White, maxLines = 2)
                if (set.isUpcoming()) UpcomingBadge(set)
                Text("${progress.collected} of ${progress.total} cards", style = MaterialTheme.typography.bodyMedium, color = LorcanaGold)
            }
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("${progress.percentage.toInt()}%", style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, color = LorcanaGold)
                Text("Complete", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
            }
        }
        ProgressBar(progress.percentage / 100, 8)
    }
}

@Composable
fun ProgressBar(fraction: Double, height: Int) {
    Box(Modifier.fillMaxWidth().height(height.dp).clip(RoundedCornerShape(4.dp)).background(Color.Gray.copy(alpha = 0.3f))) {
        Box(
            Modifier.fillMaxWidth(fraction.toFloat().coerceIn(0f, 1f)).fillMaxHeight().clip(RoundedCornerShape(4.dp))
                .background(Brush.horizontalGradient(listOf(LorcanaGold, LorcanaGold.copy(alpha = 0.7f)))),
        )
    }
}

@Composable
fun UpcomingBadge(set: LorcanaSet) {
    Text(
        "Releases ${set.releaseDateFormatted}",
        style = MaterialTheme.typography.labelSmall,
        fontWeight = FontWeight.Bold,
        color = Color.Black,
        modifier = Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 8.dp, vertical = 2.dp),
    )
}

