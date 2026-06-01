//
//  PackRevealView.swift
//  Inkwell Keeper
//
//  Reveals the pack's cards one at a time with a flip animation.
//  Revealed cards tilt with the device gyroscope and show the same
//  interactive holographic effect used elsewhere in the app.
//

import SwiftUI

struct PackRevealView: View {
    let simulator: PackSimulator

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = MotionManager.shared

    @State private var isFlipped = false
    @State private var revealPop = false
    @State private var showBurst = false

    private var slots: [PackSlot] { simulator.currentPack?.slots ?? [] }
    private var currentIndex: Int { simulator.revealedCount }
    private var currentSlot: PackSlot? {
        slots.indices.contains(currentIndex) ? slots[currentIndex] : nil
    }

    /// Gyro tilt for the face-down card, disabled when Reduce Motion is on.
    private var tiltX: Double { reduceMotion ? 0 : motion.pitch * 12 }
    private var tiltY: Double { reduceMotion ? 0 : -motion.roll * 12 }

    var body: some View {
        VStack(spacing: 18) {
            header

            Spacer()

            if let slot = currentSlot {
                cardArea(for: slot)
                revealLabel(for: slot)
            }

            Spacer()

            footer
        }
        .padding()
        .onAppear {
            if !reduceMotion { motion.start() }
        }
        .onDisappear {
            if !reduceMotion { motion.stop() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("Card \(min(currentIndex + 1, slots.count)) of \(slots.count)")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                ForEach(slots.indices, id: \.self) { index in
                    Circle()
                        .fill(index < currentIndex ? Color.lorcanaGold : .white.opacity(0.2))
                        .frame(width: 7, height: 7)
                }
            }
        }
    }

    // MARK: - Card

    private func cardArea(for slot: PackSlot) -> some View {
        ZStack {
            ForEach(0..<remainingBehind, id: \.self) { offset in
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.08))
                    )
                    .aspectRatio(0.717, contentMode: .fit)
                    .scaleEffect(1 - CGFloat(offset + 1) * 0.04)
                    .offset(y: CGFloat(offset + 1) * 10)
            }

            flipCard(for: slot)
                .scaleEffect(revealPop ? 1.06 : 1.0)
                .id(currentIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            if showBurst {
                CelebrationBurst(color: slot.card.rarity.color, sparkleCount: 16)
                    .id(currentIndex)
            }
        }
        .frame(maxWidth: 290)
    }

    private func flipCard(for slot: PackSlot) -> some View {
        ZStack {
            // Face-down side — tilts gently with the gyroscope.
            Button {
                handleTap(slot)
            } label: {
                CardBackView()
                    .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
                    .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            }
            .buttonStyle(.plain)
            .opacity(isFlipped ? 0 : 1)
            .allowsHitTesting(!isFlipped)

            // Revealed side — full motion-reactive holographic card.
            // Pre-rotated so the container's 180° flip nets to 360° (not mirrored).
            InteractiveCardView(card: slot.card) {
                handleTap(slot)
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .allowsHitTesting(isFlipped)
        }
        .aspectRatio(0.717, contentMode: .fit)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .sensoryFeedback(trigger: isFlipped) { _, flipped in
            guard flipped else { return nil }
            return slot.card.rarity.sortOrder >= CardRarity.superRare.sortOrder
                ? .impact(weight: .heavy)
                : .impact(weight: .light)
        }
    }

    @ViewBuilder
    private func revealLabel(for slot: PackSlot) -> some View {
        VStack(spacing: 6) {
            Text(slot.card.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            HStack(spacing: 8) {
                Text(slot.card.rarity.displayName)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(slot.card.rarity.color.opacity(0.25), in: .capsule)
                    .foregroundStyle(slot.card.rarity.color)

                if slot.isFoil {
                    Text("✦ Foil")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.lorcanaGold.opacity(0.2), in: .capsule)
                        .foregroundStyle(Color.lorcanaGold)
                }
            }
        }
        .opacity(isFlipped ? 1 : 0)
        .animation(.easeIn(duration: 0.2), value: isFlipped)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            Text(isFlipped ? "Tap the card for the next one" : "Tap the card to flip it")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            Button("Reveal all") {
                simulator.revealAll()
            }
            .buttonStyle(LorcanaButtonStyle(style: .secondary))
        }
    }

    // MARK: - Helpers

    private var remainingBehind: Int {
        min(max(slots.count - currentIndex - 1, 0), 3)
    }

    private func handleTap(_ slot: PackSlot) {
        isFlipped ? advance() : flip(slot)
    }

    private func flip(_ slot: PackSlot) {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.45)) {
            isFlipped = true
        }

        let isRare = slot.card.rarity.sortOrder >= CardRarity.superRare.sortOrder
        Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.0 : 0.4))
            if isRare { showBurst = true }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) {
                revealPop = true
            }
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeOut(duration: 0.25)) {
                revealPop = false
            }
        }
    }

    private func advance() {
        showBurst = false
        revealPop = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isFlipped = false
            simulator.revealNext()
        }
    }
}
