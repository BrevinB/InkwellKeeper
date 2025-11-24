//
//  FilterModels.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import Foundation
import SwiftUI

enum CardFilter: CaseIterable {
    case all, character, action, item, song

    var displayName: String {
        switch self {
        case .all: return "All"
        case .character: return "Characters"
        case .action: return "Actions"
        case .item: return "Items"
        case .song: return "Songs"
        }
    }
}

enum InkColorFilter: String, CaseIterable {
    case all = "All"
    case amber = "Amber"
    case amethyst = "Amethyst"
    case emerald = "Emerald"
    case ruby = "Ruby"
    case sapphire = "Sapphire"
    case steel = "Steel"

    var displayName: String {
        return rawValue
    }

    var color: Color {
        switch self {
        case .all: return .gray
        case .amber: return Color(red: 1.0, green: 0.75, blue: 0.0)
        case .amethyst: return Color(red: 0.58, green: 0.29, blue: 0.78)
        case .emerald: return Color(red: 0.0, green: 0.7, blue: 0.4)
        case .ruby: return Color(red: 0.9, green: 0.1, blue: 0.26)
        case .sapphire: return Color(red: 0.12, green: 0.46, blue: 0.82)
        case .steel: return Color(red: 0.5, green: 0.5, blue: 0.5)
        }
    }

    var icon: String {
        switch self {
        case .all: return "circle.grid.2x2"
        case .amber: return "sun.max.fill"
        case .amethyst: return "sparkles"
        case .emerald: return "leaf.fill"
        case .ruby: return "flame.fill"
        case .sapphire: return "drop.fill"
        case .steel: return "shield.fill"
        }
    }
}

enum SortOption: CaseIterable {
    case recentlyAdded, name, cost, rarity, set

    var displayName: String {
        switch self {
        case .recentlyAdded: return "Recently Added"
        case .name: return "Name"
        case .cost: return "Cost"
        case .rarity: return "Rarity"
        case .set: return "Set"
        }
    }
}
