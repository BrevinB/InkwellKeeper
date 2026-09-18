//
//  PaywallContext.swift
//  Inkwell Keeper
//
//  What the paywall leads with, based on where it was opened from.
//
//  Someone who tapped a blurred collection-value chart and someone who tapped
//  "Ask the AI" want different things, and a single pitch can only speak to one
//  of them. Each context leads with what the reader just reached for, then
//  lists the rest so the full subscription is still visible.
//

import Foundation

struct PaywallContext: Sendable {
    /// Matches the `source` string the surface passes, which is also the
    /// analytics discriminator.
    let source: String
    let heroIcon: String
    let headline: String
    let subheadline: String
    /// Shown first, with descriptions.
    let leadFeatures: [PaywallFeature]

    /// Everything else Pro includes, listed compactly beneath.
    var supportingFeatures: [PaywallFeature] {
        let leadIDs = Set(leadFeatures.map(\.id))
        return PaywallFeature.all.filter { !leadIDs.contains($0.id) }
    }
}

extension PaywallContext {
    static func forSource(_ source: String) -> Self {
        switch source {
        case "portfolioHistory": .portfolio
        case "tradeCalculator": .trades
        case "deckBuilder", "deckCompleter", "deckStrategy": .deckBuilding
        case "rulesTab", "cardAsk": .rules
        default: .general
        }
    }

    /// Reached from the Stats cards — a collector looking at their own numbers.
    static let portfolio = Self(
        source: "portfolioHistory",
        heroIcon: "chart.xyaxis.line",
        headline: "Know what your collection is worth",
        subheadline: "Track its value over time, see what moved this week, and what you're up on.",
        leadFeatures: [.valueHistory, .movers, .costBasis]
    )

    /// Reached from the trade calculator — someone mid-deal.
    static let trades = Self(
        source: "tradeCalculator",
        heroIcon: "arrow.left.arrow.right.circle.fill",
        headline: "Never lose a trade again",
        subheadline: "Value both sides before you agree, then share the result.",
        leadFeatures: [.tradeCalculator, .valueHistory, .highsAndLows]
    )

    /// Reached from the AI deck tools.
    static let deckBuilding = Self(
        source: "deckBuilder",
        heroIcon: "wand.and.stars",
        headline: "Build better decks, faster",
        subheadline: "Describe a deck and get one back — or let AI finish the one you started.",
        leadFeatures: [.deckBuilder, .strategyGuides, .rulesExpert]
    )

    /// Reached from the rules assistant.
    static let rules = Self(
        source: "rulesTab",
        heroIcon: "book.circle.fill",
        headline: "Settle any rules question",
        subheadline: "Instant answers with rule citations, so the game keeps moving.",
        leadFeatures: [.rulesExpert, .cardAnalysis, .shareRulings]
    )

    /// No particular surface — lead with the collection, which is what most
    /// people open the app to do.
    static let general = Self(
        source: "general",
        heroIcon: "sparkles",
        headline: "Inkwell Pro",
        subheadline: "Everything you need to track what you own and play your best.",
        leadFeatures: [.valueHistory, .tradeCalculator, .rulesExpert]
    )
}
