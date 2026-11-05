//
//  FoilTiltFilterTests.swift
//  Inkwell KeeperTests
//

import Foundation
import Testing
@testable import Inkwell_Keeper

struct FoilTiltFilterTests {
    @Test func restingPoseReadsAsFlat() {
        var filter = FoilTiltFilter()
        let tilt = filter.update(gravity: SIMD2(0.1, -0.7), time: 0).motion
        #expect(abs(tilt.x) < 0.001 && abs(tilt.y) < 0.001)
    }

    @Test func tiltingMovesTheCardThenSettles() {
        var filter = FoilTiltFilter()
        _ = filter.update(gravity: SIMD2(0, -0.7), time: 0)
        let moved = filter.update(gravity: SIMD2(0.2, -0.7), time: 1 / 30).motion
        #expect(moved.x > 0.4)

        // Holding the new angle for a while lets the card drift back toward flat.
        var settled = moved
        for frame in 2...600 {
            settled = filter.update(gravity: SIMD2(0.2, -0.7), time: Double(frame) / 30).motion
        }
        #expect(settled.x < moved.x * 0.1)
    }

    @Test func raisingTheTopEdgeIsPositivePitch() {
        var filter = FoilTiltFilter()
        _ = filter.update(gravity: SIMD2(0, -0.5), time: 0)
        // Gravity's y moves toward -1 as the phone stands more upright.
        let tilt = filter.update(gravity: SIMD2(0, -0.7), time: 1 / 30).motion
        #expect(tilt.y > 0.3)
    }

    @Test func motionHasNoDriftButFoilDoes() {
        var filter = FoilTiltFilter()
        _ = filter.update(gravity: SIMD2(0, -0.7), time: 0)
        let tilt = filter.update(gravity: SIMD2(0, -0.7), time: 5)
        #expect(tilt.motion == .zero)
        #expect(tilt.foil != .zero)
    }

    @Test func tiltIsClamped() {
        var filter = FoilTiltFilter()
        _ = filter.update(gravity: SIMD2(-1, 0), time: 0)
        let tilt = filter.update(gravity: SIMD2(1, 0), time: 0.03)
        #expect(tilt.motion.x <= 1 && tilt.foil.x <= 1)
    }

    @Test func driftWithoutSensorStaysInRangeAndDoesNotRepeatQuickly() {
        var filter = FoilTiltFilter()
        let samples = (0..<1_200).map { filter.update(gravity: nil, time: Double($0) / 10).foil }
        #expect(samples.allSatisfy { abs($0.x) <= 1 && abs($0.y) <= 1 })
        // No exact repeat of the starting pose within two minutes.
        #expect(!samples.dropFirst(50).contains { abs($0.x - samples[0].x) < 0.001 && abs($0.y - samples[0].y) < 0.001 })
    }
}
