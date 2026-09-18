//
//  PortfolioPoint.swift
//  Inkwell Keeper
//
//  One day on the collection value chart.
//

import Foundation

struct PortfolioPoint: Identifiable, Hashable, Sendable {
    let date: Date
    let value: Double

    var id: Date { date }
}
