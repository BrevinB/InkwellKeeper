//
//  ShareMilestone.swift
//  Inkwell Keeper
//
//  Describes a celebratory collection moment worth sharing. Pure value type: it owns the
//  copy and formatting for each milestone so `MilestoneShareCardView` stays presentation-only
//  and the logic can be unit-tested without any UI.
//

import Foundation

enum ShareMilestone: Equatable {
    /// A set fully completed (100%).
    case setCompleted(name: String)
    /// Progress toward completing a set. `percentage` is 0...1.
    case setProgress(name: String, percentage: Double)
    /// Total collection value crossed a notable amount.
    case collectionValue(amount: Double, currencyCode: String)
    /// A scanning haul — number of cards added in a session.
    case cardsScanned(count: Int)
    /// Total unique cards in the collection.
    case uniqueCards(count: Int)

    /// SF Symbol shown in the hero badge.
    var iconName: String {
        switch self {
        case .setCompleted: "checkmark.seal.fill"
        case .setProgress: "chart.pie.fill"
        case .collectionValue: "dollarsign.circle.fill"
        case .cardsScanned: "viewfinder.circle.fill"
        case .uniqueCards: "square.grid.3x3.fill"
        }
    }

    /// The large hero string (a number, percentage, or amount).
    var heroValue: String {
        switch self {
        case .setCompleted:
            "100%"
        case let .setProgress(_, percentage):
            percentage.formatted(.percent.precision(.fractionLength(0)))
        case let .collectionValue(amount, currencyCode):
            amount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)))
        case let .cardsScanned(count):
            count.formatted(.number)
        case let .uniqueCards(count):
            count.formatted(.number)
        }
    }

    /// Bold headline beneath the hero value.
    var headline: String {
        switch self {
        case let .setCompleted(name):
            "\(name) Complete!"
        case let .setProgress(name, _):
            name
        case .collectionValue:
            "Collection Value"
        case .cardsScanned:
            "Cards Scanned"
        case .uniqueCards:
            "Unique Cards Collected"
        }
    }

    /// Supporting line under the headline.
    var subtitle: String {
        switch self {
        case .setCompleted:
            "Every card collected — gotta catch 'em all."
        case .setProgress:
            "Working through the set…"
        case .collectionValue:
            "My Lorcana collection so far."
        case let .cardsScanned(count):
            count == 1 ? "Just added a new card." : "Added in one scanning session."
        case .uniqueCards:
            "Different cards and counting."
        }
    }

    /// Short analytics discriminator.
    var analyticsKind: String {
        switch self {
        case .setCompleted: "setCompleted"
        case .setProgress: "setProgress"
        case .collectionValue: "collectionValue"
        case .cardsScanned: "cardsScanned"
        case .uniqueCards: "uniqueCards"
        }
    }
}
