//
//  ChartRange.swift
//  Inkwell Keeper
//
//  The time windows a value-history chart can zoom to (1W, 1M, …).
//

import Foundation

enum ChartRange: String, CaseIterable, Identifiable, Hashable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case all = "All"

    var id: Self { self }

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .threeMonths: 90
        case .sixMonths: 180
        case .all: nil
        }
    }

    var accessibilityName: String {
        switch self {
        case .week: String(localized: "1 week")
        case .month: String(localized: "1 month")
        case .threeMonths: String(localized: "3 months")
        case .sixMonths: String(localized: "6 months")
        case .all: String(localized: "All history")
        }
    }

    /// The points inside this window, counted back from the latest point.
    func filter(_ points: [PortfolioPoint]) -> [PortfolioPoint] {
        filter(points, date: \.date)
    }

    /// The items inside this window, counted back from the latest one.
    func filter<Item>(_ items: [Item], date: (Item) -> Date) -> [Item] {
        guard let days, let latest = items.map(date).max() else { return items }
        let cutoff = latest.addingTimeInterval(-Double(days) * 86_400)
        return items.filter { date($0) >= cutoff }
    }

    /// Windows worth offering: shorter than the history (otherwise they'd show the
    /// same thing as All) and holding at least two points. Empty when only All fits.
    static func available(for points: [PortfolioPoint]) -> [Self] {
        guard let first = points.map(\.date).min(), let last = points.map(\.date).max() else { return [] }
        let spanDays = last.timeIntervalSince(first) / 86_400
        let shorter = allCases.filter { range in
            guard let days = range.days else { return false }
            return Double(days) < spanDays && range.filter(points).count >= 2
        }
        return shorter.isEmpty ? [] : shorter + [.all]
    }
}
