//
//  ContainerDraft.swift
//  Inkwell Keeper
//
//  Editable copy of a container's settings, so the editor can be cancelled
//  without touching the saved model.
//

import Foundation

struct ContainerDraft: Equatable {
    var name = ""
    var kind: StorageKind = .binder {
        didSet {
            if oldValue != kind, let capacity = kind.defaultCapacity {
                self.capacity = capacity
                tracksCapacity = true
            }
        }
    }
    var color: StorageCoverColor = .amethyst
    var style: StorageCoverStyle = .classic
    var pocketsPerPage = 9
    var sheetCount = 20
    var isDoubleSided = true
    var tracksCapacity = false
    var capacity = 100
    var linkedSetName: String?
    var hasFoilPockets = false
    var linkedDeckId: UUID?

    init() {}

    init(container: StorageContainer) {
        name = container.name
        kind = container.kind
        color = container.coverColor
        style = container.cover
        pocketsPerPage = container.pocketsPerPage
        sheetCount = container.sheetCount
        isDoubleSided = container.isDoubleSided
        tracksCapacity = container.capacity != nil
        capacity = container.capacity ?? container.kind.defaultCapacity ?? 100
        linkedSetName = container.linkedSetName
        hasFoilPockets = container.hasFoilPockets
        linkedDeckId = container.linkedDeckId
    }

    /// Smallest sheet count that still holds `cardCount` cards with this page setup.
    func minimumSheets(for cardCount: Int) -> Int {
        cardCount > 0 ? layout.sheetsNeeded(for: cardCount) : 1
    }

    /// Grows the draft back up if an edit would leave less room than the cards already
    /// inside — e.g. switching a full 9-pocket binder to 4 pockets adds sheets.
    mutating func keepRoom(for cardCount: Int) {
        if kind.usesSlots {
            if layout.totalSlots < cardCount {
                sheetCount = layout.sheetsNeeded(for: cardCount)
            }
        } else if tracksCapacity, capacity < cardCount {
            capacity = cardCount
        }
    }

    var layout: BinderLayout {
        BinderLayout(pocketsPerPage: pocketsPerPage, sheetCount: sheetCount, isDoubleSided: isDoubleSided)
    }

    func apply(to container: StorageContainer) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { container.name = trimmed }
        container.kind = kind
        container.coverColor = color
        container.cover = style
        container.pocketsPerPage = pocketsPerPage
        container.sheetCount = sheetCount
        container.isDoubleSided = isDoubleSided
        container.capacity = kind.usesSlots || !tracksCapacity ? nil : capacity
        container.linkedSetName = kind.usesSlots ? linkedSetName : nil
        container.hasFoilPockets = kind.usesSlots && linkedSetName != nil && hasFoilPockets
        container.linkedDeckId = kind == .deckBox ? linkedDeckId : nil
    }
}
