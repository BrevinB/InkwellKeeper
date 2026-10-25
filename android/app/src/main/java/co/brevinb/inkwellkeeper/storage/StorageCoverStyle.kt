package co.brevinb.inkwellkeeper.storage

/** Finishes for binder covers and boxes. Two are free; the showier ones are Pro. */
enum class StorageCoverStyle(val rawValue: String, val displayName: String, val requiresPro: Boolean) {
    CLASSIC("classic", "Classic", false),
    LEATHER("leather", "Stitched", false),
    STARLIGHT("starlight", "Starlight", true),
    HOLOFOIL("holofoil", "Holofoil", true);

    companion object {
        fun fromRaw(raw: String?): StorageCoverStyle = entries.firstOrNull { it.rawValue == raw } ?: CLASSIC
    }
}
