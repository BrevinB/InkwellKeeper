//
//  TiltingCardFace.swift
//  Inkwell Keeper
//
//  The card art, foil, shadow and 3D rotation for InteractiveCardView
//

import SwiftUI

/// Card art that turns in 3D with the device tilt plus any tilt from the user's finger,
/// with its foil and shadow following along.
///
/// The finger's tilt is animatable, so the card springs back to the device's tilt
/// after a drag even though the device tilt itself updates every frame.
struct TiltingCardFace: View, Animatable {
    let card: LorcanaCard
    let imageURL: URL?
    /// Whether to follow the device tilt; `FoilMotion` must be running while this is on.
    let tracksMotion: Bool
    /// Tilt from dragging the card, within -1...1 on each axis.
    var touchPitch: Double
    var touchRoll: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(touchPitch, touchRoll) }
        set {
            touchPitch = newValue.first
            touchRoll = newValue.second
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // 3D rotation parameters
    private let maxRotationDegrees: Double = 15.0
    private let perspective: CGFloat = 0.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !tracksMotion)) { timeline in
            let deviceTilt = tracksMotion ? FoilMotion.shared.tilt(at: timeline.date) : (motion: .zero, foil: .zero)
            let touch = reduceMotion ? .zero : SIMD2(touchRoll, touchPitch)
            let cardTilt = combined(deviceTilt.motion, touch)
            let foilTilt = combined(deviceTilt.foil, touch)

            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable().scaledToFit()
                        .interactiveHolographicEffect(
                            pitch: foilTilt.y,
                            roll: foilTilt.x,
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
            // Shadow offset moves opposite to tilt direction
            .shadow(
                color: .black.opacity(0.4),
                radius: 20,
                x: -cardTilt.x * 20,
                y: -cardTilt.y * 20 + 10
            )
            .rotation3DEffect(
                .degrees(cardTilt.y * maxRotationDegrees),
                axis: (x: 1.0, y: 0.0, z: 0.0),
                anchor: .center,
                perspective: perspective
            )
            .rotation3DEffect(
                .degrees(-cardTilt.x * maxRotationDegrees),
                axis: (x: 0.0, y: 1.0, z: 0.0),
                anchor: .center,
                perspective: perspective
            )
        }
    }

    /// Device and finger tilt together, kept within -1...1 on each axis.
    private func combined(_ device: SIMD2<Double>, _ touch: SIMD2<Double>) -> SIMD2<Double> {
        (device + touch).clamped(lowerBound: SIMD2(repeating: -1), upperBound: SIMD2(repeating: 1))
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
            .aspectRatio(5.0 / 7.0, contentMode: .fit)  // Standard card aspect ratio
    }
}
