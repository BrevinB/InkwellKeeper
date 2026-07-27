//
//  CardRarity.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

enum CardRarity: String, CaseIterable, Codable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case superRare = "Super Rare"
    case legendary = "Legendary"
    case epic = "Epic"
    case enchanted = "Enchanted"
    case iconic = "Iconic"
    case promo = "Promo"

    var displayName: String {
        return rawValue
    }

    var color: Color {
        switch self {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .superRare: return .purple
        case .legendary: return .orange
        case .enchanted: return .lorcanaGold
        case .epic: return .indigo
        case .iconic: return .lorcanaGold
        case .promo: return .pink
        }
    }

    var sortOrder: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .superRare: return 3
        case .legendary: return 4
        case .epic: return 5
        case .enchanted: return 6
        case .iconic: return 7
        case .promo: return 8
        }
    }
}
