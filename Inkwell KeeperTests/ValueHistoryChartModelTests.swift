//
//  ValueHistoryChartModelTests.swift
//  Inkwell KeeperTests
//
//  The value-history chart's axis, callouts and storyline: cheap cards must get a
//  readable axis, and the chart should only call out movements that happened.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct ValueHistoryChartModelTests {
    private let start = Date(timeIntervalSince1970: 1_780_000_000)

    private func series(_ values: [Double], everyDays days: Double = 1) -> [PortfolioPoint] {
        values.enumerated().map { index, value in
            PortfolioPoint(date: start.addingTimeInterval(Double(index) * days * 86_400), value: value)
        }
    }

    // MARK: - Y axis

    @Test func cardsUnderADollarGetCentTicks() {
        let model = ValueHistoryChartModel(points: series([0.22, 0.25, 0.31, 0.28]))

        #expect(model.axisFractionDigits == 2)
        #expect(model.axisValues.count >= 3)
        // Every tick is a distinct amount once shown to the cent.
        let labels = model.axisValues.map { ($0 * 100).rounded() }
        #expect(Set(labels).count == labels.count)
        #expect(model.yDomain.lowerBound > 0)
    }

    @Test func largeValuesUseWholeDollarTicks() {
        let model = ValueHistoryChartModel(points: series([1_200, 1_340, 1_290, 1_410]))

        #expect(model.axisFractionDigits == 0)
        // Zoomed in on the movement rather than starting at $0.
        #expect(model.yDomain.lowerBound >= 1_000)
    }

    @Test func theDomainHoldsEveryPointAndEveryTick() {
        let model = ValueHistoryChartModel(points: series([3.1, 4.8, 2.2, 3.9]))
        let domain = model.yDomain

        #expect(model.points.allSatisfy { domain.contains($0.value) })
        #expect(model.axisValues.allSatisfy { $0 >= domain.lowerBound - 0.0001 && $0 <= domain.upperBound + 0.0001 })
    }

    @Test func aFlatSeriesStillHasARange() {
        let model = ValueHistoryChartModel(points: series([0.5, 0.5, 0.5]))

        #expect(model.yDomain.upperBound > model.yDomain.lowerBound)
        #expect(model.markedExtremes.isEmpty)
        #expect(model.storyline { "\($0)" } == nil)
    }

    @Test func ticksAreRoundNumbersAndNoMoreThanFive() {
        #expect(ValueHistoryChartModel.ticks(in: 0.18...0.41) == [0.2, 0.25, 0.3, 0.35, 0.4])
        #expect(ValueHistoryChartModel.ticks(in: 773...1_000) == [800, 850, 900, 950, 1_000])
        #expect(ValueHistoryChartModel.ticks(in: 0.01...0.03) == [0.01, 0.02, 0.03])
    }

    // MARK: - Story

    @Test func aMidWindowPeakIsCalledOut() {
        let model = ValueHistoryChartModel(points: series([2, 3, 5, 4, 3.5]))

        #expect(model.markedExtremes.map(\.kind) == [.high])
        let line = model.storyline { String(format: "$%.2f", $0) }
        #expect(line?.contains("Peaked at $5.00") == true)
        #expect(line?.contains("30%") == true)
    }

    @Test func endingAtTheHighSaysSo() {
        let model = ValueHistoryChartModel(points: series([2, 1.5, 3, 4]))

        #expect(model.storyline { "\($0)" }?.hasPrefix("At its highest") == true)
    }

    @Test func aRecoveryFromADipTellsTheDip() {
        let model = ValueHistoryChartModel(points: series([3, 1, 2.5, 2.9]))

        #expect(model.storyline { String(format: "$%.2f", $0) }?.hasPrefix("Bottomed at $1.00") == true)
    }

    @Test func scrubbingPicksTheNearestDayAndMeasuresFromTheStart() throws {
        let model = ValueHistoryChartModel(points: series([2, 3, 4]))
        let point = try #require(model.nearest(to: start.addingTimeInterval(1.2 * 86_400)))

        #expect(point.value == 3)
        #expect(model.change(at: point) == .init(amount: 1, percent: 0.5))
    }

    // MARK: - Ranges

    @Test func onlyRangesShorterThanTheHistoryAreOffered() {
        let points = series(Array(repeating: 1, count: 40))

        #expect(ChartRange.available(for: points) == [.week, .month, .all])
        #expect(ChartRange.week.filter(points).count == 8)
    }

    @Test func aShortHistoryOffersNoRanges() {
        #expect(ChartRange.available(for: series([1, 2, 3])).isEmpty)
    }
}
