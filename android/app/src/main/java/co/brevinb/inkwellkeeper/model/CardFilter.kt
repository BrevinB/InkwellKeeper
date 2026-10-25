package co.brevinb.inkwellkeeper.model

enum class CardFilter(val displayName: String, val type: String?) {
    ALL("All", null),
    CHARACTER("Characters", "Character"),
    ACTION("Actions", "Action"),
    ITEM("Items", "Item"),
    SONG("Songs", "Song"),
}
