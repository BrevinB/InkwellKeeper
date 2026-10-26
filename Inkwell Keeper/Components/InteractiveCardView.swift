//
//  InteractiveCardView.swift
//  Inkwell Keeper
//
//  Reusable component combining 3D rotation with holographic effects
//

import SwiftUI

struct InteractiveCardView: View {
    let card: LorcanaCard
    let imageURL: URL?
    var onTap: (() -> Void)?

    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var ownsMotionUpdates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Touch-based interaction state, added on top of the device tilt
    @State private var touchPitch: Double = 0
    @State private var touchRoll: Double = 0
    @State private var dragDistance: CGFloat = 0

    private let tapThreshold: CGFloat = 10  // Max movement to count as tap

    private var needsMotion: Bool {
        isVisible && !reduceMotion && scenePhase == .active
    }

    init(card: LorcanaCard, onTap: (() -> Void)? = nil) {
        self.card = card
        self.imageURL = card.bestImageUrl()
        self.onTap = onTap
    }

    var body: some View {
        GeometryReader { geometry in
            TiltingCardFace(
                card: card,
                imageURL: imageURL,
                tracksMotion: ownsMotionUpdates,
                touchPitch: touchPitch,
                touchRoll: touchRoll
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Track drag distance from start
                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        dragDistance = max(dragDistance, hypot(dx, dy))

                        // Convert touch position to -1...1 range relative to card center
                        let centerX = max(geometry.size.width / 2, 1)
                        let centerY = max(geometry.size.height / 2, 1)

                        // Roll based on horizontal position (left = negative, right = positive)
                        let rawRoll = (value.location.x - centerX) / centerX
                        touchRoll = min(max(Double(rawRoll), -1), 1)
                        // Pitch based on vertical position (top = negative, bottom = positive)
                        let rawPitch = (value.location.y - centerY) / centerY
                        touchPitch = min(max(Double(rawPitch), -1), 1)
                    }
                    .onEnded { _ in
                        // If minimal movement, treat as tap
                        if dragDistance < tapThreshold {
                            onTap?()
                        }

                        // Spring back to the device tilt when touch ends
                        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7)) {
                            touchPitch = 0
                            touchRoll = 0
                        }
                        dragDistance = 0
                    }
            )
        }
        .aspectRatio(5.0 / 7.0, contentMode: .fit)
        .onAppear {
            isVisible = true
            updateMotionSubscription()
        }
        .onChange(of: reduceMotion) { updateMotionSubscription() }
        .onChange(of: scenePhase) { updateMotionSubscription() }
        .onDisappear {
            isVisible = false
            updateMotionSubscription()
        }
    }

    private func updateMotionSubscription() {
        guard needsMotion != ownsMotionUpdates else { return }
        ownsMotionUpdates = needsMotion
        if needsMotion {
            FoilMotion.shared.begin()
        } else {
            FoilMotion.shared.end()
        }
    }
}
