package co.brevinb.inkwellkeeper.ui.storage

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import co.brevinb.inkwellkeeper.data.AppSettings
import co.brevinb.inkwellkeeper.data.SetsDataManager
import co.brevinb.inkwellkeeper.storage.BinderLayout
import co.brevinb.inkwellkeeper.storage.SetChecklistLayout
import co.brevinb.inkwellkeeper.storage.StorageContainer
import co.brevinb.inkwellkeeper.storage.StorageCoverColor
import co.brevinb.inkwellkeeper.storage.StorageCoverStyle
import co.brevinb.inkwellkeeper.storage.StorageKind
import co.brevinb.inkwellkeeper.ui.LocalApp
import co.brevinb.inkwellkeeper.ui.components.FormSection
import co.brevinb.inkwellkeeper.ui.components.FormTextField
import co.brevinb.inkwellkeeper.ui.components.FullScreenSheet
import co.brevinb.inkwellkeeper.ui.components.LabeledRow
import co.brevinb.inkwellkeeper.ui.components.MenuPickerRow
import co.brevinb.inkwellkeeper.ui.components.SegmentedPicker
import co.brevinb.inkwellkeeper.ui.components.StepperRow
import co.brevinb.inkwellkeeper.ui.components.ToggleRow
import co.brevinb.inkwellkeeper.ui.theme.LorcanaGold

/** Editable copy of a container's settings, so the editor can be cancelled. */
data class ContainerDraft(
    val name: String = "",
    val kind: StorageKind = StorageKind.BINDER,
    val color: StorageCoverColor = StorageCoverColor.AMETHYST,
    val style: StorageCoverStyle = StorageCoverStyle.CLASSIC,
    val pocketsPerPage: Int = 9,
    val sheetCount: Int = 20,
    val isDoubleSided: Boolean = true,
    val tracksCapacity: Boolean = false,
    val capacity: Int = 100,
    val linkedSetName: String? = null,
    val hasFoilPockets: Boolean = false,
    val linkedDeckId: String? = null,
) {
    val layout: BinderLayout get() = BinderLayout.of(pocketsPerPage, sheetCount, isDoubleSided)

    fun minimumSheets(cardCount: Int): Int = if (cardCount > 0) layout.sheetsNeeded(cardCount) else 1

    fun withKind(newKind: StorageKind): ContainerDraft {
        if (newKind == kind) return this
        val cap = newKind.defaultCapacity
        return if (cap != null) copy(kind = newKind, capacity = cap, tracksCapacity = true) else copy(kind = newKind)
    }

    /** Never let an edit leave less room than the cards already inside. */
    fun keepingRoom(cardCount: Int): ContainerDraft = when {
        kind.usesSlots && layout.totalSlots < cardCount -> copy(sheetCount = layout.sheetsNeeded(cardCount))
        !kind.usesSlots && tracksCapacity && capacity < cardCount -> copy(capacity = cardCount)
        else -> this
    }

    /** Resizes a set binder so every pocket of its checklist exists. */
    fun sizedForChecklist(): ContainerDraft {
        val set = linkedSetName ?: return this
        val pockets = SetChecklistLayout(SetChecklistLayout.catalogPrintings(set), hasFoilPockets).pocketCount
        return copy(sheetCount = layout.sheetsNeeded(pockets))
    }

    fun apply(container: StorageContainer) {
        name.trim().takeIf { it.isNotEmpty() }?.let { container.name = it }
        container.kind = kind
        container.coverColor = color
        container.cover = style
        container.pocketsPerPage = pocketsPerPage
        container.sheetCount = sheetCount
        container.isDoubleSided = isDoubleSided
        container.capacity = if (kind.usesSlots || !tracksCapacity) null else capacity
        container.linkedSetName = if (kind.usesSlots) linkedSetName else null
        container.hasFoilPockets = kind.usesSlots && linkedSetName != null && hasFoilPockets
        container.linkedDeckId = if (kind == StorageKind.DECK_BOX) linkedDeckId else null
    }

    companion object {
        fun from(container: StorageContainer) = ContainerDraft(
            name = container.name,
            kind = container.kind,
            color = container.coverColor,
            style = container.cover,
            pocketsPerPage = container.pocketsPerPage,
            sheetCount = container.sheetCount,
            isDoubleSided = container.isDoubleSided,
            tracksCapacity = container.capacity != null,
            capacity = container.capacity ?: container.kind.defaultCapacity ?: 100,
            linkedSetName = container.linkedSetName,
            hasFoilPockets = container.hasFoilPockets,
            linkedDeckId = container.linkedDeckId,
        )
    }
}

/** Create or edit a binder, trove, box or bin, with a live preview at the top. */
@Composable
fun ContainerEditorSheet(
    container: StorageContainer?,
    onDismiss: () -> Unit,
    onCreated: (StorageContainer) -> Unit = {},
    initialKind: StorageKind = StorageKind.BINDER,
) {
    val app = LocalApp.current
    val cardCount = container?.cardCount ?: 0
    val isPro = AppSettings.isProUnlocked
    var draft by remember { mutableStateOf(container?.let { ContainerDraft.from(it) } ?: ContainerDraft().withKind(initialKind)) }
    fun update(transform: (ContainerDraft) -> ContainerDraft) {
        draft = transform(draft).keepingRoom(cardCount)
    }

    FullScreenSheet(
        title = if (container == null) "New ${draft.kind.displayName}" else "Edit ${draft.kind.displayName}",
        onDismiss = onDismiss,
        confirmLabel = if (container == null) "Create" else "Save",
        onConfirm = {
            if (container != null) {
                draft.apply(container)
                app.storage.containerDidChange(container)
            } else {
                val created = app.storage.createContainer(draft.name, draft.kind) { draft.apply(it) }
                onCreated(created)
            }
            onDismiss()
        },
    ) { padding ->
        Column(
            Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Box(Modifier.fillMaxWidth().height(160.dp), contentAlignment = Alignment.Center) {
                ContainerArtwork(draft.kind, draft.color, draft.style, Modifier.height(150.dp))
            }

            FormSection("Name") {
                FormTextField(draft.name, { v -> update { it.copy(name = v) } }, placeholder = draft.kind.displayName)
            }

            if (container == null) {
                FormSection("Kind") {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                        StorageKind.entries.forEach { kind ->
                            val selected = draft.kind == kind
                            Column(
                                Modifier.weight(1f).clip(RoundedCornerShape(10.dp))
                                    .background(if (selected) LorcanaGold.copy(alpha = 0.2f) else Color.Transparent)
                                    .border(1.dp, if (selected) LorcanaGold else Color.Transparent, RoundedCornerShape(10.dp))
                                    .clickable { update { it.withKind(kind) } }.padding(vertical = 6.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                            ) {
                                ContainerArtwork(kind, draft.color, StorageCoverStyle.CLASSIC, Modifier.height(36.dp))
                                Text(kind.displayName, style = MaterialTheme.typography.labelSmall, color = if (selected) LorcanaGold else Color.Gray, maxLines = 1)
                            }
                        }
                    }
                }
            }

            FormSection("Look") {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    StorageCoverColor.entries.forEach { color ->
                        val selected = draft.color == color
                        Box(
                            Modifier.size(32.dp).clip(CircleShape)
                                .background(Brush.linearGradient(listOf(color.highlight, color.shadow)))
                                .border(if (selected) 3.dp else 0.dp, Color.White, CircleShape)
                                .clickable { update { it.copy(color = color) } },
                            contentAlignment = Alignment.Center,
                        ) {
                            if (selected) Icon(Icons.Filled.Check, contentDescription = color.displayName, tint = color.trim, modifier = Modifier.size(16.dp))
                        }
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StorageCoverStyle.entries.forEach { style ->
                        val locked = style.requiresPro && !isPro
                        val selected = draft.style == style
                        Row(
                            Modifier.weight(1f).clip(RoundedCornerShape(8.dp))
                                .background(if (selected) LorcanaGold.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.08f))
                                .clickable(enabled = !locked) { update { it.copy(style = style) } }
                                .padding(vertical = 8.dp),
                            horizontalArrangement = Arrangement.Center,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            if (locked) Icon(Icons.Filled.Lock, contentDescription = "Pro", tint = Color.Gray, modifier = Modifier.size(12.dp))
                            Text(style.displayName, style = MaterialTheme.typography.labelMedium, color = if (locked) Color.Gray else Color.White, fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal)
                        }
                    }
                }
            }

            if (draft.kind.usesSlots) {
                val layout = draft.layout
                FormSection("Pages", footer = "${layout.pageCount} pages · ${layout.totalSlots} pockets") {
                    SegmentedPicker(BinderLayout.supportedPocketCounts, draft.pocketsPerPage, { v ->
                        update { d -> d.copy(pocketsPerPage = v).let { if (cardCount == 0) it.sizedForChecklist() else it } }
                    }, { "$it" })
                    val minSheets = draft.minimumSheets(cardCount)
                    StepperRow("Sheets", draft.sheetCount, minSheets..maxOf(250, minSheets), onValueChange = { v -> update { it.copy(sheetCount = v) } })
                    ToggleRow("Double-sided pages", draft.isDoubleSided, { v ->
                        update { d -> d.copy(isDoubleSided = v).let { if (cardCount == 0) it.sizedForChecklist() else it } }
                    })
                }
                val footer = when {
                    cardCount > 0 -> "Empty the binder to change its set checklist."
                    draft.hasFoilPockets -> "Each card gets a normal and a foil pocket side by side. Epic, Enchanted and Iconic cards only come as foils, so they get one."
                    else -> "Give every card in a set its own numbered pocket — a normal or a foil fills it. Only that set's cards can go in, and empty pockets show the cards you're missing."
                }
                FormSection(footer = footer) {
                    if (cardCount > 0) {
                        LabeledRow("Set checklist", draft.linkedSetName ?: "None")
                    } else if (isPro) {
                        MenuPickerRow(
                            "Set checklist",
                            listOf<String?>(null) + SetsDataManager.sets.map { it.name },
                            draft.linkedSetName,
                            { v -> update { it.copy(linkedSetName = v, hasFoilPockets = if (v == null) false else it.hasFoilPockets).sizedForChecklist() } },
                            { it ?: "None" },
                        )
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("Set checklist", color = Color.White, modifier = Modifier.weight(1f))
                            Text("PRO", style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold, color = Color.Black,
                                modifier = Modifier.clip(RoundedCornerShape(50)).background(LorcanaGold).padding(horizontal = 8.dp, vertical = 2.dp))
                        }
                    }
                    if (draft.linkedSetName != null) {
                        ToggleRow("Master set (normal + foil)", draft.hasFoilPockets, { v -> update { it.copy(hasFoilPockets = v).sizedForChecklist() } }, enabled = cardCount == 0)
                    }
                }
            } else {
                FormSection(
                    "Capacity",
                    footer = if (draft.tracksCapacity && cardCount > 0 && draft.capacity <= cardCount) {
                        "It already holds $cardCount cards, so it can't be made smaller. Take cards out first."
                    } else null,
                ) {
                    ToggleRow("Track capacity", draft.tracksCapacity, { v -> update { it.copy(tracksCapacity = v) } })
                    if (draft.tracksCapacity) {
                        StepperRow(
                            "Holds",
                            draft.capacity,
                            maxOf(10, cardCount)..maxOf(5000, cardCount),
                            step = if (draft.capacity >= 200) 100 else 10,
                            onValueChange = { v -> update { it.copy(capacity = v) } },
                            valueText = "${draft.capacity} cards",
                        )
                    }
                }
                if (draft.kind == StorageKind.DECK_BOX) {
                    val decks = app.decks.decks.filter { app.storage.deckBox(it.id) == null || it.id == container?.linkedDeckId }
                    if (decks.isNotEmpty()) {
                        FormSection(footer = "See which cards from the deck are still missing from this box.") {
                            MenuPickerRow(
                                "Holds deck",
                                listOf<String?>(null) + decks.map { it.id },
                                draft.linkedDeckId,
                                { v -> update { it.copy(linkedDeckId = v) } },
                                { id -> id?.let { app.decks.deck(it)?.name } ?: "None" },
                            )
                        }
                    }
                }
            }
        }
    }
}
