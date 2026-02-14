//
//  MotionManager.swift
//  Inkwell Keeper
//
//  CoreMotion wrapper for device orientation data used in 3D card effects
//

import SwiftUI
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    // Shared instance for efficient motion sharing across views
    static let shared = MotionManager()

    @Published var pitch: Double = 0.0  // Vertical tilt (-1 to 1)
    @Published var roll: Double = 0.0   // Horizontal tilt (-1 to 1)
    @Published var isAvailable: Bool = false

    private var motionManager: CMMotionManager?
    private let updateInterval: TimeInterval = 1.0 / 60.0  // 60fps

    // Low-pass filter coefficients for smoothing (higher = more responsive)
    private let filterFactor: Double = 0.25
    // Sensitivity multiplier (higher = less tilt needed for full effect)
    private let sensitivity: Double = 3.5
    private var filteredPitch: Double = 0.0
    private var filteredRoll: Double = 0.0

    // Simulator fallback animation
    private var simulatorTimer: Timer?
    private var simulatorPhase: Double = 0.0

    // Reference counting for start/stop
    private var activeObservers: Int = 0

    init() {
        motionManager = CMMotionManager()
        isAvailable = motionManager?.isDeviceMotionAvailable ?? false
    }

    @MainActor
    func start() {
        activeObservers += 1

        // Only start if this is the first observer
        guard activeObservers == 1 else { return }

        #if targetEnvironment(simulator)
        startSimulatorFallback()
        #else
        if motionManager?.isDeviceMotionAvailable == true {
            startDeviceMotion()
        } else {
            startSimulatorFallback()
        }
        #endif
    }

    @MainActor
    func stop() {
        activeObservers = max(0, activeObservers - 1)

        // Only stop if no more observers
        guard activeObservers == 0 else { return }

        motionManager?.stopDeviceMotionUpdates()
        simulatorTimer?.invalidate()
        simulatorTimer = nil

        // Reset values
        pitch = 0.0
        roll = 0.0
        filteredPitch = 0.0
        filteredRoll = 0.0
    }

    @MainActor
    private func startDeviceMotion() {
        guard let motionManager = motionManager, motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }

            // Get attitude (device orientation relative to reference frame)
            let attitude = motion.attitude

            // Convert to normalized range (-1 to 1) with sensitivity boost
            // Pitch: tilting device forward/backward
            // Roll: tilting device left/right
            // Higher sensitivity means less tilt needed for full effect
            let rawPitch = Self.clampValue(attitude.pitch * self.sensitivity, min: -1.0, max: 1.0)
            let rawRoll = Self.clampValue(attitude.roll * self.sensitivity, min: -1.0, max: 1.0)

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Apply low-pass filter for smooth motion
                self.filteredPitch = self.lowPassFilter(
                    current: self.filteredPitch,
                    new: rawPitch
                )
                self.filteredRoll = self.lowPassFilter(
                    current: self.filteredRoll,
                    new: rawRoll
                )

                self.pitch = self.filteredPitch
                self.roll = self.filteredRoll
            }
        }
    }

    @MainActor
    private func startSimulatorFallback() {
        // Animated motion for simulator/devices without gyroscope
        simulatorTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.simulatorPhase += self.updateInterval * 0.8  // Moderate movement speed

                // Create figure-8 pattern with good amplitude
                self.pitch = sin(self.simulatorPhase) * 0.5
                self.roll = sin(self.simulatorPhase * 0.7) * 0.5
            }
        }
    }

    @MainActor
    private func lowPassFilter(current: Double, new: Double) -> Double {
        return current + filterFactor * (new - current)
    }

    private static func clampValue(_ value: Double, min: Double, max: Double) -> Double {
        return Swift.min(Swift.max(value, min), max)
    }
}
