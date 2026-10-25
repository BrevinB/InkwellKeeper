package co.brevinb.inkwellkeeper.scan

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.brevinb.inkwellkeeper.data.Analytics
import co.brevinb.inkwellkeeper.model.CardVariant
import co.brevinb.inkwellkeeper.model.LorcanaCard
import java.util.UUID

data class ScannedCardEntry(
    val id: String = UUID.randomUUID().toString(),
    val card: LorcanaCard,
    val quantity: Int,
    val variant: CardVariant,
)

/**
 * The multi-scan tray: every recognized card accumulates here until it's reviewed and added.
 * Mirrors the batch half of the iOS `CameraManager`. Lives for the app session so switching
 * tabs doesn't lose a half-scanned pile.
 */
class ScanSession {
    val scannedCards = mutableStateListOf<ScannedCardEntry>()
    var isFoilMode by mutableStateOf(false)
    var isAutoScanEnabled by mutableStateOf(false)
    var isProcessing by mutableStateOf(false)
    var status by mutableStateOf<String?>(null)
    var lastEntry by mutableStateOf<ScannedCardEntry?>(null)
        private set
    /** Bumped on each add; drives the reveal animation. */
    var scanEventId by mutableIntStateOf(0)
        private set
    var pendingSetChoices by mutableStateOf<List<LorcanaCard>?>(null)

    val totalCount: Int get() = scannedCards.sumOf { it.quantity }

    private fun indexOf(card: LorcanaCard, variant: CardVariant) =
        scannedCards.indexOfFirst { it.card.name == card.name && it.card.setName == card.setName && it.variant == variant }

    /** Special printings keep their own variant; everything else is Normal or Foil per the toggle. */
    private fun variantFor(card: LorcanaCard): CardVariant =
        if (card.variant.isSpecialPrinting) card.variant else if (isFoilMode) CardVariant.FOIL else CardVariant.NORMAL

    fun add(card: LorcanaCard) {
        val variant = variantFor(card)
        val i = indexOf(card, variant)
        if (i >= 0) scannedCards[i] = scannedCards[i].copy(quantity = scannedCards[i].quantity + 1)
        else scannedCards += ScannedCardEntry(card = if (card.variant == variant) card else card.withVariant(variant), quantity = 1, variant = variant)
        lastEntry = scannedCards[indexOf(card, variant)]
        scanEventId++
        Analytics.send("scan.cardRecognized")
    }

    fun resolveSetChoice(card: LorcanaCard) {
        pendingSetChoices = null
        add(card)
    }

    fun undoLast() {
        val entry = lastEntry ?: return
        val i = indexOf(entry.card, entry.variant)
        if (i >= 0) {
            if (scannedCards[i].quantity > 1) scannedCards[i] = scannedCards[i].copy(quantity = scannedCards[i].quantity - 1)
            else scannedCards.removeAt(i)
        }
        lastEntry = null
    }

    /** Swaps the last scan for the right card, keeping its variant. */
    fun replaceLast(newCard: LorcanaCard) {
        val entry = lastEntry ?: return
        Analytics.send("scan.corrected", mapOf("from" to entry.card.name, "to" to newCard.name))
        undoLast()
        val variant = if (newCard.variant.isSpecialPrinting) newCard.variant else entry.variant
        val i = indexOf(newCard, variant)
        if (i >= 0) scannedCards[i] = scannedCards[i].copy(quantity = scannedCards[i].quantity + 1)
        else scannedCards += ScannedCardEntry(card = if (newCard.variant == variant) newCard else newCard.withVariant(variant), quantity = 1, variant = variant)
        lastEntry = scannedCards[indexOf(newCard, variant)]
    }

    fun replace(index: Int, newCard: LorcanaCard) {
        val old = scannedCards.getOrNull(index) ?: return
        scannedCards.removeAt(index)
        val variant = if (newCard.variant.isSpecialPrinting) newCard.variant else old.variant
        val i = indexOf(newCard, variant)
        if (i >= 0) scannedCards[i] = scannedCards[i].copy(quantity = scannedCards[i].quantity + old.quantity)
        else scannedCards.add(minOf(index, scannedCards.size), ScannedCardEntry(card = if (newCard.variant == variant) newCard else newCard.withVariant(variant), quantity = old.quantity, variant = variant))
    }

    fun setQuantity(index: Int, quantity: Int) {
        val entry = scannedCards.getOrNull(index) ?: return
        if (quantity <= 0) scannedCards.removeAt(index) else scannedCards[index] = entry.copy(quantity = quantity)
    }

    fun setVariant(index: Int, variant: CardVariant) {
        val entry = scannedCards.getOrNull(index) ?: return
        scannedCards[index] = entry.copy(variant = variant, card = entry.card.withVariant(variant))
    }

    fun remove(index: Int) {
        if (index in scannedCards.indices) scannedCards.removeAt(index)
    }

    fun clear() {
        scannedCards.clear()
        lastEntry = null
    }

    fun clearLastEntry() {
        lastEntry = null
    }
}
