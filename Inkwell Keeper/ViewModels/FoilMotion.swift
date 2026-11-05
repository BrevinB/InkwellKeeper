//
//  FoilMotion.swift
//  Inkwell Keeper
//

import CoreMotion
import Foundation

/// The device tilt shared by every tilting or foil card on screen.
///
/// Motion updates only run while at least one card needs them. Device motion needs no
/// permission prompt. Cards read the tilt once per frame from a `TimelineView`, so the
/// latest sample is polled rather than delivered through a handler, and nothing is
/// observed, so motion never invalidates the views around a card.
@MainActor
final class FoilMotion {
    static let shared = FoilMotion()

    private let manager = CMMotionManager()
    private var filter = FoilTiltFilter()
    private var activeCards = 0
    private var lastSample: (time: TimeInterval, tilt: (motion: SIMD2<Double>, foil: SIMD2<Double>))?

    private init() {
        manager.deviceMotionUpdateInterval = 1 / 30
    }

    func begin() {
        activeCards += 1
        if activeCards == 1, manager.isDeviceMotionAvailable {
            manager.startDeviceMotionUpdates()
        }
    }

    func end() {
        activeCards = max(activeCards - 1, 0)
        if activeCards == 0 {
            manager.stopDeviceMotionUpdates()
        }
    }

    /// Current tilt, computed once per frame however many cards ask.
    func tilt(at date: Date) -> (motion: SIMD2<Double>, foil: SIMD2<Double>) {
        let time = date.timeIntervalSinceReferenceDate
        if let lastSample, abs(lastSample.time - time) < 1 / 120 {
            return lastSample.tilt
        }
        let gravity = manager.deviceMotion.map { SIMD2($0.gravity.x, $0.gravity.y) }
        let tilt = filter.update(gravity: gravity, time: time)
        lastSample = (time, tilt)
        return tilt
    }
}
