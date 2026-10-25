package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.pricing.PricingService
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.EmptyState
import co.brevinb.inkwellkeeper.ui.components.InkwellScaffold
import co.brevinb.inkwellkeeper.ui.components.LorcanaPrimaryButton
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

private val woodLight = Color(0xFF8B5A2B)
private val woodDark = Color(0xFF5C3A1A)

/** Every binder and box standing on a wooden bookcase; tap one to open it. */
@Composable
fun BookshelfScreen() {
    val app = LocalApp.current
    val nav = LocalNav.current
    app.storage.revision
    var creating by remember { mutableStateOf(false) }
    val containers = app.storage.containers
    val perShelf = 3

    InkwellScaffold("Bookshelf", showBack = true, actions = {
        IconButton(onClick = { creating = true }) { Icon(Icons.Filled.Add, contentDescription = "Add Storage") }
    }) { padding ->
        Column(Modifier.padding(padding).verticalScroll(rememberScrollState()).navigationBarsPadding().padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceEvenly) {
                Summary("${containers.size}", if (containers.size == 1) "Container" else "Containers")
                Summary("${containers.sumOf { it.cardCount }}", "Cards")
                Summary(PricingService.formatPrice(containers.sumOf { app.storage.value(it) }), "Value")
            }
            if (containers.isEmpty()) {
                EmptyState(Icons.Filled.Inventory2, "An Empty Bookcase", "Add your binders and boxes to see them on the shelf.") {
                    LorcanaPrimaryButton(onClick = { creating = true }) { Text("Add Storage") }
                }
            }
            containers.chunked(perShelf).forEach { row ->
                Column(Modifier.padding(top = 12.dp)) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Bottom) {
                        row.forEach { c ->
                            Column(Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).clickable { nav.navigate(Routes.container(c.id)) }, horizontalAlignment = Alignment.CenterHorizontally) {
                                Box(Modifier.height(110.dp), contentAlignment = Alignment.BottomCenter) {
                                    ContainerArtwork(c.kind, c.coverColor, c.cover, Modifier.height(if (c.kind.usesSlots) 110.dp else 72.dp))
                                }
                            }
                        }
                        repeat(perShelf - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                    Box(Modifier.fillMaxWidth().height(14.dp).shadow(6.dp, RoundedCornerShape(3.dp)).background(Brush.verticalGradient(listOf(woodLight, woodDark)), RoundedCornerShape(3.dp)))
                    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        row.forEach { c ->
                            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(c.name, style = MaterialTheme.typography.labelMedium, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
                                Text("${c.cardCount} cards", style = MaterialTheme.typography.labelSmall, color = Color.Gray)
                            }
                        }
                        repeat(perShelf - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
    }
    if (creating) ContainerEditorSheet(null, onDismiss = { creating = false }, onCreated = { creating = false; nav.navigate(Routes.container(it.id)) })
}

@Composable
private fun Summary(value: String, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold, color = LorcanaGold)
        Text(label, style = MaterialTheme.typography.labelMedium, color = Color.Gray)
    }
}
