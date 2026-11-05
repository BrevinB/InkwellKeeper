//
//  FoilTiltFilter.swift
//  Inkwell Keeper
//

import Foundation

/// Turns the device's gravity reading into a card tilt, the way real foil responds to
/// how you hold a card.
///
/// Tilt is measured relative to a resting pose that slowly follows the device, so
/// however you hold the phone, the card settles and then moves when you tilt it.
/// A gentle drift built from waves with unrelated periods keeps the foil alive when
/// the phone is still (or has no motion sensor) without ever visibly repeating.
///
/// `x` is roll (right side down is positive) and `y` is pitch, in the same direction
/// as `CMAttitude.pitch`, each within -1...1.
nonisolated struct FoilTiltFilter: Sendable {
    /// How far the device must tilt (in gravity units) for the card to reach its edge.
    var sensitivity = 2.5
    /// Fraction of the gap to the current pose the resting pose closes each second.
    var settleRate = 0.35

    private var restingPose: SIMD2<Double>?
    private var lastTime: TimeInterval?

    /// - Parameters:
    ///   - gravity: The x and y components of gravity in device coordinates, or nil without a sensor.
    ///   - time: Seconds since any fixed reference.
    /// - Returns: `motion` follows only the device, for moving the card itself; `foil`
    ///   adds the idle drift, for the sheen.
    mutating func update(gravity: SIMD2<Double>?, time: TimeInterval) -> (motion: SIMD2<Double>, foil: SIMD2<Double>) {
        let elapsed = lastTime.map { min(max(time - $0, 0), 0.5) } ?? 0
        lastTime = time

        var tilt = SIMD2<Double>.zero
        if let gravity {
            let rest = restingPose ?? gravity
            let settled = rest + (gravity - rest) * min(settleRate * elapsed, 1)
            restingPose = settled
            // Gravity's y falls as the top edge rises, the opposite of attitude pitch.
            tilt = (gravity - settled) * SIMD2(1, -1) * sensitivity
        }
        let driftScale = gravity == nil ? 0.6 : 0.2
        let range = (lower: SIMD2<Double>(repeating: -1), upper: SIMD2<Double>(repeating: 1))
        return (
            motion: tilt.clamped(lowerBound: range.lower, upperBound: range.upper),
            foil: (tilt + Self.drift(at: time) * driftScale).clamped(lowerBound: range.lower, upperBound: range.upper)
        )
    }

    /// Slow wandering within -1...1 on each axis; the periods share no common multiple
    /// that a person would notice.
    static func drift(at time: TimeInterval) -> SIMD2<Double> {
        SIMD2(
            sin(time * 0.31) * 0.6 + sin(time * 0.173 + 1.7) * 0.4,
            sin(time * 0.237 + 0.4) * 0.55 + sin(time * 0.119 + 2.9) * 0.45
        )
    }
}
