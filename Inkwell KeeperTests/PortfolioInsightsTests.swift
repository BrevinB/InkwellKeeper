//
//  PortfolioInsightsTests.swift
//  Inkwell KeeperTests
//
//  Per-printing readings over the compressed price series: movers, window
//  extremes, and the foil/normal value split.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct PortfolioInsightsTests {
    private typealias Point = PricingService.PortfolioPricePoint

    private func holding(
        _ key: String,
        _ quantity: Int,
        name: String = "Card",
        foil: Bool = false
    ) -> PortfolioHolding {
        PortfolioHolding(cardKey: key, quantity: quantity, name: name, isFoil: foil)
    }

    // MARK: - Price lookup

    @Test func priceCarriesForwardBetweenChangePoints() {
        let series = [Point(day: 10, price: 1.0), Point(day: 20, price: 2.0)]

        #expect(PortfolioInsightsBuilder.price(in: series, onOrBefore: 15) == 1.0)
        #expect(PortfolioInsightsBuilder.price(in: series, onOrBefore: 20) == 2.0)
        #expect(PortfolioInsightsBuilder.price(in: series, onOrBefore: 25) == 2.0)
    }

    /// Matches how the chart carries a short series backwards, so a card the
    /// backend started tracking late does not register as a huge gain.
    @Test func priceBeforeTheSeriesStartsUsesTheFirstKnownPrice() {
        let series = [Point(day: 10, price: 5.0)]

        #expect(PortfolioInsightsBuilder.price(in: series, onOrBefore: 1) == 5.0)
    }

    // MARK: - Movers

    @Test func moversReportTheChangeInHeldValueNotUnitPrice() {
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 8, price: 1.5)]]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: [holding("a", 4)], series: series, overTrailing: 7
        )

        #expect(movers.count == 1)
        #expect(movers[0].change == 2.0)        // 50c x 4 copies
        #expect(movers[0].currentValue == 6.0)
        #expect(movers[0].percentChange == 50.0)
    }

    @Test func moversAreOrderedByTheSizeOfTheMove() {
        let series = [
            "small": [Point(day: 1, price: 1.0), Point(day: 8, price: 1.2)],
            "big": [Point(day: 1, price: 1.0), Point(day: 8, price: 4.0)],
            "drop": [Point(day: 1, price: 5.0), Point(day: 8, price: 3.0)]
        ]
        let holdings = [holding("small", 1), holding("big", 1), holding("drop", 1)]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: holdings, series: series, overTrailing: 7
        )

        #expect(movers.map(\.cardKey) == ["big", "drop", "small"])
    }

    @Test func aFallIsReportedAsALoss() {
        let series = ["a": [Point(day: 1, price: 4.0), Point(day: 8, price: 1.0)]]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: [holding("a", 2)], series: series, overTrailing: 7
        )

        #expect(movers[0].change == -6.0)
        #expect(movers[0].isGain == false)
        #expect(movers[0].percentChange == -75.0)
    }

    @Test func unchangedPrintingsAreNotMovers() {
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 8, price: 1.0)]]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: [holding("a", 1)], series: series, overTrailing: 7
        )

        #expect(movers.isEmpty)
    }

    @Test func holdingsWithoutPricesOrCopiesAreSkipped() {
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 8, price: 2.0)]]
        let holdings = [holding("a", 0), holding("missing", 5)]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: holdings, series: series, overTrailing: 7
        )

        #expect(movers.isEmpty)
    }

    @Test func theWindowIsMeasuredFromTheLatestDayInTheData() {
        // The card's own series ends before the collection's latest day; the
        // trailing window must still be anchored to the collection's end.
        let series = [
            "stale": [Point(day: 1, price: 1.0), Point(day: 20, price: 2.0)],
            "fresh": (1...30).map { Point(day: $0, price: 1.0) }
        ]

        let movers = PortfolioInsightsBuilder.movers(
            holdings: [holding("stale", 1), holding("fresh", 1)],
            series: series,
            overTrailing: 7
        )

        // Days 23-30 for "stale" are all 2.0, so it has not moved in the window.
        #expect(movers.isEmpty)
    }

    // MARK: - Extremes

    private func risingSeries(to peak: Double) -> [Point] {
        (1...10).map { Point(day: $0, price: $0 == 10 ? peak : 1.0) }
    }

    @Test func aPrintingAtItsWindowHighIsReported() {
        let series = ["a": risingSeries(to: 4.0)]

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: series
        )

        #expect(extremes.count == 1)
        #expect(extremes[0].kind == .high)
        #expect(extremes[0].price == 4.0)
        #expect(extremes[0].windowHigh == 4.0)
        #expect(extremes[0].windowLow == 1.0)
    }

    @Test func aPrintingAtItsWindowLowIsReported() {
        var points = (1...9).map { Point(day: $0, price: 5.0) }
        points.append(Point(day: 10, price: 1.0))

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: ["a": points]
        )

        #expect(extremes[0].kind == .low)
        #expect(extremes[0].price == 1.0)
    }

    @Test func aPrintingInTheMiddleOfItsRangeIsNotAnExtreme() {
        var points = (1...9).map { Point(day: $0, price: Double($0)) }
        points.append(Point(day: 10, price: 5.0))

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: ["a": points]
        )

        #expect(extremes.isEmpty)
    }

    /// A penny common ticking 1c to 2c is technically at a high and is noise.
    @Test func cheapPrintingsAreExcluded() {
        let series = ["a": (1...10).map { Point(day: $0, price: $0 == 10 ? 0.02 : 0.01) }]

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: series
        )

        #expect(extremes.isEmpty)
    }

    /// A flat price is trivially at both its high and its low.
    @Test func aPrintingWithNoMeaningfulRangeIsExcluded() {
        let series = ["a": (1...10).map { Point(day: $0, price: 5.0) }]

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: series
        )

        #expect(extremes.isEmpty)
    }

    @Test func aSeriesTooShortToJudgeIsExcluded() {
        let series = ["a": [Point(day: 1, price: 1.0), Point(day: 2, price: 9.0)]]

        let extremes = PortfolioInsightsBuilder.extremes(
            holdings: [holding("a", 1)], series: series
        )

        #expect(extremes.isEmpty)
    }

    // MARK: - Variant split

    @Test func valueSplitsBetweenFoilAndNormal() {
        let series = [
            "n": [Point(day: 1, price: 1.0)],
            "f": [Point(day: 1, price: 6.0)]
        ]
        let holdings = [holding("n", 3, foil: false), holding("f", 2, foil: true)]

        let split = PortfolioInsightsBuilder.variantSplit(holdings: holdings, series: series)

        #expect(split.normalValue == 3.0)
        #expect(split.foilValue == 12.0)
        #expect(split.normalCopies == 3)
        #expect(split.foilCopies == 2)
        #expect(split.totalValue == 15.0)
    }

    @Test func foilMultipleComparesAveragePerCopy() {
        let series = [
            "n": [Point(day: 1, price: 2.0)],
            "f": [Point(day: 1, price: 6.0)]
        ]
        let holdings = [holding("n", 4, foil: false), holding("f", 1, foil: true)]

        let split = PortfolioInsightsBuilder.variantSplit(holdings: holdings, series: series)

        // $6.00 per foil copy against $2.00 per normal copy.
        #expect(split.foilMultiple == 3.0)
    }

    @Test func foilMultipleIsUnavailableWithoutBothSides() {
        let series = ["f": [Point(day: 1, price: 6.0)]]
        let holdings = [holding("f", 1, foil: true)]

        let split = PortfolioInsightsBuilder.variantSplit(holdings: holdings, series: series)

        #expect(split.foilMultiple == nil)
        #expect(split.foilShare == 1.0)
    }

    /// The card's bar chart plots these, so they have to agree with the
    /// multiple quoted above them.
    @Test func averagesPerCopyBackTheQuotedMultiple() {
        let series = [
            "n": [Point(day: 1, price: 2.0)],
            "f": [Point(day: 1, price: 6.0)]
        ]
        let holdings = [holding("n", 4, foil: false), holding("f", 2, foil: true)]

        let split = PortfolioInsightsBuilder.variantSplit(holdings: holdings, series: series)

        #expect(split.averageNormalValue == 2.0)
        #expect(split.averageFoilValue == 6.0)
        #expect(split.averageFoilValue / split.averageNormalValue == split.foilMultiple)
    }

    @Test func averagesAreZeroWithoutCopies() {
        let split = PortfolioVariantSplit.empty

        #expect(split.averageFoilValue == 0)
        #expect(split.averageNormalValue == 0)
    }

    @Test func anEmptySplitReportsNothing() {
        let split = PortfolioInsightsBuilder.variantSplit(holdings: [], series: [:])

        #expect(split == .empty)
        #expect(split.foilShare == nil)
    }
}
