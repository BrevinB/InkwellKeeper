//
//  StorageContainer.swift
//  Inkwell Keeper
//
//  A physical place cards live: a binder, trove, deck box, storage box, or bin.
//  CloudKit-compliant: every attribute defaulted or optional, relationships optional.
//

import Foundation
import SwiftData

@Model
final class StorageContainer {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = StorageKind.binder.rawValue
    /// `StorageCoverStyle` raw value — the binder cover / box finish.
    var coverStyle: String = StorageCoverStyle.classic.rawValue
    /// `StorageCoverColor` raw value.
    var colorName: String = StorageCoverColor.amethyst.rawValue
    var sortOrder: Int = 0
    var createdDate: Date = Date.now
    var notes: String = ""

    // Binder configuration (ignored for other kinds).
    var pocketsPerPage: Int = 9
    /// Physical sheets in the binder. Double-sided sheets hold two pages each.
    var sheetCount: Int = 20
    var isDoubleSided: Bool = true

    /// Optional card limit for boxes and bins.
    var capacity: Int?

    /// When set, this binder is a checklist for one set: empty pockets map to that set's cards.
    var linkedSetName: String?
    /// Set binders only: a normal and a foil pocket for every card (see `SetChecklistLayout`).
    var hasFoilPockets: Bool = false
    /// When set, this deck box holds the given deck.
    var linkedDeckId: UUID?

    @Relationship(deleteRule: .cascade, inverse: \StoredCard.container)
    var items: [StoredCard]?

    var kind: StorageKind {
        get { StorageKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    var coverColor: StorageCoverColor {
        get { StorageCoverColor(rawValue: colorName) ?? .amethyst }
        set { colorName = newValue.rawValue }
    }

    var cover: StorageCoverStyle {
        get { StorageCoverStyle(rawValue: coverStyle) ?? .classic }
        set { coverStyle = newValue.rawValue }
    }

    var binderLayout: BinderLayout {
        BinderLayout(pocketsPerPage: pocketsPerPage, sheetCount: sheetCount, isDoubleSided: isDoubleSided)
    }

    /// Total copies stored here.
    var cardCount: Int {
        (items ?? []).reduce(0) { $0 + $1.quantity }
    }

    init(name: String, kind: StorageKind, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.createdDate = Date.now
        self.capacity = kind.defaultCapacity
    }
}
