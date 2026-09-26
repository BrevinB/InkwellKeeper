//
//  AIDeckFeedbackReason.swift
//  Inkwell Keeper
//
//  Why an AI deck result missed — the follow-up chips after a thumbs down.
//

import Foundation

enum AIDeckFeedbackReason: String, CaseIterable, Identifiable {
    case brokeRules
    case offTheme
    case weakCards
    case badCurve
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .brokeRules: "Broke deck rules"
        case .offTheme: "Didn't match my idea"
        case .weakCards: "Weak card choices"
        case .badCurve: "Bad cost curve"
        case .other: "Something else"
        }
    }

    /// What a retry tells the model to do differently.
    var retryGuidance: String {
        switch self {
        case .brokeRules:
            "It broke deck-building rules. Re-check every rule: 60 cards total, at most 4 copies of each card name, only the allowed inks (dual-ink cards need both) and legal sets."
        case .offTheme:
            "It didn't match what the player asked for. Follow the player's description and theme much more closely."
        case .weakCards:
            "The card choices were weak. Use stronger, proven competitive cards and tighter synergies."
        case .badCurve:
            "The cost curve was bad. Put most cards at cost 1-5 with a solid 2-3 cost core, only a few 6+ cards, and keep at least 70% inkable."
        case .other:
            "The player wasn't happy with it. Try a noticeably different approach."
        }
    }
}
