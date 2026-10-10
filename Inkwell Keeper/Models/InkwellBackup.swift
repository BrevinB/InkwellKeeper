//
//  InkwellBackup.swift
//  Inkwell Keeper
//
//  The app's own JSON backup: every card in the collection, plus (since storage
//  arrived) every binder and box and which cards sit where. Written by Export's
//  "JSON Backup" and read back by Import.
//
//  Keys match the original export exactly, so backups made before storage existed
//  still read; `storage` is simply absent from those.
//

import Foundation

struct InkwellBackup: Codable {
    let exportDate: String
    let appVersion: String
    let totalCards: Int
    let totalQuantity: Int
    let cards: [Card]
    /// Binders and boxes with their contents. Nil in backups from before storage.
    var storage: [Container]?

    /// One printing in the collection and how many are owned.
    struct Card: Codable {
        let id: String
        let name: String
        let setName: String
        let cardNumber: Int?
        let uniqueId: String?
        let variant: String
        let quantity: Int
        let rarity: String
        let inkColor: String?
        let cardType: String
        let cost: Int
        let strength: Int?
        let willpower: Int?
        let lore: Int?
        let inkwell: Bool?
        let franchise: String?
        let price: Double?
        let condition: String?
        let notes: String?
        let dateAdded: String?
        let imageUrl: String
    }

    /// A binder or box and everything in it.
    struct Container: Codable {
        let id: UUID
        let name: String
        let kind: String
        let coverStyle: String
        let colorName: String
        let sortOrder: Int
        let notes: String
        let pocketsPerPage: Int
        let sheetCount: Int
        let isDoubleSided: Bool
        let capacity: Int?
        let linkedSetName: String?
        let hasFoilPockets: Bool
        let linkedDeckId: UUID?
        let items: [Item]
    }

    /// Copies of one card in a container: one pocket of a binder, or every copy in a box.
    struct Item: Codable {
        let cardId: String
        let name: String
        let cost: Int
        let type: String
        let rarity: String
        let setName: String
        let imageUrl: String
        let inkColor: String?
        let variant: String
        let cardNumber: Int?
        let uniqueId: String?
        let price: Double?
        let quantity: Int
        let slotIndex: Int?
        let originContainerId: UUID?
        let originSlot: Int?
    }

    /// True when the text is one of this app's backups rather than another app's file.
    static func looksLikeBackup(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("{")
            && trimmed.contains("\"appVersion\"")
            && trimmed.contains("\"exportDate\"")
            && trimmed.contains("\"cards\"")
    }

    static func decode(_ text: String) -> Self? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
}

extension InkwellBackup.Item {
    init(_ row: StoredCard) {
        self.init(
            cardId: row.cardId,
            name: row.name,
            cost: row.cost,
            type: row.type,
            rarity: row.rarity,
            setName: row.setName,
            imageUrl: row.imageUrl,
            inkColor: row.inkColor,
            variant: row.variant,
            cardNumber: row.cardNumber,
            uniqueId: row.uniqueId,
            price: row.price,
            quantity: row.quantity,
            slotIndex: row.slotIndex,
            originContainerId: row.originContainerId,
            originSlot: row.originSlot
        )
    }

    /// The card this row holds, as the rest of the app sees cards.
    var card: LorcanaCard {
        LorcanaCard(
            id: cardId,
            name: name,
            cost: cost,
            type: type,
            rarity: CardRarity(rawValue: rarity) ?? .common,
            setName: setName,
            imageUrl: imageUrl,
            price: price,
            variant: CardVariant(rawValue: variant) ?? .normal,
            cardNumber: cardNumber,
            uniqueId: uniqueId,
            inkColor: inkColor
        )
    }
}

extension InkwellBackup.Container {
    init(_ container: StorageContainer) {
        self.init(
            id: container.id,
            name: container.name,
            kind: container.kindRaw,
            coverStyle: container.coverStyle,
            colorName: container.colorName,
            sortOrder: container.sortOrder,
            notes: container.notes,
            pocketsPerPage: container.pocketsPerPage,
            sheetCount: container.sheetCount,
            isDoubleSided: container.isDoubleSided,
            capacity: container.capacity,
            linkedSetName: container.linkedSetName,
            hasFoilPockets: container.hasFoilPockets,
            linkedDeckId: container.linkedDeckId,
            items: (container.items ?? []).map(InkwellBackup.Item.init)
        )
    }
}
