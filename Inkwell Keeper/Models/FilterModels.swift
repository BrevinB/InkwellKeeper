//
//  FilterModels.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import Foundation

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

enum SortOption: CaseIterable {
    case name, cost, rarity, set
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .cost: return "Cost"
        case .rarity: return "Rarity"
        case .set: return "Set"
        }
    }
}
