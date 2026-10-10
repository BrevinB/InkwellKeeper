//
//  StorageCoverColor.swift
//  Inkwell Keeper
//
//  Cover colors for binders and boxes: the six inks plus a couple of neutrals.
//

import SwiftUI

enum StorageCoverColor: String, CaseIterable, Identifiable, Sendable {
    case amber
    case amethyst
    case emerald
    case ruby
    case sapphire
    case steel
    case midnight
    case ivory

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// The lighter tone used at the top-left of a cover gradient.
    var highlight: Color {
        switch self {
        case .amber: Color(red: 0.96, green: 0.70, blue: 0.25)
        case .amethyst: Color(red: 0.62, green: 0.40, blue: 0.85)
        case .emerald: Color(red: 0.25, green: 0.72, blue: 0.45)
        case .ruby: Color(red: 0.88, green: 0.28, blue: 0.32)
        case .sapphire: Color(red: 0.28, green: 0.55, blue: 0.92)
        case .steel: Color(red: 0.66, green: 0.70, blue: 0.76)
        case .midnight: Color(red: 0.22, green: 0.24, blue: 0.40)
        case .ivory: Color(red: 0.95, green: 0.91, blue: 0.82)
        }
    }

    /// The deeper tone used at the bottom-right of a cover gradient and for spines.
    var shadow: Color {
        switch self {
        case .amber: Color(red: 0.62, green: 0.38, blue: 0.08)
        case .amethyst: Color(red: 0.30, green: 0.14, blue: 0.48)
        case .emerald: Color(red: 0.07, green: 0.38, blue: 0.22)
        case .ruby: Color(red: 0.50, green: 0.08, blue: 0.14)
        case .sapphire: Color(red: 0.08, green: 0.24, blue: 0.55)
        case .steel: Color(red: 0.30, green: 0.34, blue: 0.40)
        case .midnight: Color(red: 0.06, green: 0.07, blue: 0.16)
        case .ivory: Color(red: 0.70, green: 0.64, blue: 0.52)
        }
    }

    /// Text and trim drawn on top of the cover.
    var trim: Color {
        self == .ivory || self == .steel ? .lorcanaDark : .lorcanaGold
    }
}
