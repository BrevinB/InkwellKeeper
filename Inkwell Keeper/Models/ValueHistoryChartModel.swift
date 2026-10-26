//
//  ValueHistoryChartModel.swift
//  Inkwell Keeper
//
//  The maths behind a value-over-time chart (a card's market price, or the whole
//  collection's value): a y-axis scaled to the data with ticks that read well even
//  for cards under $1, the high and low points worth calling out, and a one-line
//  storyline of what happened over the window.
//

import Foundation

struct ValueHistoryChartModel {
    /// Oldest first.
    let points: [PortfolioPoint]

    init(points: [PortfolioPoint]) {
        self.points = points.sorted { $0.date < $1.date }
    }

    var start: PortfolioPoint? { points.first }
    var latest: PortfolioPoint? { points.last }

    /// The highest point; the most recent one when the high repeats.
    var high: PortfolioPoint? {
        points.max { $0.value < $1.value || ($0.value == $1.value && $0.date < $1.date) }
    }

    /// The lowest point; the most recent one when the low repeats.
    var low: PortfolioPoint? {
        points.min { $0.value < $1.value || ($0.value == $1.value && $0.date > $1.date) }
    }

    var isUp: Bool {
        guard let start, let latest else { return true }
        return latest.value >= start.value
    }

    // MARK: - Change

    struct Change: Equatable {
        let amount: Double
        /// Nil when the window starts at zero, where a percentage means nothing.
        let percent: Double?
    }

    /// How far `point` is from where the window started.
    func change(at point: PortfolioPoint) -> Change? {
        guard let start else { return nil }
        let amount = point.value - start.value
        return Change(amount: amount, percent: start.value > 0 ? amount / start.value : nil)
    }

    /// The data point closest to a date, for scrubbing.
    func nearest(to date: Date) -> PortfolioPoint? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    // MARK: - Extremes

    /// The high and low are only worth marking when the line actually moved (a
    /// flat line would get two labels on top of each other) and they aren't just
    /// the window's two ends, which the header already covers.
    var markedExtremes: [Extreme] {
        guard points.count >= 3, let high, let low, let start, let latest,
              high.value - low.value >= max(high.value * 0.03, 0.01) else { return [] }
        let ends: Set<Date> = [start.date, latest.date]
        var marked: [Extreme] = []
        if !ends.contains(high.date) { marked.append(Extreme(kind: .high, point: high)) }
        if !ends.contains(low.date) { marked.append(Extreme(kind: .low, point: low)) }
        return marked
    }

    struct Extreme: Identifiable, Equatable {
        enum Kind: Equatable { case high, low }
        let kind: Kind
        let point: PortfolioPoint
        var id: Date { point.date }
    }

    // MARK: - Y axis

    /// The value range drawn, padded so the line and its labels don't touch the
    /// edges. It doesn't start at zero: a card going $0.20 → $0.35 is a 75% move
    /// and should look like one.
    var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let pad = max((high - low) * 0.2, high * 0.04, 0.02)
        return max(0, low - pad)...(high + pad)
    }

    /// Round-number ticks (e.g. $0.20, $0.25, $0.30) inside the domain: the finest
    /// step that gives no more than five labels.
    var axisValues: [Double] {
        Self.ticks(in: yDomain)
    }

    /// Cents on the axis whenever the ticks aren't whole dollars, so a card under
    /// $1 never reads "$0, $0, $0".
    var axisFractionDigits: Int {
        axisValues.allSatisfy { $0.rounded() == $0 } ? 0 : 2
    }

    static func ticks(in domain: ClosedRange<Double>) -> [Double] {
        let span = domain.upperBound - domain.lowerBound
        guard span > 0, span.isFinite else { return [domain.lowerBound] }
        // 1, 2 and 5 × powers of ten, never finer than a cent: 2.5 steps would need
        // a third decimal at cent scale.
        var exponent = max(-2, Int((log10(span / 5)).rounded(.down)) - 1)
        while true {
            let magnitude = pow(10, Double(exponent))
            for multiple in [1.0, 2, 5] {
                let step = multiple * magnitude
                let first = ((domain.lowerBound / step) - 1e-9).rounded(.up)
                let last = ((domain.upperBound / step) + 1e-9).rounded(.down)
                if last - first + 1 <= 5 {
                    return stride(from: first, through: last, by: 1).map { ($0 * step * 100).rounded() / 100 }
                }
            }
            exponent += 1
        }
    }

    // MARK: - Storyline

    /// One sentence on the shape of the window beyond start-vs-now, which the
    /// header already shows: where it peaked or bottomed out, or that it's sitting
    /// at its high or low right now. Nil when the line barely moved.
    func storyline(formatValue: (Double) -> String) -> String? {
        guard points.count >= 3, let high, let low, let latest, let start,
              high.value - low.value >= max(high.value * 0.03, 0.01) else { return nil }
        let dateFormat = Date.FormatStyle.dateTime.month(.abbreviated).day()

        if latest.date == high.date {
            return String(localized: "At its highest since \(start.date.formatted(dateFormat))")
        }
        if latest.date == low.date {
            return String(localized: "At its lowest since \(start.date.formatted(dateFormat))")
        }

        // A high or low on the window's first day is just the starting value,
        // which the header already compares against.
        let offHigh = high.value > 0 && high.date != start.date ? (high.value - latest.value) / high.value : 0
        let offLow = low.value > 0 && low.date != start.date ? (latest.value - low.value) / low.value : 0
        guard max(offHigh, offLow) >= 0.03 else { return nil }
        // Tell whichever turn matters more: a fall from a peak, or a recovery from a dip.
        if offHigh >= offLow {
            let below = offHigh.formatted(.percent.precision(.fractionLength(0)))
            return String(localized: "Peaked at \(formatValue(high.value)) on \(high.date.formatted(dateFormat)) · \(below) below that now")
        }
        let above = offLow.formatted(.percent.precision(.fractionLength(0)))
        return String(localized: "Bottomed at \(formatValue(low.value)) on \(low.date.formatted(dateFormat)) · \(above) above that now")
    }
}
