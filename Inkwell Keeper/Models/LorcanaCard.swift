//
//  LorcanaCard.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import Foundation

// Helper for dynamic coding keys
struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(_ key: String) {
        self.stringValue = key
        self.intValue = nil
    }
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

enum CardVariant: String, Codable, CaseIterable, Hashable {
    case normal = "Normal"
    case foil = "Foil"
    case borderless = "Borderless"
    case promo = "Promo"
    case enchanted = "Enchanted"
    case epic = "Epic"
    case iconic = "Iconic"

    var displayName: String {
        return rawValue
    }

    var shortName: String {
        switch self {
        case .normal: return "N"
        case .foil: return "F"
        case .borderless: return "B"
        case .promo: return "P"
        case .enchanted: return "E"
        case .epic: return "EP"
        case .iconic: return "I"
        }
    }
}

struct LorcanaCard: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let cost: Int
    let type: String
    let rarity: CardRarity
    let setName: String
    let cardText: String
    let imageUrl: String
    let price: Double?
    let variant: CardVariant
    let cardNumber: Int?
    let uniqueId: String?
    
    // Additional properties for complete card data
    let inkwell: Bool?
    let strength: Int?
    let willpower: Int?
    let lore: Int?
    let franchise: String?
    let inkColor: String?
    let dateAdded: Date?
    
    // Custom decoding to handle missing id field and field name variations
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        
        // Helper function to decode with multiple possible keys
        func decodeField<T: Codable>(_ type: T.Type, keys: [String]) throws -> T {
            for key in keys {
                if let value = try container.decodeIfPresent(type, forKey: AnyCodingKey(key)) {
                    return value
                }
            }
            throw DecodingError.keyNotFound(AnyCodingKey(keys[0]), 
                DecodingError.Context(codingPath: decoder.codingPath, 
                debugDescription: "No value found for keys: \(keys)"))
        }
        
        func decodeOptionalField<T: Codable>(_ type: T.Type, keys: [String]) -> T? {
            for key in keys {
                if let value = try? container.decodeIfPresent(type, forKey: AnyCodingKey(key)) {
                    return value
                }
            }
            return nil
        }
        
        // Decode fields with multiple possible key names
        name = try decodeField(String.self, keys: ["name", "Name"])
        cost = try decodeField(Int.self, keys: ["cost", "Cost"])
        type = try decodeField(String.self, keys: ["type", "Type"])
        
        // Handle rarity - might be string that needs conversion
        if let rarityString = decodeOptionalField(String.self, keys: ["rarity", "Rarity"]) {
            rarity = CardRarity.fromString(rarityString)
        } else {
            rarity = try decodeField(CardRarity.self, keys: ["rarity", "Rarity"])
        }
        
        setName = try decodeField(String.self, keys: ["setName", "Set_Name", "set_name", "set"])
        cardText = decodeOptionalField(String.self, keys: ["cardText", "Body_Text", "text", "card_text"]) ?? ""
        imageUrl = try decodeField(String.self, keys: ["imageUrl", "Image", "image_url", "image"])
        price = decodeOptionalField(Double.self, keys: ["price", "Price"])
        
        // Handle variant
        if let variantString = decodeOptionalField(String.self, keys: ["variant", "Variant"]) {
            variant = CardVariant(rawValue: variantString) ?? .normal
        } else {
            variant = .normal
        }
        
        cardNumber = decodeOptionalField(Int.self, keys: ["cardNumber", "Card_Num", "card_number", "number"])
        uniqueId = decodeOptionalField(String.self, keys: ["uniqueId", "Unique_ID", "unique_id"])
        
        // Additional properties
        inkwell = decodeOptionalField(Bool.self, keys: ["inkwell", "Inkwell", "Inkable", "inkable"])
        strength = decodeOptionalField(Int.self, keys: ["strength", "Strength"])
        willpower = decodeOptionalField(Int.self, keys: ["willpower", "Willpower"])
        lore = decodeOptionalField(Int.self, keys: ["lore", "Lore"])
        franchise = decodeOptionalField(String.self, keys: ["franchise", "Franchise"])
        inkColor = decodeOptionalField(String.self, keys: ["Color", "inkColor", "Ink_Color", "ink_color"])
        dateAdded = decodeOptionalField(Date.self, keys: ["dateAdded", "date_added"])
        
        // Generate ID if not present
        if let existingId = decodeOptionalField(String.self, keys: ["id", "ID"]) {
            id = existingId
        } else {
            // Generate ID from available data
            let setCode = setName.prefix(3).uppercased().replacingOccurrences(of: " ", with: "")
            let cardNum = cardNumber ?? 0
            let variantCode = variant.shortName
            let safeName = name.replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "-", with: "_")
            id = "\(setCode)_\(String(format: "%03d", cardNum))_\(variantCode)_\(safeName)"
        }
    }
    
    init(id: String = UUID().uuidString, name: String, cost: Int, type: String, rarity: CardRarity, setName: String, cardText: String = "", imageUrl: String, price: Double? = nil, variant: CardVariant = .normal, cardNumber: Int? = nil, uniqueId: String? = nil, inkwell: Bool? = nil, strength: Int? = nil, willpower: Int? = nil, lore: Int? = nil, franchise: String? = nil, inkColor: String? = nil, dateAdded: Date? = nil) {
        self.id = id
        self.name = name
        self.cost = cost
        self.type = type
        self.rarity = rarity
        self.setName = setName
        self.cardText = cardText
        self.imageUrl = imageUrl
        self.price = price
        self.variant = variant
        self.cardNumber = cardNumber
        self.uniqueId = uniqueId
        self.inkwell = inkwell
        self.strength = strength
        self.willpower = willpower
        self.lore = lore
        self.franchise = franchise
        self.inkColor = inkColor
        self.dateAdded = dateAdded
    }
}
