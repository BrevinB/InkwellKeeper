//
//  SwiftDataModels.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI
import SwiftData
import Foundation

@Model
class CollectedCard {
    @Attribute(.unique) var cardId: String
    var name: String
    var cost: Int
    var type: String
    var rarity: String
    var setName: String
    var cardText: String
    var imageUrl: String
    var price: Double?
    var dateAdded: Date
    var quantity: Int
    var condition: String
    var isWishlisted: Bool
    var notes: String
    var variant: String?
    
    var cardRarity: CardRarity {
        get { CardRarity(rawValue: rarity) ?? .common }
        set { rarity = newValue.rawValue }
    }
    
    var cardVariant: CardVariant {
        get { 
            guard let variant = variant else { return .normal }
            return CardVariant(rawValue: variant) ?? .normal 
        }
        set { variant = newValue.rawValue }
    }
    
    init(cardId: String, name: String, cost: Int, type: String, rarity: CardRarity, setName: String, cardText: String = "", imageUrl: String, price: Double? = nil, quantity: Int = 1, condition: String = "Near Mint", isWishlisted: Bool = false, notes: String = "", variant: CardVariant = .normal) {
        self.cardId = cardId
        self.name = name
        self.cost = cost
        self.type = type
        self.rarity = rarity.rawValue
        self.setName = setName
        self.cardText = cardText
        self.imageUrl = imageUrl
        self.price = price
        self.dateAdded = Date()
        self.quantity = quantity
        self.condition = condition
        self.isWishlisted = isWishlisted
        self.notes = notes
        self.variant = variant.rawValue
    }
    
    var toLorcanaCard: LorcanaCard {
        LorcanaCard(
            id: cardId,
            name: name,
            cost: cost,
            type: type,
            rarity: cardRarity,
            setName: setName,
            cardText: cardText,
            imageUrl: imageUrl,
            price: price,
            variant: cardVariant
        )
    }
}

@Model
class CardSet {
    @Attribute(.unique) var setId: String
    var name: String
    var releaseDate: Date
    var totalCards: Int
    var setCode: String
    var imageUrl: String?
    
    @Relationship(deleteRule: .cascade, inverse: \CollectionStats.cardSet)
    var stats: CollectionStats?
    
    init(setId: String, name: String, releaseDate: Date, totalCards: Int, setCode: String, imageUrl: String? = nil) {
        self.setId = setId
        self.name = name
        self.releaseDate = releaseDate
        self.totalCards = totalCards
        self.setCode = setCode
        self.imageUrl = imageUrl
    }
}

@Model
class CollectionStats {
    var totalValue: Double
    var totalCards: Int
    var lastUpdated: Date
    var favoriteRarity: String?
    
    @Relationship(deleteRule: .nullify)
    var cardSet: CardSet?
    
    init(totalValue: Double = 0, totalCards: Int = 0, favoriteRarity: String? = nil) {
        self.totalValue = totalValue
        self.totalCards = totalCards
        self.lastUpdated = Date()
        self.favoriteRarity = favoriteRarity
    }
}

@Model
class PriceHistory {
    @Attribute(.unique) var id: UUID
    var cardId: String
    var price: Double
    var date: Date
    var source: String
    
    init(cardId: String, price: Double, source: String = "Unknown") {
        self.id = UUID()
        self.cardId = cardId
        self.price = price
        self.date = Date()
        self.source = source
    }
}
