//
//  LoreCounterModels.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 2/14/26.
//

import SwiftUI

// Reuses InkColor from DeckModels.swift

struct PlayerLore: Identifiable {
    let id: UUID
    var name: String
    var lore: Int
    var inkColor: InkColor

    init(id: UUID = UUID(), name: String, lore: Int = 0, inkColor: InkColor = .amber) {
        self.id = id
        self.name = name
        self.lore = lore
        self.inkColor = inkColor
    }
}

struct LoreHistoryEntry: Identifiable {
    let id: UUID
    let playerName: String
    let previousValue: Int
    let newValue: Int
    let timestamp: Date

    init(id: UUID = UUID(), playerName: String, previousValue: Int, newValue: Int, timestamp: Date = Date()) {
        self.id = id
        self.playerName = playerName
        self.previousValue = previousValue
        self.newValue = newValue
        self.timestamp = timestamp
    }
}
