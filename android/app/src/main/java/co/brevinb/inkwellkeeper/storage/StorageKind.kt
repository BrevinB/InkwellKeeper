package co.brevinb.inkwellkeeper.storage

/** The kinds of physical storage a collector can mirror in the app. Raw values match iOS. */
enum class StorageKind(val rawValue: String, val displayName: String, val defaultCapacity: Int?) {
    BINDER("binder", "Binder", null),
    TROVE("trove", "Trove", null),
    DECK_BOX("deckBox", "Deck Box", 100),
    STORAGE_BOX("storageBox", "Storage Box", 800),
    BULK_BIN("bulkBin", "Bulk Bin", null),
    OTHER("other", "Other", null);

    /** Binders hold cards in exact pocket positions; everything else is a loose pile. */
    val usesSlots: Boolean get() = this == BINDER

    companion object {
        fun fromRaw(raw: String?): StorageKind = entries.firstOrNull { it.rawValue == raw } ?: OTHER
    }
}
