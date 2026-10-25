package co.brevinb.inkwellkeeper.model

enum class DeckArchetype(val rawValue: String) {
    AGGRO("Aggro"),
    MIDRANGE("Midrange"),
    CONTROL("Control"),
    COMBO("Combo"),
    RAMP("Ramp"),
    OTHER("Other");

    companion object {
        fun fromRaw(raw: String?): DeckArchetype? = entries.firstOrNull { it.rawValue == raw }
    }
}
