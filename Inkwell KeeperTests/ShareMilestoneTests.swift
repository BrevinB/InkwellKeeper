//
//  ShareMilestoneTests.swift
//  Inkwell KeeperTests
//
//  Unit tests for ShareMilestone copy/formatting — pure presentation logic.
//

import Testing
import Foundation
@testable import Inkwell_Keeper

struct ShareMilestoneTests {
    @Test func setCompletedShowsHundredPercent() {
        let milestone = ShareMilestone.setCompleted(name: "Azurite Sea")
        #expect(milestone.heroValue == "100%")
        #expect(milestone.headline == "Azurite Sea Complete!")
    }

    @Test func setProgressFormatsPercentage() {
        let milestone = ShareMilestone.setProgress(name: "Fabled", percentage: 0.42)
        #expect(milestone.heroValue == 0.42.formatted(.percent.precision(.fractionLength(0))))
        #expect(milestone.headline == "Fabled")
    }

    @Test func cardsScannedSingularVsPlural() {
        #expect(ShareMilestone.cardsScanned(count: 1).subtitle == "Just added a new card.")
        #expect(ShareMilestone.cardsScanned(count: 5).subtitle == "Added in one scanning session.")
    }

    @Test func everyMilestoneHasNonEmptyCopy() {
        let milestones: [ShareMilestone] = [
            .setCompleted(name: "X"),
            .setProgress(name: "X", percentage: 0.5),
            .collectionValue(amount: 1234, currencyCode: "USD"),
            .cardsScanned(count: 3),
            .uniqueCards(count: 99)
        ]
        for milestone in milestones {
            #expect(!milestone.heroValue.isEmpty)
            #expect(!milestone.headline.isEmpty)
            #expect(!milestone.subtitle.isEmpty)
            #expect(!milestone.iconName.isEmpty)
            #expect(!milestone.analyticsKind.isEmpty)
        }
    }
}
