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
    var onTap: (() -> Void)? = nil

    @ObservedObject private var motionManager = MotionManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Touch-based interaction state
    @State private var isTouching = false
    @State private var touchPitch: Double = 0
    @State private var touchRoll: Double = 0
    @State private var dragStartLocation: CGPoint = .zero
    @State private var dragDistance: CGFloat = 0

    // 3D rotation parameters
    private let maxRotationDegrees: Double = 15.0
    private let perspective: CGFloat = 0.5
    private let tapThreshold: CGFloat = 10  // Max movement to count as tap

    // Active pitch/roll values - uses touch when touching, motion otherwise
    private var activePitch: Double {
        if reduceMotion && !isTouching { return 0 }
        return isTouching ? touchPitch : motionManager.pitch
    }

    private var activeRoll: Double {
        if reduceMotion && !isTouching { return 0 }
        return isTouching ? touchRoll : motionManager.roll
    }

    init(card: LorcanaCard, onTap: (() -> Void)? = nil) {
        self.card = card
        self.imageURL = card.bestImageUrl()
        self.onTap = onTap
    }

    var body: some View {
        GeometryReader { geometry in
            let rotationX = activePitch * maxRotationDegrees
            let rotationY = activeRoll * maxRotationDegrees

            // Shadow offset moves opposite to tilt direction
            let shadowOffsetX = -activeRoll * 20
            let shadowOffsetY = -activePitch * 20

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .interactiveHolographicEffect(
                            pitch: activePitch,
                            roll: activeRoll,
                            variant: card.variant
                        )
                case .failure:
                    cardPlaceholder
                case .empty:
                    cardPlaceholder
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                @unknown default:
                    cardPlaceholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(
                color: .black.opacity(0.4),
                radius: 20,
                x: shadowOffsetX,
                y: shadowOffsetY + 10
            )
            .rotation3DEffect(
                .degrees(rotationX),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .center,
                perspective: perspective
            )
            .rotation3DEffect(
                .degrees(-rotationY),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                perspective: perspective
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Track drag distance from start
                        if !isTouching {
                            dragStartLocation = value.startLocation
                        }
                        isTouching = true

                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        dragDistance = sqrt(dx * dx + dy * dy)

                        // Convert touch position to -1...1 range relative to card center
                        let centerX = geometry.size.width / 2
                        let centerY = geometry.size.height / 2

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

                        // Animate back to neutral when touch ends
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isTouching = false
                            touchPitch = 0
                            touchRoll = 0
                        }
                        dragDistance = 0
                    }
            )
        }
        .onAppear {
            if !reduceMotion {
                motionManager.start()
            }
        }
        .onDisappear {
            motionManager.stop()
        }
    }

    private var cardPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(0.714, contentMode: .fit)  // Standard card aspect ratio
    }
}
