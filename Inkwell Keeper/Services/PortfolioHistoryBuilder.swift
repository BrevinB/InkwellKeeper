//
//  PortfolioHistoryBuilder.swift
//  Inkwell Keeper
//
//  Turns the backend's per-printing price series into one daily value series
//  for the whole collection. Pure functions so the maths can be tested without
//  a network or a model container.
//

import Foundation

enum PortfolioHistoryBuilder {
    /// Daily value of the given holdings over the window the series cover.
    ///
    /// Quantities are held at today's numbers rather than replayed from
    /// `dateAdded`: most collections arrive through a single bulk import, which
    /// stamps every card with the same date and would draw a cliff out of an
    /// import rather than out of the market. Holding quantities constant makes
    /// the line mean "what the cards I own now were worth", so a rise is market
    /// movement and nothing else.
    ///
    /// A printing whose series starts partway through the window (a recent set,
    /// or one the backend only began tracking later) carries its earliest known
    /// price backwards. Leaving it at zero instead would draw a jump on the day
    /// tracking started, which reads as a gain that never happened.
    static func dailyValues(
        holdings: [PortfolioHolding],
        series: [String: [PricingService.PortfolioPricePoint]]
    ) -> [PortfolioPoint] {
        let priced = holdings.filter { holding in
            holding.quantity > 0 && !(series[holding.cardKey] ?? []).isEmpty
        }
        guard !priced.isEmpty else { return [] }

        let allDays = priced.flatMap { series[$0.cardKey]?.map(\.day) ?? [] }
        guard let firstDay = windowStart(observationDays: allDays),
              let lastDay = allDays.max() else { return [] }

        // Walk every holding forward together, one day at a time, so each
        // series is traversed once rather than re-searched per day.
        var cursors = [Int](repeating: 0, count: priced.count)
        var points: [PortfolioPoint] = []
        points.reserveCapacity(lastDay - firstDay + 1)

        for day in firstDay...lastDay {
            var total = 0.0
            for (index, holding) in priced.enumerated() {
                guard let cardSeries = series[holding.cardKey], !cardSeries.isEmpty else { continue }
                var cursor = cursors[index]
                while cursor + 1 < cardSeries.count, cardSeries[cursor + 1].day <= day {
                    cursor += 1
                }
                cursors[index] = cursor
                total += cardSeries[cursor].price * Double(holding.quantity)
            }
            points.append(PortfolioPoint(date: date(fromEpochDay: day), value: total))
        }
        return points
    }

    /// Longest gap tolerated inside the charted window, in days.
    static let maxObservationGapDays = 14

    /// Where the chart should open: after the last long gap in the data, not
    /// at the oldest point on record.
    ///
    /// The backend holds a handful of stray early observations — TFC-1 has one
    /// on 2 March 2026 and then nothing until 13 May. Opening the window in
    /// March would carry that lone value flat across ten weeks and then show
    /// its correction as a jump, inventing a gain out of a gap in the data.
    static func windowStart(
        observationDays: [Int],
        maxGap: Int = maxObservationGapDays
    ) -> Int? {
        let sorted = Set(observationDays).sorted()
        guard var start = sorted.first else { return nil }
        for index in sorted.indices.dropLast() where sorted[index + 1] - sorted[index] > maxGap {
            start = sorted[index + 1]
        }
        return start
    }

    /// Headline value and movement across the charted window.
    static func summary(for points: [PortfolioPoint]) -> PortfolioSummary {
        guard let first = points.first, let last = points.last else { return .empty }
        let change = last.value - first.value
        let percent = first.value > 0 ? (change / first.value) * 100 : nil
        return PortfolioSummary(currentValue: last.value, change: change, percentChange: percent)
    }

    /// Movement over the trailing `days`, for the "up $34 this week" line.
    static func change(in points: [PortfolioPoint], overTrailing days: Int) -> Double? {
        guard let last = points.last, points.count > 1 else { return nil }
        let startIndex = max(0, points.count - 1 - days)
        return last.value - points[startIndex].value
    }

    /// Epoch days are counted in UTC, so anchoring each one at midday UTC keeps
    /// it on the same calendar date once it is rendered in the reader's own
    /// time zone. Anchoring at midnight instead moved every point back a day
    /// anywhere west of UTC — enough, at a month boundary, to put the wrong
    /// month on the locked card.
    static func date(fromEpochDay day: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(day) * 86_400 + 43_200)
    }
}
