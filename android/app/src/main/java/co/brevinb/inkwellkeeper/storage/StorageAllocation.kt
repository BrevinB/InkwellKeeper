package co.brevinb.inkwellkeeper.storage

/** "Where is this card?" — how many copies of a card sit in one container. */
data class StorageAllocation(
    val containerId: String,
    val containerName: String,
    val kind: StorageKind,
    val quantity: Int,
    /** For binders, the 1-based page and pocket of each copy, in slot order. */
    val pockets: List<BinderPocket>,
) {
    data class BinderPocket(val page: Int, val pocket: Int)

    /** e.g. "p.3, pocket 5" or "p.3–7 (4 pockets)". */
    val pocketSummary: String?
        get() {
            val first = pockets.firstOrNull() ?: return null
            if (pockets.size == 1) return "p.${first.page}, pocket ${first.pocket}"
            val pages = pockets.map { it.page }.toSortedSet().toList()
            if (pages.size == 1) return "p.${first.page} (${pockets.size} pockets)"
            return "p.${pages.first()}–${pages.last()} (${pockets.size} pockets)"
        }
}
