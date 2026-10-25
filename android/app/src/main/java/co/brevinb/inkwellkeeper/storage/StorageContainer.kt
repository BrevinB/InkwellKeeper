package co.brevinb.inkwellkeeper.storage

import kotlinx.serialization.Serializable
import java.util.UUID

/** A physical place cards live: a binder, trove, deck box, storage box, or bin. */
@Serializable
class StorageContainer(
    var id: String = UUID.randomUUID().toString(),
    var name: String = "",
    var kindRaw: String = StorageKind.BINDER.rawValue,
    var coverStyle: String = StorageCoverStyle.CLASSIC.rawValue,
    var colorName: String = StorageCoverColor.AMETHYST.rawValue,
    var sortOrder: Int = 0,
    var createdDate: Long = System.currentTimeMillis(),
    var notes: String = "",
    var pocketsPerPage: Int = 9,
    var sheetCount: Int = 20,
    var isDoubleSided: Boolean = true,
    var capacity: Int? = null,
    /** When set, this binder is a checklist for one set. */
    var linkedSetName: String? = null,
    /** Set binders only: a normal and a foil pocket for every card. */
    var hasFoilPockets: Boolean = false,
    /** When set, this deck box holds the given deck. */
    var linkedDeckId: String? = null,
    var items: MutableList<StoredCard> = mutableListOf(),
) {
    var kind: StorageKind
        get() = StorageKind.fromRaw(kindRaw)
        set(value) { kindRaw = value.rawValue }

    var coverColor: StorageCoverColor
        get() = StorageCoverColor.fromRaw(colorName)
        set(value) { colorName = value.rawValue }

    var cover: StorageCoverStyle
        get() = StorageCoverStyle.fromRaw(coverStyle)
        set(value) { coverStyle = value.rawValue }

    val binderLayout: BinderLayout get() = BinderLayout.of(pocketsPerPage, sheetCount, isDoubleSided)

    val cardCount: Int get() = items.sumOf { it.quantity }

    companion object {
        fun create(name: String, kind: StorageKind, sortOrder: Int) = StorageContainer(
            name = name,
            kindRaw = kind.rawValue,
            sortOrder = sortOrder,
            capacity = kind.defaultCapacity,
        )
    }
}
