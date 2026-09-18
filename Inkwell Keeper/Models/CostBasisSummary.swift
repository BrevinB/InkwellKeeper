//
//  CostBasisSummary.swift
//  Inkwell Keeper
//
//  What the collector paid against what their cards are worth now.
//

import Foundation

struct CostBasisSummary: Hashable, Sendable {
    /// Total paid for the copies that have a recorded purchase price.
    let costBasis: Double
    /// Current market value of those same copies, so the two sides compare
    /// like for like — counting unpriced or unrecorded cards on one side only
    /// would invent a gain.
    let marketValue: Double
    let recordedCopies: Int
    let unrecordedCopies: Int

    static let empty = Self(costBasis: 0, marketValue: 0, recordedCopies: 0, unrecordedCopies: 0)

    var gain: Double { marketValue - costBasis }

    var percentGain: Double? {
        guard costBasis > 0 else { return nil }
        return (gain / costBasis) * 100
    }

    var hasRecordedCost: Bool { recordedCopies > 0 }

    /// True when some of the collection is not represented, so the UI can say
    /// the figure covers only part of it.
    var isPartial: Bool { unrecordedCopies > 0 }
}

/// One card's contribution to the gain or loss, for the biggest-mover list.
struct CostBasisEntry: Identifiable, Hashable, Sendable {
    let cardKey: String
    let name: String
    let isFoil: Bool
    let quantity: Int
    let costBasis: Double
    let marketValue: Double

    var id: String { cardKey }
    var gain: Double { marketValue - costBasis }

    var percentGain: Double? {
        guard costBasis > 0 else { return nil }
        return (gain / costBasis) * 100
    }
}
