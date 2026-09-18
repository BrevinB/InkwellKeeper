//
//  PortfolioSummary.swift
//  Inkwell Keeper
//
//  Headline numbers shown above the collection value chart.
//

import Foundation

struct PortfolioSummary: Hashable, Sendable {
    let currentValue: Double
    let change: Double
    /// Nil when the window opens at zero, where a percentage has no meaning.
    let percentChange: Double?

    static let empty = Self(currentValue: 0, change: 0, percentChange: nil)
}
