//
//  SealedPackView.swift
//  Inkwell Keeper
//
//  Shows the sealed booster wrapper and plays the tear-open animation.
//  The pack tilts with the device's gyroscope while sealed.
//

import SwiftUI

struct SealedPackView: View {
    let simulator: PackSimulator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = MotionManager.shared

    @State private var float = false
    @State private var wiggle = false
    @State private var tear: Double = 0
    @State private var packOpacity: Double = 1
    @State private var packScale: Double = 1
    @State private var showBurst = false
    @State private var isOpening = false

    /// Gyro tilt, disabled when Reduce Motion is on.
    private var tiltX: Double { reduceMotion ? 0 : motion.pitch * 12 }
    private var tiltY: Double { reduceMotion ? 0 : -motion.roll * 12 }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Button(action: openPack) {
                    GenericPackWrapper(
                        setName: simulator.selectedSet?.name ?? "Lorcana",
                        tearProgress: tear
                    )
                    .frame(width: 260, height: 420)
                    .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .rotationEffect(.degrees(wiggle ? 3 : 0))
                    .offset(y: float ? -8 : 8)
                    .scaleEffect(packScale)
                    .opacity(packOpacity)
                }
                .buttonStyle(.plain)
                .disabled(isOpening)

                if showBurst {
                    CelebrationBurst(color: .lorcanaGold, sparkleCount: 18)
                }
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: tear)

            VStack(spacing: 6) {
                Text(isOpening ? "Ripping…" : "Tap the pack to rip it open")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("12 random cards await")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .opacity(isOpening ? 0 : 1)

            Spacer()

            Button("Choose a different set") {
                simulator.reset()
            }
            .buttonStyle(LorcanaButtonStyle(style: .secondary))
            .opacity(isOpening ? 0 : 1)
            .disabled(isOpening)
        }
        .padding()
        .onAppear {
            guard !reduceMotion else { return }
            motion.start()
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                float = true
            }
        }
        .onDisappear {
            if !reduceMotion { motion.stop() }
        }
    }

    private func openPack() {
        guard !isOpening else { return }
        isOpening = true

        guard !reduceMotion else {
            simulator.openPack()
            return
        }

        Task {
            // Grip-and-shake.
            withAnimation(.easeInOut(duration: 0.09).repeatCount(5, autoreverses: true)) {
                wiggle = true
            }
            try? await Task.sleep(for: .seconds(0.5))

            // Initial resistance — the seal starts to give.
            withAnimation(.easeOut(duration: 0.14)) { tear = 0.13 }
            try? await Task.sleep(for: .seconds(0.16))

            // The rip — strip snaps away.
            showBurst = true
            withAnimation(.easeOut(duration: 0.45)) { tear = 1 }
            try? await Task.sleep(for: .seconds(0.5))

            // Body fades out into the reveal.
            withAnimation(.easeIn(duration: 0.28)) {
                packOpacity = 0
                packScale = 1.12
            }
            try? await Task.sleep(for: .seconds(0.28))

            simulator.openPack()
        }
    }
}
