//
//  RenderedArtworkTests.swift
//  Inkwell KeeperTests
//
//  Guards the Blender-rendered container artwork: every layer the app asks for is
//  in the asset catalog, and the generated metrics describe a scene that works.
//

import Testing
import UIKit
@testable import Inkwell_Keeper

struct RenderedArtworkTests {
    private let finishes: [StorageCoverStyle] = [.classic, .leather]

    @Test(arguments: StorageKind.allCases)
    func everyLayerIsInTheCatalog(kind: StorageKind) {
        let metrics = RenderedArtworkMetrics.forKind(kind)
        for style in finishes {
            var parts = ["base"]
            if metrics.lidHinge != nil { parts.append("lid") }
            for part in parts {
                let name = metrics.layerName(part, style: style)
                #expect(UIImage(named: "\(name)_shade") != nil, "missing \(name)_shade")
                #expect(UIImage(named: "\(name)_mask") != nil, "missing \(name)_mask")
            }
        }
    }

    @Test func binderCoverLayersAreInTheCatalog() {
        for style in finishes {
            let name = RenderedArtworkMetrics.binderCover.layerName("base", style: style)
            #expect(UIImage(named: "\(name)_shade") != nil)
            #expect(UIImage(named: "\(name)_mask") != nil)
        }
        for style in finishes {
            let name = RenderedArtworkMetrics.binderSpine.layerName("base", style: style)
            #expect(UIImage(named: "\(name)_shade") != nil)
            #expect(UIImage(named: "\(name)_mask") != nil)
        }
        #expect(RenderedArtworkMetrics.binderSpine.label != nil, "the spine needs a label area for the name")
        #expect(UIImage(named: "bindercover_plate") != nil)
        #expect(UIImage(named: "bindercover_emblem") != nil)
    }

    @Test(arguments: StorageKind.allCases)
    func cardsRiseClearOfTheRim(kind: StorageKind) throws {
        let metrics = RenderedArtworkMetrics.forKind(kind)
        guard metrics.cards == .rising else { return }
        let rimY = try #require(metrics.rimY)
        // Enough of the card shows above the rim to read as cards, not a sliver.
        #expect(rimY - metrics.cardPeakY > 0.08, "\(kind) cards barely clear the rim")
        // The lifted lid stays in frame.
        let hinge = try #require(metrics.lidHinge)
        #expect(hinge.y - metrics.lidRise > 0)
    }

    @Test(arguments: StorageKind.allCases)
    func everythingSitsInsideTheFrame(kind: StorageKind) {
        let metrics = RenderedArtworkMetrics.forKind(kind)
        #expect((0...1).contains(metrics.bottomY))
        #expect(metrics.openingLeft < metrics.openingRight)
        if let rimY = metrics.rimY {
            #expect(rimY < metrics.bottomY)
        }
    }

    @Test func ornamentsSitOnTheCover() {
        let unit = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(unit.contains(RenderedArtworkMetrics.coverPlate))
        #expect(unit.contains(RenderedArtworkMetrics.coverEmblem))
        // The name plate sits above the emblem, as on the drawn cover.
        #expect(RenderedArtworkMetrics.coverPlate.maxY < RenderedArtworkMetrics.coverEmblem.minY)
    }
}
