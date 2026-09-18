//
//  PaywallFeature.swift
//  Inkwell Keeper
//
//  One thing Pro unlocks, as shown on the paywall.
//

import Foundation

struct PaywallFeature: Identifiable, Hashable, Sendable {
    let id: String
    let icon: String
    let title: String
    let description: String
}

extension PaywallFeature {
    // MARK: - Collection

    static let valueHistory = Self(
        id: "valueHistory",
        icon: "chart.xyaxis.line",
        title: "Collection Value History",
        description: "Watch what your collection is worth rise and fall, day by day"
    )

    static let movers = Self(
        id: "movers",
        icon: "arrow.up.arrow.down",
        title: "Biggest Movers",
        description: "See which of your cards gained and lost the most each week"
    )

    static let highsAndLows = Self(
        id: "highsAndLows",
        icon: "arrow.up.to.line",
        title: "Highs & Lows",
        description: "Spot the cards sitting at the top or bottom of their price range"
    )

    static let costBasis = Self(
        id: "costBasis",
        icon: "tag",
        title: "Cost vs Value",
        description: "Record what you paid and track the gain or loss on every card"
    )

    static let foilPremium = Self(
        id: "foilPremium",
        icon: "sparkle",
        title: "Foil Premium",
        description: "Compare what your foils are worth against everything else"
    )

    static let tradeCalculator = Self(
        id: "tradeCalculator",
        icon: "arrow.left.arrow.right",
        title: "Trade Calculator",
        description: "Value both sides of a trade — scan cards straight in — and share the result"
    )

    // MARK: - AI

    static let rulesExpert = Self(
        id: "rulesExpert",
        icon: "sparkles",
        title: "AI Rules Expert",
        description: "Ask any rules question and get an answer with rule citations"
    )

    static let deckBuilder = Self(
        id: "deckBuilder",
        icon: "wand.and.stars",
        title: "AI Deck Builder",
        description: "Generate a deck from a description, or finish one you started"
    )

    static let cardAnalysis = Self(
        id: "cardAnalysis",
        icon: "rectangle.stack.badge.plus",
        title: "Card Analysis",
        description: "Attach up to 4 cards to ask about a specific interaction"
    )

    static let strategyGuides = Self(
        id: "strategyGuides",
        icon: "map",
        title: "AI Strategy Guides",
        description: "Get a game plan for any deck — matchups, mulligans, win conditions"
    )

    static let shareRulings = Self(
        id: "shareRulings",
        icon: "square.and.arrow.up",
        title: "Share Rulings",
        description: "Turn any answer into an image and settle the debate in the group chat"
    )

    static let chatHistory = Self(
        id: "chatHistory",
        icon: "bubble.left.and.bubble.right",
        title: "Chat History",
        description: "Save, pin, and revisit your past conversations"
    )

    /// Everything Pro includes, in the order used when no context applies.
    static let all: [Self] = [
        .valueHistory, .movers, .highsAndLows, .costBasis, .foilPremium,
        .tradeCalculator, .rulesExpert, .deckBuilder, .cardAnalysis,
        .strategyGuides, .shareRulings, .chatHistory
    ]
}
