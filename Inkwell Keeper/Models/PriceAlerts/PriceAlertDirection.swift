//
//  PriceAlertDirection.swift
//  Inkwell Keeper
//
//  Whether a price alert waits for a drop or a rise.
//

import SwiftUI

enum PriceAlertDirection: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Fires when the market price falls to or below the threshold — a buy signal.
    case below
    /// Fires when the market price rises to or above the threshold — a sell signal.
    case above

    var id: String { rawValue }

    var title: String {
        switch self {
        case .below: "Drops to"
        case .above: "Rises to"
        }
    }

    /// Editor tile heading.
    var tileTitle: String {
        switch self {
        case .below: String(localized: "Price drops")
        case .above: String(localized: "Price rises")
        }
    }

    var tileSubtitle: String {
        switch self {
        case .below: String(localized: "Buy when it's cheaper")
        case .above: String(localized: "Sell while it's hot")
        }
    }

    /// Green for a buying chance, orange for a selling one.
    var tint: Color {
        switch self {
        case .below: .green
        case .above: .orange
        }
    }

    var systemImage: String {
        switch self {
        case .below: "arrow.down.right"
        case .above: "arrow.up.right"
        }
    }
}
