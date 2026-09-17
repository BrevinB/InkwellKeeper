//
//  TradeCalculatorViewModel.swift
//  Inkwell Keeper
//
//  Values both halves of a proposed trade against current market prices.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TradeCalculatorViewModel {
    enum Side: String, CaseIterable, Identifiable {
        case yours
        case theirs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .yours: "You give"
            case .theirs: "You get"
            }
        }
    }

    var yours = TradeSide()
    var theirs = TradeSide()
    private(set) var isPricing = false

    private let pricingService: PricingService

    init(pricingService: PricingService = .shared) {
        self.pricingService = pricingService
    }

    /// Positive when the other side is worth more — the direction a collector
    /// cares about when deciding whether to accept.
    var difference: Double { theirs.total - yours.total }

    var isEmpty: Bool { yours.lines.isEmpty && theirs.lines.isEmpty }

    /// Both halves need something in them before a trade means anything.
    var canConfirm: Bool { !yours.lines.isEmpty && !theirs.lines.isEmpty }

    /// Copies on either side with no market price, so the UI can say the totals
    /// are incomplete rather than quietly under-reporting.
    var unpricedCount: Int { yours.unpricedCount + theirs.unpricedCount }

    func add(_ card: LorcanaCard, to side: Side) {
        switch side {
        case .yours: yours.add(card)
        case .theirs: theirs.add(card)
        }
        Task { await refreshPrices() }
    }

    func remove(_ lineID: String, from side: Side) {
        switch side {
        case .yours: yours.remove(lineID)
        case .theirs: theirs.remove(lineID)
        }
    }

    func clear() {
        yours = TradeSide()
        theirs = TradeSide()
    }

    func refreshPrices() async {
        let cards = (yours.lines + theirs.lines).map(\.card)
        guard !cards.isEmpty else { return }

        isPricing = true
        defer { isPricing = false }

        let prices = await pricingService.fetchBulkMarketPrices(for: cards)
        yours.applyPrices(prices)
        theirs.applyPrices(prices)
    }
}
