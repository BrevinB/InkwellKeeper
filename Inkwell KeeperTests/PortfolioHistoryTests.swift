//
//  PortfolioHistoryTests.swift
//  Inkwell KeeperTests
//
//  The collection value chart is built from the backend's change-point
//  compressed series, so most of the work is expanding those back into daily
//  values without inventing movement that did not happen.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct PortfolioHistoryTests {
    private typealias Point = PricingService.PortfolioPricePoint

    private func holding(_ key: String, _ quantity: Int) -> PortfolioHolding {
        PortfolioHolding(cardKey: key, quantity: quantity)
    }

    @Test func expandsCompressedSeriesToOneValuePerDay() {
        let series = ["a": [Point(day: 10, price: 1.0), Point(day: 13, price: 2.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: series
        )

        #expect(points.map(\.value) == [1.0, 1.0, 1.0, 2.0])
    }

    @Test func multipliesByQuantity() {
        let series = ["a": [Point(day: 5, price: 2.5)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 4)], series: series
        )

        #expect(points.first?.value == 10.0)
    }

    @Test func sumsAcrossHoldings() {
        let series = [
            "a": [Point(day: 1, price: 1.0)],
            "b": [Point(day: 1, price: 0.5)]
        ]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 2), holding("b", 3)], series: series
        )

        #expect(points.first?.value == 3.5)
    }

    /// A card the backend only started tracking partway through the window
    /// must not read as a sudden gain on the day tracking began.
    @Test func carriesAShortSeriesBackwardsInsteadOfStartingAtZero() {
        let series = [
            "old": [Point(day: 1, price: 1.0)],
            "new": [Point(day: 3, price: 10.0)]
        ]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("old", 1), holding("new", 1)], series: series
        )

        #expect(points.map(\.value) == [11.0, 11.0, 11.0])
    }

    // MARK: - Window trimming

    /// The backend holds stray early observations — TFC-1 has one on 2 March
    /// 2026 and nothing until 13 May. Charting from March would draw a flat
    /// ten-week line and then show the correction as a gain.
    @Test func opensAfterALongGapRatherThanAtTheOldestPoint() {
        let series = ["a": [Point(day: 1, price: 0.04), Point(day: 73, price: 0.09)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: series
        )

        #expect(points.count == 1)
        #expect(points.first?.value == 0.09)
    }

    @Test func shortGapsStayInsideTheWindow() {
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 8, price: 2.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: series
        )

        #expect(points.count == 8)
        #expect(points.first?.value == 1.0)
    }

    @Test func windowOpensAfterTheLastLongGapNotTheFirst() {
        let days = [1, 2, 40, 41, 100, 101]

        #expect(PortfolioHistoryBuilder.windowStart(observationDays: days) == 100)
    }

    @Test func aGapInOneCardDoesNotTrimTheWholeCollection() {
        // The union of observations is what matters: another card covering the
        // gap keeps the window open.
        let series = [
            "sparse": [Point(day: 1, price: 1.0), Point(day: 40, price: 1.0)],
            "daily": (1...40).map { Point(day: $0, price: 1.0) }
        ]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("sparse", 1), holding("daily", 1)], series: series
        )

        #expect(points.count == 40)
        #expect(points.first?.value == 2.0)
    }

    @Test func windowStartOfNoObservationsIsNil() {
        #expect(PortfolioHistoryBuilder.windowStart(observationDays: []) == nil)
    }

    @Test func ignoresHoldingsWithNoPriceData() {
        let series = ["a": [Point(day: 1, price: 1.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1), holding("unpriced", 5)], series: series
        )

        #expect(points.map(\.value) == [1.0])
    }

    @Test func ignoresZeroQuantityHoldings() {
        let series = ["a": [Point(day: 1, price: 1.0)], "b": [Point(day: 1, price: 99.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1), holding("b", 0)], series: series
        )

        #expect(points.first?.value == 1.0)
    }

    @Test func returnsNothingWhenNoHoldingIsPriced() {
        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: [:]
        )

        #expect(points.isEmpty)
    }

    @Test func holdsQuantitiesConstantSoAnImportIsNotACliff() {
        // Every card bulk-imported today still charts across the whole window.
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 4, price: 1.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 10)], series: series
        )

        #expect(points.count == 4)
        #expect(points.allSatisfy { $0.value == 10.0 })
    }

    @Test func daysAreOrderedAndContiguous() {
        let series = ["a": [Point(day: 100, price: 1.0), Point(day: 104, price: 1.0)]]

        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: series
        )
        let dates = points.map(\.date)

        #expect(dates == dates.sorted())
        #expect(points.count == 5)
    }

    /// Points are anchored at midday UTC so they render on the same calendar
    /// date either side of the meridian.
    @Test func epochDaysAnchorAtMiddayUTC() {
        #expect(PortfolioHistoryBuilder.date(fromEpochDay: 0)
                == Date(timeIntervalSince1970: 43_200))
    }

    @Test func aDayKeepsItsDateInWesternTimeZones() {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles") ?? .gmt
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt

        // 20586 is 13 May 2026, the day the backend's daily history starts.
        let date = PortfolioHistoryBuilder.date(fromEpochDay: 20_586)

        #expect(losAngeles.component(.day, from: date) == 13)
        #expect(utc.component(.day, from: date) == 13)
        #expect(losAngeles.component(.month, from: date) == 5)
    }

    // MARK: - Summary

    @Test func summaryReportsCurrentValueAndMovement() {
        let series = ["a": [Point(day: 1, price: 10.0), Point(day: 3, price: 15.0)]]
        let points = PortfolioHistoryBuilder.dailyValues(
            holdings: [holding("a", 1)], series: series
        )

        let summary = PortfolioHistoryBuilder.summary(for: points)

        #expect(summary.currentValue == 15.0)
        #expect(summary.change == 5.0)
        #expect(summary.percentChange == 50.0)
    }

    @Test func summaryHasNoPercentageWhenTheWindowOpensAtZero() {
        let points = [
            PortfolioPoint(date: .now, value: 0),
            PortfolioPoint(date: .now.addingTimeInterval(86_400), value: 5)
        ]

        #expect(PortfolioHistoryBuilder.summary(for: points).percentChange == nil)
    }

    @Test func summaryOfAnEmptySeriesIsEmpty() {
        #expect(PortfolioHistoryBuilder.summary(for: []) == .empty)
    }

    @Test func trailingChangeLooksBackTheRequestedNumberOfDays() {
        let points = (0..<10).map {
            PortfolioPoint(
                date: Date(timeIntervalSince1970: TimeInterval($0) * 86_400),
                value: Double($0)
            )
        }

        #expect(PortfolioHistoryBuilder.change(in: points, overTrailing: 7) == 7.0)
    }

    @Test func trailingChangeClampsToTheStartOfAShortSeries() {
        let points = [
            PortfolioPoint(date: Date(timeIntervalSince1970: 0), value: 2),
            PortfolioPoint(date: Date(timeIntervalSince1970: 86_400), value: 6)
        ]

        #expect(PortfolioHistoryBuilder.change(in: points, overTrailing: 30) == 4.0)
    }

    @Test func trailingChangeIsUnavailableForASinglePoint() {
        let points = [PortfolioPoint(date: .now, value: 5)]

        #expect(PortfolioHistoryBuilder.change(in: points, overTrailing: 7) == nil)
    }
}
