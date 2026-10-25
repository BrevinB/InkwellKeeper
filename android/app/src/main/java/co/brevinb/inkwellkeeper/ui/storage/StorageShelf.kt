package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.navigation.LocalNav
import co.brevinb.inkwellkeeper.ui.navigation.Routes
import co.brevinb.inkwellkeeper.ui.theme.LorcanaDark
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/**
 * The shelf at the top of the Collection tab: the Unsorted pile, then every binder and box,
 * then a slot to add another.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun StorageShelf(
    unsortedCount: Int,
    showUnsortedOnly: Boolean,
    onToggleUnsorted: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val app = LocalApp.current
    val nav = LocalNav.current
    val collapsed = AppSettings.storageShelfCollapsed
    var showingCreate by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<StorageContainer?>(null) }
    var pendingDelete by remember { mutableStateOf<StorageContainer?>(null) }
    var showingLimit by remember { mutableStateOf(false) }
    val chevron by animateFloatAsState(if (collapsed) -90f else 0f, label = "chevron")

    fun addContainer() {
        if (app.storage.canCreateContainer(AppSettings.isProUnlocked)) showingCreate = true else showingLimit = true
    }

    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Row(
                Modifier.clip(RoundedCornerShape(8.dp)).clickable { AppSettings.updateStorageShelfCollapsed(!collapsed) }.padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Storage", style = MaterialTheme.typography.titleMedium, color = LorcanaGold)
                Icon(Icons.Filled.KeyboardArrowDown, contentDescription = if (collapsed) "Expand storage" else "Collapse storage", tint = Color.Gray, modifier = Modifier.rotate(chevron))
            }
            if (showUnsortedOnly) {
                Spacer(Modifier.width(8.dp))
                Row(
                    Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold.copy(alpha = 0.2f)).clickable(onClick = onToggleUnsorted)
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Cancel, contentDescription = "Clear Unsorted filter", tint = LorcanaGold, modifier = Modifier.size(14.dp))
                    Text(" Unsorted", style = MaterialTheme.typography.labelMedium, color = LorcanaGold)
                }
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = ::addContainer) {
                Icon(Icons.Filled.Add, contentDescription = "Add Binder or Box", tint = LorcanaGold)
            }
        }

        AnimatedVisibility(!collapsed) {
            if (app.storage.containers.isEmpty()) {
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(LorcanaDark.copy(alpha = 0.6f))
                        .border(1.dp, LorcanaGold.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                        .clickable(onClick = ::addContainer).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Icon(Icons.Filled.Inventory2, null, tint = LorcanaGold)
                    Column(Modifier.weight(1f)) {
                        Text("Where are your cards?", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, color = Color.White)
                        Text("Add your binders and boxes to track where every copy lives.", style = MaterialTheme.typography.labelMedium, color = Color.Gray)
                    }
                    Icon(Icons.Filled.Add, null, tint = LorcanaGold)
                }
            } else {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item {
                        ShelfTile(
                            title = "Unsorted",
                            subtitle = "$unsortedCount",
                            selected = showUnsortedOnly,
                            onClick = onToggleUnsorted,
                        ) {
                            Icon(Icons.Filled.Inventory2, null, tint = if (showUnsortedOnly) LorcanaGold else Color.Gray, modifier = Modifier.size(40.dp))
                        }
                    }
                    items(app.storage.containers, key = { it.id }) { container ->
                        var menu by remember { mutableStateOf(false) }
                        Box {
                            ShelfTile(
                                title = container.name,
                                subtitle = if (app.storage.isFull(container)) "Full" else "${container.cardCount}",
                                selected = false,
                                onClick = { nav.navigate(Routes.container(container.id)) },
                                onLongClick = { menu = true },
                            ) {
                                ContainerArtwork(container.kind, container.coverColor, container.cover, Modifier.height(56.dp))
                            }
                            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                                DropdownMenuItem(text = { Text("Edit") }, onClick = { menu = false; editing = container })
                                DropdownMenuItem(text = { Text("Delete") }, onClick = { menu = false; pendingDelete = container })
                            }
                        }
                    }
                    item {
                        ShelfTile(title = "Add", subtitle = "Binder or box", selected = false, onClick = ::addContainer) {
                            Icon(Icons.Filled.Add, null, tint = LorcanaGold, modifier = Modifier.size(40.dp))
                        }
                    }
                }
            }
        }
    }

    if (showingCreate || editing != null) {
        ContainerEditorSheet(
            container = editing,
            onDismiss = {
                showingCreate = false
                editing = null
            },
            onCreated = { nav.navigate(Routes.container(it.id)) },
        )
    }
    pendingDelete?.let { container ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Delete ${container.name}?") },
            text = { Text("Its cards stay in your collection and move back to Unsorted.") },
            confirmButton = {
                TextButton(onClick = {
                    app.storage.delete(container)
                    pendingDelete = null
                }) { Text("Delete ${container.kind.displayName}", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = { TextButton(onClick = { pendingDelete = null }) { Text("Cancel") } },
        )
    }
    if (showingLimit) {
        AlertDialog(
            onDismissRequest = { showingLimit = false },
            title = { Text("Inkwell Keeper Pro") },
            text = { Text("Free collections can track ${co.brevinb.inkwellkeeper.storage.StorageManager.FREE_CONTAINER_LIMIT} binders or boxes. Pro removes the limit. (Deck boxes for built decks never count.)") },
            confirmButton = { TextButton(onClick = { showingLimit = false; nav.navigate(Routes.paywall("storageLimit")) }) { Text("Learn More") } },
            dismissButton = { TextButton(onClick = { showingLimit = false }) { Text("Not Now") } },
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ShelfTile(
    title: String,
    subtitle: String,
    selected: Boolean,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null,
    art: @Composable () -> Unit,
) {
    val shape = RoundedCornerShape(12.dp)
    Column(
        Modifier.width(92.dp).clip(shape)
            .background(if (selected) LorcanaGold.copy(alpha = 0.18f) else LorcanaDark.copy(alpha = 0.6f))
            .border(1.dp, if (selected) LorcanaGold else LorcanaGold.copy(alpha = 0.2f), shape)
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .padding(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.height(56.dp), contentAlignment = Alignment.Center) { art() }
        Text(title, style = MaterialTheme.typography.labelMedium, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, textAlign = TextAlign.Center)
        Text(subtitle, style = MaterialTheme.typography.labelSmall, color = Color.Gray, maxLines = 1)
    }
}
