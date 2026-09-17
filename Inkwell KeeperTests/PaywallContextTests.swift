//
//  PaywallContextTests.swift
//  Inkwell KeeperTests
//
//  The paywall leads with whatever the reader just reached for. These guard
//  the mapping and, more importantly, that tailoring the pitch never hides
//  part of what the subscription includes.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct PaywallContextTests {
    /// Every source string any surface passes to the paywall today.
    private static let liveSources = [
        "portfolioHistory",
        "tradeCalculator",
        "deckBuilder",
        "deckCompleter",
        "deckStrategy",
        "rulesTab",
        "cardAsk"
    ]

    // MARK: - Routing

    @Test func collectionSurfacesLeadWithCollectionValue() {
        let context = PaywallContext.forSource("portfolioHistory")

        #expect(context.leadFeatures.first == .valueHistory)
    }

    @Test func theTradeCalculatorLeadsWithTrading() {
        let context = PaywallContext.forSource("tradeCalculator")

        #expect(context.leadFeatures.first == .tradeCalculator)
    }

    @Test func everyDeckSurfaceLeadsWithTheDeckBuilder() {
        for source in ["deckBuilder", "deckCompleter", "deckStrategy"] {
            #expect(PaywallContext.forSource(source).leadFeatures.first == .deckBuilder)
        }
    }

    @Test func bothRulesEntryPointsLeadWithTheRulesExpert() {
        for source in ["rulesTab", "cardAsk"] {
            #expect(PaywallContext.forSource(source).leadFeatures.first == .rulesExpert)
        }
    }

    @Test func anUnknownSourceFallsBackToTheGeneralPitch() {
        let context = PaywallContext.forSource("somethingNew")

        #expect(context.headline == PaywallContext.general.headline)
        #expect(!context.leadFeatures.isEmpty)
    }

    /// The default parameter on the paywall view is "rulesPro", which matches
    /// no case and must still produce a usable pitch.
    @Test func theViewsDefaultSourceResolves() {
        #expect(PaywallContext.forSource("rulesPro").leadFeatures.isEmpty == false)
    }

    // MARK: - Completeness

    /// Tailoring the pitch must never drop a feature: lead plus supporting has
    /// to account for everything Pro includes, whichever surface opened it.
    @Test func everyContextShowsTheWholeSubscription() {
        for source in Self.liveSources + ["unknown"] {
            let context = PaywallContext.forSource(source)
            let shown = Set(context.leadFeatures.map(\.id))
                .union(context.supportingFeatures.map(\.id))

            #expect(
                shown == Set(PaywallFeature.all.map(\.id)),
                "\(source) does not show every feature"
            )
        }
    }

    @Test func leadFeaturesAreNotRepeatedInTheSupportingList() {
        for source in Self.liveSources {
            let context = PaywallContext.forSource(source)
            let leadIDs = Set(context.leadFeatures.map(\.id))
            let supportingIDs = Set(context.supportingFeatures.map(\.id))

            #expect(leadIDs.isDisjoint(with: supportingIDs), "\(source) repeats a feature")
        }
    }

    @Test func everyContextLeadsWithAFewFeaturesNotAWall() {
        for source in Self.liveSources {
            let count = PaywallContext.forSource(source).leadFeatures.count
            #expect((2...4).contains(count), "\(source) leads with \(count) features")
        }
    }

    @Test func everyContextHasCopy() {
        for source in Self.liveSources {
            let context = PaywallContext.forSource(source)

            #expect(!context.headline.isEmpty)
            #expect(!context.subheadline.isEmpty)
            #expect(!context.heroIcon.isEmpty)
        }
    }

    // MARK: - Feature catalogue

    @Test func featureIDsAreUnique() {
        let ids = PaywallFeature.all.map(\.id)

        #expect(Set(ids).count == ids.count)
    }

    @Test func everyFeatureHasCopyAndAnIcon() {
        for feature in PaywallFeature.all {
            #expect(!feature.title.isEmpty)
            #expect(!feature.description.isEmpty)
            #expect(!feature.icon.isEmpty)
        }
    }

    /// The collector features were the reason for this work; a paywall that
    /// lists only the AI ones is the thing being fixed.
    @Test func theCatalogueCoversBothHalvesOfTheSubscription() {
        let ids = Set(PaywallFeature.all.map(\.id))

        #expect(ids.isSuperset(of: ["valueHistory", "movers", "costBasis", "tradeCalculator"]))
        #expect(ids.isSuperset(of: ["rulesExpert", "deckBuilder"]))
    }
}
