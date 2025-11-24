//
//  TipProduct.swift
//  Inkwell Keeper
//
//  Tip jar product definitions
//

import Foundation

struct TipProduct: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let message: String

    static let tiers = [
        TipProduct(
            id: "inkwellkeeper.tip.small",
            title: "Small Tip",
            emoji: "☕️",
            message: "Buy me a coffee"
        ),
        TipProduct(
            id: "inkwellkeeper.tip.medium",
            title: "Medium Tip",
            emoji: "☕️☕️",
            message: "Buy me a large coffee"
        ),
        TipProduct(
            id: "inkwellkeeper.tip.large",
            title: "Large Tip",
            emoji: "🍕",
            message: "Buy me lunch"
        ),
        TipProduct(
            id: "inkwellkeeper.tip.love",
            title: "Love the app!!",
            emoji: "🍽️",
            message: "Buy me dinner"
        )
    ]
}
