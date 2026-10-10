//
//  StoredCard.swift
//  Inkwell Keeper
//
//  Copies of one card sitting in a StorageContainer. Like DeckCard, this snapshots
//  the card's display fields and matches the collection by identity key rather than
//  a relationship, so it survives CollectedCard duplicate-merges and keeps the
//  CloudKit schema simple.
//
//  In a binder, one row is one pocket (quantity 1, `slotIndex` set).
//  In a box, one row holds every copy of that card (`slotIndex` nil).
//

import Foundation
import SwiftData

@Model
final class StoredCard {
    var id: UUID = UUID()
    var cardId: String = ""
    var name: String = ""
    var cost: Int = 0
    var type: String = ""
    var rarity: String = ""
    var setName: String = ""
    var imageUrl: String = ""
    var inkColor: String?
    var variant: String = CardVariant.normal.rawValue
    var cardNumber: Int?
    var uniqueId: String?
    var price: Double?

    var quantity: Int = 1
    /// Global pocket index inside a binder (see `BinderLayout`); nil for boxes.
    var slotIndex: Int?
    var dateStored: Date = Date.now

    /// For cards pulled into a deck box: the container and binder pocket they came
    /// from, so taking the deck apart can put each copy back where it was.
    var originContainerId: UUID?
    var originSlot: Int?

    var container: StorageContainer?

    var cardVariant: CardVariant {
        CardVariant(rawValue: variant) ?? .normal
    }

    /// Same key format as `CollectionManager.identityKey(for:)`.
    var identityKey: String {
        if let uniqueId, !uniqueId.isEmpty {
            return "\(uniqueId)|\(variant)"
        }
        return "\(name)|\(setName)|\(variant)"
    }

    init(from card: LorcanaCard, quantity: Int = 1, slotIndex: Int? = nil) {
        self.id = UUID()
        self.cardId = card.id
        self.name = card.name
        self.cost = card.cost
        self.type = card.type
        self.rarity = card.rarity.rawValue
        self.setName = card.setName
        self.imageUrl = card.imageUrl
        self.inkColor = card.inkColor
        self.variant = card.variant.rawValue
        self.cardNumber = card.cardNumber
        self.uniqueId = card.uniqueId
        self.price = card.price
        self.quantity = quantity
        self.slotIndex = slotIndex
        self.dateStored = Date.now
    }

    var toLorcanaCard: LorcanaCard {
        LorcanaCard(
            id: cardId,
            name: name,
            cost: cost,
            type: type,
            rarity: CardRarity(rawValue: rarity) ?? .common,
            setName: setName,
            imageUrl: imageUrl,
            price: price,
            variant: cardVariant,
            cardNumber: cardNumber,
            uniqueId: uniqueId,
            inkColor: inkColor
        )
    }
}
